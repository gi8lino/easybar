@preconcurrency import EasyBarShared
import Foundation

/// Result returned by one host-owned Lua command execution.
struct LuaCommandResult: Sendable {
  let output: String
  let status: Int32
}

/// Executes Lua-requested shell commands in the host process.
final class LuaCommandRunner: @unchecked Sendable {
  struct Limits: Sendable {
    let timeoutSeconds: TimeInterval
    let maxOutputBytes: Int

    static let timedOutStatus: Int32 = 124
    static let outputLimitStatus: Int32 = 65
  }

  private let logger: ProcessLogger
  private let queue = DispatchQueue(label: "easybar.lua-command-runner", qos: .utility)

  /// Creates one Lua command runner.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Runs one shell command through `/bin/sh -lc`.
  func run(command: String, limits: Limits) async -> LuaCommandResult {
    await withCheckedContinuation { continuation in
      queue.async { [logger] in
        continuation.resume(returning: Self.execute(command: command, limits: limits, logger: logger))
      }
    }
  }

  /// Performs one blocking command execution and captures combined output.
  private static func execute(command: String, limits: Limits, logger: ProcessLogger) -> LuaCommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-lc", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    let handle = pipe.fileHandleForReading
    var outputData = Data()
    var exceededOutputLimit = false
    var timedOut = false
    let stateLock = NSLock()
    let completionSemaphore = DispatchSemaphore(value: 0)
    let deadline = DispatchTime.now() + limits.timeoutSeconds

    handle.readabilityHandler = { readableHandle in
      let chunk = readableHandle.availableData

      stateLock.lock()
      defer { stateLock.unlock() }

      guard !chunk.isEmpty else {
        completionSemaphore.signal()
        return
      }

      let remainingBytes = max(0, limits.maxOutputBytes - outputData.count)
      if remainingBytes > 0 {
        outputData.append(chunk.prefix(remainingBytes))
      }

      if outputData.count >= limits.maxOutputBytes {
        exceededOutputLimit = true
        readableHandle.readabilityHandler = nil
        if process.isRunning {
          process.terminate()
        }
        completionSemaphore.signal()
      }
    }

    do {
      try process.run()
    } catch {
      logger.warn(
        "failed to launch lua command",
        .field("command", command),
        .field("error", "\(error)")
      )
      return LuaCommandResult(
        output: "failed to launch command: \(error)",
        status: 1
      )
    }

    let waitResult = completionSemaphore.wait(timeout: deadline)
    if waitResult == .timedOut {
      timedOut = true
      handle.readabilityHandler = nil
      if process.isRunning {
        process.terminate()
      }
    }

    process.waitUntilExit()
    handle.readabilityHandler = nil

    do {
      let trailingData = try handle.readToEnd() ?? Data()
      stateLock.lock()
      let remainingBytes = max(0, limits.maxOutputBytes - outputData.count)
      if remainingBytes > 0 {
        outputData.append(trailingData.prefix(remainingBytes))
      }
      if outputData.count >= limits.maxOutputBytes && !trailingData.isEmpty {
        exceededOutputLimit = true
      }
      stateLock.unlock()
    } catch {
      logger.warn(
        "failed to read lua command output",
        .field("command", command),
        .field("error", "\(error)")
      )
      return LuaCommandResult(
        output: "failed to read command output: \(error)",
        status: process.terminationStatus == 0 ? 1 : process.terminationStatus
      )
    }

    let output =
      String(data: outputData, encoding: .utf8)?
      .replacingOccurrences(of: "\r", with: "")
      .trimmingCharacters(in: .newlines) ?? ""

    if timedOut {
      logger.warn(
        "lua command timed out",
        .field("command", command),
        .field("timeout_seconds", limits.timeoutSeconds)
      )
      return LuaCommandResult(
        output: output,
        status: Limits.timedOutStatus
      )
    }

    if exceededOutputLimit {
      logger.warn(
        "lua command output exceeded limit",
        .field("command", command),
        .field("max_output_bytes", limits.maxOutputBytes)
      )
      return LuaCommandResult(
        output: output,
        status: Limits.outputLimitStatus
      )
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

        return LuaCommandResult(
          output: message,
          status: process.terminationStatus
        )
      }

      logger.debug(
        "lua command exited non-zero",
        .field("command", command),
        .field("status", process.terminationStatus)
      )
    }

    return LuaCommandResult(
      output: output,
      status: process.terminationStatus
    )
  }
}
