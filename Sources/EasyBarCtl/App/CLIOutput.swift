import Darwin
import EasyBarShared
import Foundation

/// Prints user-facing CLI output.
enum CLIOutput {
  /// Prints an error.
  static func printError(_ message: String) {
    fputs("easybar: \(message)\n", stderr)
  }

  /// Prints the version.
  static func printVersion() {
    fputs("easybar \(BuildInfo.appVersion)\n", stdout)
  }

  /// Prints usage.
  static func printUsage() {
    let commandLines = CLI.cmdOptions.map {
      CLI.formatOption(CLI.optionText(for: $0), $0.description)
    }
    let appOptionLines = CLI.appOptions.map {
      CLI.formatOption(CLI.optionText(for: $0), $0.description)
    }

    let lines: [String] =
      [
        "usage:",
        "  easybar <command> [options]",
        "",
        "commands:",
      ] + commandLines + [
        "",
        "options:",
      ] + appOptionLines

    fputs(lines.joined(separator: "\n") + "\n", stderr)
  }

  /// Prints one metrics snapshot.
  static func printMetricsSnapshot(_ snapshot: IPC.MetricsSnapshot) {
    fputs(MetricsRenderer.snapshotText(snapshot) + "\n", stdout)
  }
}
