@preconcurrency import EasyBarShared
import Foundation

/// Result returned by one host-owned Lua command execution.
struct LuaCommandResult: Sendable {
  let output: String
  let status: Int32
}

/// Executes Lua-requested shell commands in the host process.
///
/// The runner is immutable after initialization; each command execution owns
/// its mutable state in a separate locked `CommandExecution`.
final class LuaCommandRunner: @unchecked Sendable {
  struct Limits: Sendable {
    let timeoutSeconds: TimeInterval
    let maxOutputBytes: Int

    static let timedOutStatus: Int32 = 124
    static let outputLimitStatus: Int32 = 65
  }

  private let logger: ProcessLogger

  /// Creates one Lua command runner.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Runs one shell command through `/bin/sh -lc`.
  func run(
    command: String,
    limits: Limits,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) async -> LuaCommandResult {
    await withCheckedContinuation { continuation in
      let execution = CommandExecution(
        command: command,
        limits: limits,
        environment: environment,
        logger: logger,
        continuation: continuation
      )
      execution.start()
    }
  }
}

/// Owns one asynchronous process execution.
///
/// The process handlers intentionally capture this object strongly. That keeps
/// the checked continuation alive until one terminal path resumes it. `complete`
/// clears the handlers and cancels the timeout task, which breaks the temporary
/// retain cycle.
///
/// Output reads and process completion are serialized on `queue`. This avoids a
/// race where a readability handler could consume a tiny output chunk while the
/// termination handler completed the command before that chunk was appended.
/// Sendability is guarded by `LockedState`; output buffers, completion flags,
/// and continuation ownership are only mutated while holding that lock.
private final class CommandExecution: @unchecked Sendable {
  private struct State {
    var outputData = Data()
    var exceededOutputLimit = false
    var timedOut = false
    var completed = false
    var continuation: CheckedContinuation<LuaCommandResult, Never>?
  }

  private let command: String
  private let limits: LuaCommandRunner.Limits
  private let environment: [String: String]
  private let logger: ProcessLogger
  private let process = Process()
  private let pipe = Pipe()
  private let state: LockedState<State>
  private let queue = DispatchQueue(
    label: "easybar.lua-command-runner.command-execution.\(UUID().uuidString)"
  )
  private var timeoutTask: Task<Void, Never>?

  init(
    command: String,
    limits: LuaCommandRunner.Limits,
    environment: [String: String],
    logger: ProcessLogger,
    continuation: CheckedContinuation<LuaCommandResult, Never>
  ) {
    self.command = command
    self.limits = limits
    self.environment = environment
    self.logger = logger
    self.state = LockedState(State(continuation: continuation))
  }

  /// Starts the process and installs async completion handlers.
  func start() {
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-lc", command]
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe

    let handle = pipe.fileHandleForReading

    handle.readabilityHandler = { readableHandle in
      self.queue.async {
        self.readAvailableOutput(from: readableHandle)
      }
    }

    process.terminationHandler = { process in
      self.queue.async {
        self.finish(process: process)
      }
    }

    do {
      try process.run()
    } catch {
      handle.readabilityHandler = nil

      logger.warn(
        "failed to launch lua command",
        .field("command", command),
        .field("error", "\(error)")
      )

      complete(
        LuaCommandResult(output: "failed to launch command: \(error)", status: 1)
      )
      return
    }

    scheduleTimeout()
  }

  /// Reads currently available command output without blocking.
  private func readAvailableOutput(from handle: FileHandle) {
    let isCompleted = state.withLock { $0.completed }
    guard !isCompleted else { return }

    let chunk = handle.availableData

    guard !chunk.isEmpty else { return }

    let shouldTerminate = state.withLock { state -> Bool in
      guard !state.completed else { return false }

      let remainingBytes = max(0, limits.maxOutputBytes - state.outputData.count)
      if remainingBytes > 0 {
        state.outputData.append(chunk.prefix(remainingBytes))
      }

      if state.outputData.count >= limits.maxOutputBytes {
        state.exceededOutputLimit = true
        return true
      }

      return false
    }

    if shouldTerminate, process.isRunning {
      pipe.fileHandleForReading.readabilityHandler = nil
      process.terminate()
    }
  }

  /// Schedules the hard timeout for this command.
  private func scheduleTimeout() {
    guard limits.timeoutSeconds > 0 else { return }

    let timeoutNanoseconds = UInt64(limits.timeoutSeconds * 1_000_000_000)

    timeoutTask = Task {
      do {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
      } catch {
        return
      }

      self.queue.async {
        self.handleTimeout()
      }
    }
  }

  /// Handles one timeout event.
  private func handleTimeout() {
    let shouldTerminate = state.withLock { state -> Bool in
      guard !state.completed else { return false }
      state.timedOut = true
      return true
    }

    if shouldTerminate, process.isRunning {
      pipe.fileHandleForReading.readabilityHandler = nil
      process.terminate()
    }
  }

  /// Finishes after the process has terminated.
  private func finish(process: Process) {
    pipe.fileHandleForReading.readabilityHandler = nil

    if let remainingData = try? pipe.fileHandleForReading.readToEnd() {
      appendRemainingOutput(remainingData)
    }

    complete(result(for: process))
  }

  /// Appends final output read after process termination.
  private func appendRemainingOutput(_ data: Data) {
    guard !data.isEmpty else { return }

    state.withLock { state in
      guard !state.completed else { return }

      let remainingBytes = max(0, limits.maxOutputBytes - state.outputData.count)
      if remainingBytes > 0 {
        state.outputData.append(data.prefix(remainingBytes))
      }

      if state.outputData.count >= limits.maxOutputBytes {
        state.exceededOutputLimit = true
      }
    }
  }

  /// Builds the final command result from captured state.
  private func result(for process: Process) -> LuaCommandResult {
    let snapshot = state.withLock { state in
      (
        outputData: state.outputData,
        exceededOutputLimit: state.exceededOutputLimit,
        timedOut: state.timedOut
      )
    }

    let output =
      String(data: snapshot.outputData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if snapshot.timedOut {
      logger.warn(
        "lua command timed out",
        .field("command", command),
        .field("timeout_seconds", limits.timeoutSeconds)
      )
      return LuaCommandResult(output: output, status: LuaCommandRunner.Limits.timedOutStatus)
    }

    if snapshot.exceededOutputLimit {
      logger.warn(
        "lua command output exceeded limit",
        .field("command", command),
        .field("max_output_bytes", limits.maxOutputBytes)
      )
      return LuaCommandResult(output: output, status: LuaCommandRunner.Limits.outputLimitStatus)
    }

    if process.terminationStatus != 0 {
      if process.terminationStatus == 127 {
        let message =
          output.isEmpty
          ? "command not found: \(command)"
          : "command not found: \(command)\n\(output)"

        logger.warn(
          "lua command not found",
          .field("command", command),
          .field("status", process.terminationStatus)
        )

        return LuaCommandResult(output: message, status: process.terminationStatus)
      }

      logger.debug(
        "lua command exited non-zero",
        .field("command", command),
        .field("status", process.terminationStatus)
      )
    }

    return LuaCommandResult(output: output, status: process.terminationStatus)
  }

  /// Resumes the continuation exactly once.
  private func complete(_ result: LuaCommandResult) {
    let continuation = state.withLock { state -> CheckedContinuation<LuaCommandResult, Never>? in
      guard !state.completed else { return nil }

      state.completed = true
      let continuation = state.continuation
      state.continuation = nil
      return continuation
    }

    timeoutTask?.cancel()
    timeoutTask = nil

    process.terminationHandler = nil
    pipe.fileHandleForReading.readabilityHandler = nil

    continuation?.resume(returning: result)
  }
}
