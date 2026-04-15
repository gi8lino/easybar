import Foundation
import TOMLKit

extension Config {

  /// Loads configuration from disk.
  func load() throws {
    let resolvedConfigPath = configPath
    let fileURL = URL(fileURLWithPath: resolvedConfigPath)

    let readStart = Date()

    guard let data = try? Data(contentsOf: fileURL) else {
      logSlowLoadPhase(name: "read config file", startedAt: readStart, path: resolvedConfigPath)
      easybarLog.info("using default configuration from \(resolvedConfigPath)")
      return
    }

    logSlowLoadPhase(name: "read config file", startedAt: readStart, path: resolvedConfigPath)

    let decodeStart = Date()

    guard let text = String(data: data, encoding: .utf8) else {
      logSlowLoadPhase(name: "decode utf8", startedAt: decodeStart, path: resolvedConfigPath)
      throw ConfigError.invalidValue(
        path: "config",
        message: "file is not valid UTF-8"
      )
    }

    logSlowLoadPhase(name: "decode utf8", startedAt: decodeStart, path: resolvedConfigPath)

    do {
      let parseTOMLStart = Date()
      let toml = try TOMLTable(string: text)
      logSlowLoadPhase(name: "parse TOML", startedAt: parseTOMLStart, path: resolvedConfigPath)

      let parseAppStart = Date()
      try parseApp(from: toml)
      logSlowLoadPhase(name: "parseApp", startedAt: parseAppStart, path: resolvedConfigPath)

      let parseLoggingStart = Date()
      try parseLogging(from: toml)
      logSlowLoadPhase(name: "parseLogging", startedAt: parseLoggingStart, path: resolvedConfigPath)

      let parseAgentsStart = Date()
      try parseAgents(from: toml)
      logSlowLoadPhase(name: "parseAgents", startedAt: parseAgentsStart, path: resolvedConfigPath)

      let parseBarStart = Date()
      try parseBar(from: toml)
      logSlowLoadPhase(name: "parseBar", startedAt: parseBarStart, path: resolvedConfigPath)

      let parseBuiltinsStart = Date()
      try parseBuiltins(from: toml)
      logSlowLoadPhase(
        name: "parseBuiltins", startedAt: parseBuiltinsStart, path: resolvedConfigPath)
    } catch let error as ConfigError {
      throw error
    } catch {
      throw ConfigError.invalidValue(
        path: "config",
        message: "parse failed: \(error)"
      )
    }
  }

  /// Logs one config load phase duration when it looks unexpectedly slow.
  private func logSlowLoadPhase(
    name: String,
    startedAt: Date,
    path: String,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn(
      "slow config load phase phase=\(name) duration_ms=\(milliseconds) path=\(path)"
    )
  }
}
