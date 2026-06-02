import Foundation

/// Dry-run config validation mode used by the CLI.
enum AppValidationMode {
  private static let validationEnvironmentKey = "EASYBAR_VALIDATE_CONFIG_ONLY"

  /// Runs config validation when validation mode is requested and returns the process exit code.
  static func exitCodeIfRequested() -> Int32? {
    guard ProcessInfo.processInfo.environment[validationEnvironmentKey] == "1" else {
      return nil
    }

    return validateConfig()
  }

  /// Validates the current config and returns the desired process exit code.
  private static func validateConfig() -> Int32 {
    do {
      let result = try ConfigValidator.validate()
      fputs("config valid: \(result.configPath)\n", stdout)
      return 0
    } catch {
      fputs("easybar: \(error)\n", stderr)
      return 1
    }
  }
}
