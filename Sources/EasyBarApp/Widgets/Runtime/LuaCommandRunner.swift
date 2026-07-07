import Darwin
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
/// clears the handlers and cancels the timeout/wait tasks, which breaks the
/// temporary retain cycle.
///
/// Output reads and process completion are serialized on `queue`. This avoids a
/// race where a readability handler could consume a tiny output chunk while the
/// termination handler completed the command before that chunk was appended.
/// Sendability is guarded by `LockedState`; output buffers, completion flags,
/// and continuation ownership are only mutated while holding that lock. Process
/// identifiers are touched only on the serial command queue.
private final class CommandExecution: @unchecked Sendable {
  private static let shellPath = "/bin/sh"
  private static let forcedTerminationGraceNanoseconds: UInt64 = 300_000_000

  private struct State {
    var outputData = Data()
    var exceededOutputLimit = false
    var timedOut = false
    var completed = false
    var continuation: CheckedContinuation<LuaCommandResult, Never>?

    mutating func appendOutput(_ data: Data, maxOutputBytes: Int) -> Bool {
      guard !completed, !data.isEmpty else { return false }

      let remainingBytes = max(0, maxOutputBytes - outputData.count)
      if remainingBytes > 0 {
        outputData.append(data.prefix(remainingBytes))
      }

      guard outputData.count >= maxOutputBytes else {
        return false
      }

      exceededOutputLimit = true
      return true
    }

    mutating func markTimedOut() -> Bool {
      guard !completed else { return false }
      timedOut = true
      return true
    }

    mutating func takeContinuationForCompletion()
      -> CheckedContinuation<LuaCommandResult, Never>?
    {
      guard !completed else { return nil }

      completed = true
      let continuation = continuation
      self.continuation = nil
      return continuation
    }
  }

  private let command: String
  private let limits: LuaCommandRunner.Limits
  private let environment: [String: String]
  private let logger: ProcessLogger
  private let state: LockedState<State>
  private let queue = DispatchQueue(
    label: "easybar.lua-command-runner.command-execution.\(UUID().uuidString)"
  )

  private var processIdentifier: Int32?
  private var processGroupIdentifier: Int32?
  private var outputReadHandle: FileHandle?
  private var timeoutTask: Task<Void, Never>?
  private var waitTask: Task<Void, Never>?
  private var forceKillTask: Task<Void, Never>?

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
    queue.async {
      self.startOnQueue()
    }
  }

  /// Starts the process on the serial command queue.
  private func startOnQueue() {
    let pipeResult = makeOutputPipe()
    guard let pipeResult else { return }

    do {
      let pid = try spawnShell(outputWriteFD: pipeResult.writeFD)
      close(pipeResult.writeFD)

      processIdentifier = pid
      processGroupIdentifier = pid
      outputReadHandle = pipeResult.readHandle

      installOutputReader(pipeResult.readHandle)
      installWaitTask(pid: pid)
      scheduleTimeout()
    } catch {
      close(pipeResult.writeFD)
      try? pipeResult.readHandle.close()

      logger.warn(
        "failed to launch lua command",
        .field("command_bytes", command.utf8.count),
        .field("error", "\(error)")
      )

      complete(
        LuaCommandResult(output: "failed to launch command: \(error)", status: 1)
      )
    }
  }

  /// Creates a pipe used to collect combined stdout and stderr.
  private func makeOutputPipe() -> (readHandle: FileHandle, writeFD: Int32)? {
    var fileDescriptors = [Int32](repeating: -1, count: 2)
    guard pipe(&fileDescriptors) == 0 else {
      logger.warn(
        "failed to create lua command output pipe",
        .field("errno", errno)
      )

      complete(
        LuaCommandResult(output: "failed to create command output pipe", status: 1)
      )
      return nil
    }

    let readHandle = FileHandle(fileDescriptor: fileDescriptors[0], closeOnDealloc: true)
    return (readHandle, fileDescriptors[1])
  }

  /// Spawns `/bin/sh -lc <command>` in a dedicated process group.
  private func spawnShell(outputWriteFD: Int32) throws -> Int32 {
    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?

    try PosixSpawnSupport.initializeFileActions(&fileActions)
    defer {
      if fileActions != nil {
        posix_spawn_file_actions_destroy(&fileActions)
      }
    }

    try PosixSpawnSupport.initializeSpawnAttributes(&attributes)
    defer {
      if attributes != nil {
        posix_spawnattr_destroy(&attributes)
      }
    }

    try PosixSpawnSupport.addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: outputWriteFD,
      destinationFileDescriptor: STDOUT_FILENO
    )
    try PosixSpawnSupport.addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: outputWriteFD,
      destinationFileDescriptor: STDERR_FILENO
    )
    try PosixSpawnSupport.addCloseAction(
      fileActions: &fileActions,
      fileDescriptor: outputWriteFD
    )
    try PosixSpawnSupport.configureDedicatedProcessGroup(attributes: &attributes)

    let argv = try PosixSpawnSupport.makeCStringVector([Self.shellPath, "-lc", command])
    defer { PosixSpawnSupport.freeCStringVector(argv) }

    let envp = try makeEnvironmentVector(environment)
    defer { PosixSpawnSupport.freeCStringVector(envp) }

    var pid: pid_t = 0
    let spawnResult = Self.shellPath.withCString { executablePath in
      posix_spawn(
        &pid,
        executablePath,
        &fileActions,
        &attributes,
        argv,
        envp
      )
    }

    guard spawnResult == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(spawnResult),
        userInfo: [
          NSLocalizedDescriptionKey:
            "posix_spawn failed for lua command shell errno=\(spawnResult)"
        ]
      )
    }

    return pid
  }

  /// Builds a process environment vector for `posix_spawn`.
  private func makeEnvironmentVector(
    _ environment: [String: String]
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    let flattenedEnvironment = environment.map { "\($0.key)=\($0.value)" }.sorted()
    return try PosixSpawnSupport.makeCStringVector(flattenedEnvironment)
  }

  /// Installs the nonblocking output reader.
  private func installOutputReader(_ handle: FileHandle) {
    handle.readabilityHandler = { readableHandle in
      self.queue.async {
        self.readAvailableOutput(from: readableHandle)
      }
    }
  }

  /// Installs a wait task for process termination.
  private func installWaitTask(pid: Int32) {
    waitTask = DetachedTask.run(priority: .utility) { [self] in
      var status: Int32 = 0
      let waitResult = waitpid(pid, &status, 0)
      let errnoValue = errno

      guard !Task.isCancelled else { return }
      queue.async {
        self.finish(waitResult: waitResult, status: status, errnoValue: errnoValue)
      }
    }
  }

  /// Reads currently available command output without blocking.
  private func readAvailableOutput(from handle: FileHandle) {
    let isAlreadyCompleted = state.withLock { state in
      state.completed
    }
    guard !isAlreadyCompleted else { return }

    let chunk = handle.availableData
    let shouldTerminate = state.withLock { state in
      state.appendOutput(chunk, maxOutputBytes: limits.maxOutputBytes)
    }

    if shouldTerminate {
      outputReadHandle?.readabilityHandler = nil
      terminateProcessTree(signal: SIGTERM)
      scheduleForcedTermination()
    }
  }

  /// Schedules the hard timeout for this command.
  private func scheduleTimeout() {
    let timeoutNanoseconds = clampedSleepNanoseconds(from: limits.timeoutSeconds)
    guard timeoutNanoseconds > 0 else { return }

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
    let shouldTerminate = state.withLock { state in
      state.markTimedOut()
    }

    if shouldTerminate {
      outputReadHandle?.readabilityHandler = nil
      terminateProcessTree(signal: SIGTERM)
      scheduleForcedTermination()
    }
  }

  /// Finishes after the process has terminated.
  private func finish(waitResult: Int32, status: Int32, errnoValue: Int32) {
    outputReadHandle?.readabilityHandler = nil

    if waitResult < 0, errnoValue != ECHILD {
      logger.warn(
        "failed to reap lua command",
        .field("command_bytes", command.utf8.count),
        .field("errno", errnoValue)
      )
    }

    if let remainingData = try? outputReadHandle?.readToEnd() {
      appendRemainingOutput(remainingData)
    }

    complete(result(waitResult: waitResult, status: status))
  }

  /// Appends final output read after process termination.
  private func appendRemainingOutput(_ data: Data) {
    state.withLock { state in
      _ = state.appendOutput(data, maxOutputBytes: limits.maxOutputBytes)
    }
  }

  /// Builds the final command result from captured state.
  private func result(waitResult: Int32, status: Int32) -> LuaCommandResult {
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
        .field("command_bytes", command.utf8.count),
        .field("timeout_seconds", limits.timeoutSeconds)
      )
      return LuaCommandResult(output: output, status: LuaCommandRunner.Limits.timedOutStatus)
    }

    if snapshot.exceededOutputLimit {
      logger.warn(
        "lua command output exceeded limit",
        .field("command_bytes", command.utf8.count),
        .field("max_output_bytes", limits.maxOutputBytes)
      )
      return LuaCommandResult(output: output, status: LuaCommandRunner.Limits.outputLimitStatus)
    }

    let exitStatus = commandExitStatus(waitResult: waitResult, status: status)
    if exitStatus != 0 {
      if exitStatus == 127 {
        let message =
          output.isEmpty
          ? "command not found"
          : "command not found\n\(output)"

        logger.warn(
          "lua command not found",
          .field("command_bytes", command.utf8.count),
          .field("status", exitStatus)
        )

        return LuaCommandResult(output: message, status: exitStatus)
      }

      logger.debug(
        "lua command exited non-zero",
        .field("command_bytes", command.utf8.count),
        .field("status", exitStatus)
      )
    }

    return LuaCommandResult(output: output, status: exitStatus)
  }

  /// Schedules a `SIGKILL` fallback when graceful termination is ignored.
  private func scheduleForcedTermination() {
    guard forceKillTask == nil else { return }

    forceKillTask = Task {
      do {
        try await Task.sleep(nanoseconds: Self.forcedTerminationGraceNanoseconds)
      } catch {
        return
      }

      self.queue.async {
        self.forceTerminateIfStillRunning()
      }
    }
  }

  /// Force-kills the command process tree if `waitpid` has not completed yet.
  private func forceTerminateIfStillRunning() {
    let isCompleted = state.withLock { state in
      state.completed
    }
    guard !isCompleted else { return }

    logger.warn(
      "lua command ignored graceful termination",
      .field("command_bytes", command.utf8.count)
    )
    terminateProcessTree(signal: SIGKILL)
  }

  /// Sends one signal to the command process group, falling back to the shell process.
  private func terminateProcessTree(signal: Int32) {
    if let processGroupIdentifier, processGroupIdentifier > 0 {
      kill(-processGroupIdentifier, signal)
      return
    }

    if let processIdentifier {
      kill(processIdentifier, signal)
    }
  }

  /// Resumes the continuation exactly once.
  private func complete(_ result: LuaCommandResult) {
    let continuation = state.withLock { state in
      state.takeContinuationForCompletion()
    }

    timeoutTask?.cancel()
    timeoutTask = nil
    waitTask?.cancel()
    waitTask = nil
    forceKillTask?.cancel()
    forceKillTask = nil

    outputReadHandle?.readabilityHandler = nil
    outputReadHandle = nil
    processIdentifier = nil
    processGroupIdentifier = nil

    continuation?.resume(returning: result)
  }

  /// Returns a shell-compatible exit status from one `waitpid` status value.
  private func commandExitStatus(waitResult: Int32, status: Int32) -> Int32 {
    guard waitResult >= 0 else { return 1 }

    if waitStatusExited(status) {
      return waitStatusExitCode(status)
    }

    if waitStatusSignaled(status) {
      return 128 + waitStatusTerminationSignal(status)
    }

    return 1
  }

  /// Returns the low wait-status byte used by Darwin wait macros.
  private func waitStatusCode(_ status: Int32) -> Int32 {
    return status & 0x7f
  }

  /// Returns whether one wait status represents normal process exit.
  private func waitStatusExited(_ status: Int32) -> Bool {
    return waitStatusCode(status) == 0
  }

  /// Returns the process exit code from one wait status.
  private func waitStatusExitCode(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xff
  }

  /// Returns whether one wait status represents signal termination.
  private func waitStatusSignaled(_ status: Int32) -> Bool {
    let code = waitStatusCode(status)
    return code != 0x7f && code != 0
  }

  /// Returns the terminating signal from one wait status.
  private func waitStatusTerminationSignal(_ status: Int32) -> Int32 {
    return waitStatusCode(status)
  }
}
