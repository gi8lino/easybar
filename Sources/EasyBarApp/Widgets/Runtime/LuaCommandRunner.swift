@preconcurrency import EasyBarShared
import Foundation

/// Result returned by one host-owned Lua command execution.
struct LuaCommandResult: Sendable {
  let output: String
  let status: Int32
}

/// Executes Lua-requested shell commands in the host process.
final class LuaCommandRunner: @unchecked Sendable {
  private let logger: ProcessLogger
  private let queue = DispatchQueue(label: "easybar.lua-command-runner", qos: .utility)

  /// Creates one Lua command runner.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Runs one shell command through `/bin/sh -lc`.
  func run(command: String) async -> LuaCommandResult {
    await withCheckedContinuation { continuation in
      queue.async { [logger] in
        continuation.resume(returning: Self.execute(command: command, logger: logger))
      }
    }
  }

  /// Performs one blocking command execution and captures combined output.
  private static func execute(command: String, logger: ProcessLogger) -> LuaCommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-lc", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    let handle = pipe.fileHandleForReading

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

    let data: Data
    do {
      data = try handle.readToEnd() ?? Data()
    } catch {
      logger.warn(
        "failed to read lua command output",
        .field("command", command),
        .field("error", "\(error)")
      )
      process.waitUntilExit()
      return LuaCommandResult(
        output: "failed to read command output: \(error)",
        status: process.terminationStatus == 0 ? 1 : process.terminationStatus
      )
    }

    process.waitUntilExit()

    let output =
      String(data: data, encoding: .utf8)?
      .replacingOccurrences(of: "\r", with: "")
      .trimmingCharacters(in: .newlines) ?? ""

    if process.terminationStatus != 0 {
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
