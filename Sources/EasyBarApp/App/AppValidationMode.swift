import Foundation

/// Dry-run config validation mode used by the CLI.
enum AppValidationMode {
  private static let validationEnvironmentKey = "EASYBAR_VALIDATE_CONFIG_ONLY"

  /// Runs config validation and exits when validation mode is requested.
  static func runIfRequested() -> Bool {
    guard ProcessInfo.processInfo.environment[validationEnvironmentKey] == "1" else {
      return false
    }

    do {
      let result = try ConfigValidator.validate()
      fputs("config valid: \(result.configPath)\n", stdout)
      Foundation.exit(0)
    } catch {
      fputs("easybar: \(error)\n", stderr)
      Foundation.exit(1)
    }
  }
}
