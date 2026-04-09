import Foundation
import TOMLKit

extension Config {

  /// Loads configuration from disk.
  func load() throws {
    let resolvedConfigPath = configPath

    guard
      let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedConfigPath)),
      let text = String(data: data, encoding: .utf8)
    else {
      applyEnvironmentLoggingOverrides()
      easybarLog.info("using default configuration from \(resolvedConfigPath)")
      return
    }

    do {
      let toml = try TOMLTable(string: text)

      try parseApp(from: toml)
      try parseLogging(from: toml)
      try parseAgents(from: toml)
      try parseBar(from: toml)
      try parseBuiltins(from: toml)
      applyEnvironmentLoggingOverrides()
    } catch let error as ConfigError {
      throw error
    } catch {
      throw ConfigError.invalidValue(
        path: "config",
        message: "parse failed: \(error)"
      )
    }
  }

  /// Applies logging-related environment overrides after config parsing.
  private func applyEnvironmentLoggingOverrides() {
    if let debugOverride = environmentDebugOverride() {
      loggingDebugEnabled = debugOverride
    }

    if let traceOverride = environmentTraceOverride() {
      loggingTraceEnabled = traceOverride
    }
  }
}
