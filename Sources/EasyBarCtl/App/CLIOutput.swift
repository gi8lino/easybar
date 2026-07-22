import Darwin
import EasyBarShared
import Foundation

/// Prints user-facing CLI output.
enum CLIOutput {
  static func printError(_ message: String) {
    fputs("easybar: \(message)\n", stderr)
  }

  static func printWarning(_ message: String) {
    fputs("easybar: warning: \(message)\n", stderr)
  }

  static func printVersion() {
    fputs("easybar \(BuildInfo.appVersion)\n", stdout)
  }

  /// Prints root, group, or command-specific usage from the declarative command catalog.
  static func printUsage(topic: [String] = []) {
    let lines: [String]

    if topic.isEmpty {
      lines = rootUsage()
    } else if let command = CLI.commands.first(where: { $0.path == topic }) {
      lines = commandUsage(command)
    } else if topic.count == 1,
      let group = CLI.commandGroups.first(where: { $0.name == topic[0] })
    {
      lines = groupUsage(group)
    } else {
      lines = rootUsage()
    }

    fputs(lines.joined(separator: "\n") + "\n", stderr)
  }

  private static func rootUsage() -> [String] {
    var lines = [
      "usage:",
      "  easybar <command> [options]",
      "",
      "commands:",
    ]
    lines += CLI.commandGroups.map { CLI.formatRow($0.name, $0.description) }
    lines += [
      "",
      "global options:",
    ]
    lines += CLI.globalOptions.map { CLI.formatRow($0.helpText, $0.description) }
    lines += [
      "",
      "run \"easybar <command> --help\" for command-specific help",
    ]
    return lines
  }

  private static func groupUsage(_ group: CLICommandGroup) -> [String] {
    let commands = CLI.commands.filter { $0.path.first == group.name }
    if commands.count == 1, let command = commands.first, command.path.count == 1 {
      return commandUsage(command)
    }

    var lines = [
      "usage:",
      "  easybar \(group.name) <command> [options]",
      "",
      "commands:",
    ]
    lines += commands.map { command in
      let relativePath = command.path.dropFirst().joined(separator: " ")
      return CLI.formatRow(relativePath, command.description)
    }
    lines += [
      "",
      "global options:",
      CLI.formatRow(CLI.socketOption.helpText, CLI.socketOption.description),
      CLI.formatRow(CLI.debugOption.helpText, CLI.debugOption.description),
      CLI.formatRow(CLI.helpOption.helpText, CLI.helpOption.description),
    ]
    return lines
  }

  private static func commandUsage(_ command: CLICommandDescriptor) -> [String] {
    var lines = [
      "usage:",
      "  \(command.usageText) [options]",
      "",
      command.description,
    ]

    if !command.options.isEmpty {
      lines += ["", "options:"]
      lines += command.options.map { CLI.formatRow($0.helpText, $0.description) }
    }

    lines += ["", "global options:"]
    if command.kind.acceptsSocketOverride {
      lines.append(CLI.formatRow(CLI.socketOption.helpText, CLI.socketOption.description))
    }
    lines.append(CLI.formatRow(CLI.debugOption.helpText, CLI.debugOption.description))
    lines.append(CLI.formatRow(CLI.helpOption.helpText, CLI.helpOption.description))
    return lines
  }

  static func printMetricsSnapshot(_ snapshot: IPC.MetricsSnapshot) {
    fputs(MetricsRenderer.snapshotText(snapshot) + "\n", stdout)
  }

  static func printInboxItems(_ items: [IPC.InboxItem], json: Bool) throws {
    if json {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(items)
      guard let output = String(data: data, encoding: .utf8) else {
        throw AppError.message("failed to encode inbox output")
      }
      fputs(output + "\n", stdout)
      return
    }

    if items.isEmpty {
      fputs("No inbox messages.\n", stdout)
      return
    }

    for item in items {
      let state = item.unread ? "unread" : "read"
      fputs("[\(item.severity.rawValue)] \(item.source)/\(item.id) (\(state))\n", stdout)
      fputs("  \(item.title)\n", stdout)
      if let message = item.message, !message.isEmpty { fputs("  \(message)\n", stdout) }
      if let category = item.group, !category.isEmpty { fputs("  category: \(category)\n", stdout) }
      if let url = item.url, !url.isEmpty { fputs("  url: \(url)\n", stdout) }
    }
  }
}
