import EasyBarShared
import Foundation

/// Routes structured stderr lines from the Lua runtime into the normal logger.
final class LuaLogBridge {
  private let logger: ProcessLogger
  private let prefix = "EASYBAR_LUA_LOG\t"

  /// Creates one Lua log bridge.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Handles one stderr line from the Lua runtime.
  func handle(_ line: String) {
    guard line.hasPrefix(prefix) else {
      logRawStderr(line)
      return
    }

    let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)

    guard parts.count == 4 else {
      logRawStderr(line)
      return
    }

    let level = String(parts[1]).uppercased()
    let source = String(parts[2])
    let message = String(parts[3])

    logFormatted(level: level, source: source, message: message)
  }

  /// Logs one raw stderr line that does not follow the structured format.
  private func logRawStderr(_ line: String) {
    logger.error("lua stderr line", .field("bytes", line.utf8.count))
  }

  /// Logs one structured Lua message at the requested level.
  private func logFormatted(level: String, source: String, message: String) {
    let field: ProcessLogField =
      source == "runtime"
      ? .field("component", "runtime")
      : .field("widget", source)

    switch level {
    case "TRACE":
      logger.trace(message, field)
    case "DEBUG":
      logger.debug(message, field)
    case "INFO":
      logger.info(message, field)
    case "WARN":
      logger.warn(message, field)
    case "ERROR":
      logger.error(message, field)
    default:
      logger.info(message, field)
    }
  }
}
