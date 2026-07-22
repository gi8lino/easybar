import EasyBarShared

/// Describes a command-line option accepted by `easybarctl`.
struct CLIOption {
  /// Long-form option flag, such as `--metrics`.
  let flag: String
  /// Optional short-form alias, such as `-m`.
  let short: String?
  /// IPC command triggered by this option, when the option is a command.
  let command: IPC.Command?
  /// Human-readable help text shown in usage output.
  let description: String
  /// Optional value placeholder shown after the option in usage output.
  let placeholder: String?

  /// Creates a command-line option descriptor.
  init(
    flag: String,
    short: String? = nil,
    command: IPC.Command? = nil,
    description: String,
    placeholder: String? = nil
  ) {
    self.flag = flag
    self.short = short
    self.command = command
    self.description = description
    self.placeholder = placeholder
  }
}

/// Parsed command-line configuration.
struct ParsedArguments {
  /// Action selected by the user.
  let action: CLIAction
  /// Unix-domain socket path used to contact the running EasyBar process.
  let socketPath: String?
  /// Optional config path override used by validation.
  let configPath: String?
  /// Whether debug logging was requested.
  let debugEnabled: Bool
  /// Whether metrics should be streamed continuously.
  let watchMetrics: Bool
  /// Options used by the logs command.
  let logOptions: LogCommandOptions
}

/// Parsed `easybar inbox` operation.
enum InboxCLICommand: Equatable {
  case send(IPC.InboxItem)
  case read(source: String?, unreadOnly: Bool, json: Bool)
  case markRead(source: String?, id: String?)
  case markUnread(source: String?, id: String?)
  case dismiss(source: String?, id: String?)
  case remove(source: String, id: String)
  case clear(source: String?)
}

/// Supported top-level CLI actions.
enum CLIAction: Equatable {
  case command(IPC.Command)
  case validateConfig
  case restartCalendarAgent
  case restartNetworkAgent
  case restartAgents
  case logs
  case inbox(InboxCLICommand)
}

/// Defines supported command-line options and formatting helpers.
enum CLI {
  /// Option used to override the EasyBar IPC socket path.
  static let socketOption = CLIOption(
    flag: "--socket",
    short: "-s",
    description: "Override socket path",
    placeholder: "path"
  )

  /// Option used to override the config path for validation.
  static let configOption = CLIOption(
    flag: "--config",
    description: "Override config path for validation",
    placeholder: "path"
  )

  /// Option used to enable debug output.
  static let debugOption = CLIOption(
    flag: "--debug",
    short: "-d",
    description: "Enable debug output"
  )

  /// Option used to print the app version.
  static let versionOption = CLIOption(
    flag: "--version",
    short: "-v",
    description: "Show the easybar version"
  )

  /// Option used to print usage help.
  static let helpOption = CLIOption(
    flag: "--help",
    short: "-h",
    description: "Show this help"
  )

  /// Option used to stream metrics continuously.
  static let watchOption = CLIOption(
    flag: "--watch",
    short: "-w",
    description: "Keep streaming metrics and render rolling graphs"
  )

  /// Option used to validate config through the running EasyBar app.
  static let validateConfigOption = CLIOption(
    flag: "--validate-config",
    description: "Ask the running EasyBar app to validate config"
  )

  /// Option used to emit one EasyBar scripting event.
  static let eventOption = CLIOption(
    flag: "--event",
    description: "Emit an EasyBar scripting event",
    placeholder: "name"
  )

  static let restartCalendarAgentOption = CLIOption(
    flag: "--restart-calendar-agent",
    description: "Restart the calendar agent through its socket"
  )

  static let restartNetworkAgentOption = CLIOption(
    flag: "--restart-network-agent",
    description: "Restart the network agent through its socket"
  )

  static let restartAgentsOption = CLIOption(
    flag: "--restart-agents",
    description: "Restart both helper agents and report any partial failure"
  )

  static let logWidgetOption = CLIOption(
    flag: "--widget",
    description: "Show logs for one Lua or native widget",
    placeholder: "name"
  )

  static let logRuntimeOption = CLIOption(
    flag: "--runtime",
    description: "Show logs for lua, native, or agent runtime",
    placeholder: "kind"
  )

  static let logLevelOption = CLIOption(
    flag: "--level",
    description: "Show this severity and higher",
    placeholder: "level"
  )

  static let logRequestIDOption = CLIOption(
    flag: "--request-id",
    description: "Find a request across retained logs",
    placeholder: "id"
  )

  static let logSinceOption = CLIOption(
    flag: "--since",
    description: "Show entries since a duration or ISO-8601 timestamp",
    placeholder: "time"
  )

  static let logLinesOption = CLIOption(
    flag: "--lines",
    short: "-n",
    description: "Show the latest matching history before following",
    placeholder: "count"
  )

  static let logAllOption = CLIOption(
    flag: "--all",
    description: "Show all matching retained history"
  )

  static let logNoFollowOption = CLIOption(
    flag: "--no-follow",
    description: "Exit after printing retained history"
  )

  static let logJSONOption = CLIOption(
    flag: "--json",
    description: "Print one JSON object per log entry"
  )

  static let logOptions: [CLIOption] = [
    logWidgetOption,
    logRuntimeOption,
    logLevelOption,
    logRequestIDOption,
    logSinceOption,
    logLinesOption,
    logAllOption,
    logNoFollowOption,
    logJSONOption,
  ]

  /// Command options that map directly to IPC commands.
  static let cmdOptions: [CLIOption] = [
    .init(
      flag: "--refresh",
      command: .manualRefresh,
      description:
        "Refresh the bar and widgets using the currently loaded config and pull fresh data from agents"
    ),
    .init(
      flag: "--reload-config",
      command: .reloadConfig,
      description: "Reload config from disk and rebuild EasyBar with the new settings"
    ),
    .init(
      flag: "--restart-lua-runtime",
      command: .restartLuaRuntime,
      description: "Restart only the Lua widget runtime using the currently loaded config"
    ),
    .init(
      flag: "--metrics",
      command: .metrics,
      description: "Print a metrics snapshot or stream live metrics with --watch"
    ),
    restartCalendarAgentOption,
    restartNetworkAgentOption,
    restartAgentsOption,
    validateConfigOption,
  ]

  /// App-level options that configure CLI behavior.
  static let appOptions: [CLIOption] = [
    socketOption,
    configOption,
    eventOption,
    watchOption,
    debugOption,
    versionOption,
    helpOption,
  ]

  /// Formats one help row.
  static func formatOption(_ option: String, _ description: String) -> String {
    return "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
  }

  /// Renders one option label.
  static func optionText(for option: CLIOption) -> String {
    var text = option.flag

    if let short = option.short {
      text += ", \(short)"
    }

    if let placeholder = option.placeholder {
      text += " <\(placeholder)>"
    }

    return text
  }

  /// Checks whether an argument matches an option.
  static func matches(_ option: CLIOption, argument: String) -> Bool {
    return option.flag == argument || option.short == argument
  }

  /// Returns the value from `--flag=value`.
  static func inlineValue(for option: CLIOption, argument: String) -> String? {
    let prefix = "\(option.flag)="
    guard argument.hasPrefix(prefix) else { return nil }
    return String(argument.dropFirst(prefix.count))
  }

  /// Returns the command for one argument.
  static func command(for argument: String) -> IPC.Command? {
    cmdOptions.first { matches($0, argument: argument) }?.command
  }

  /// Returns the IPC command for one EasyBar scripting event name.
  static func eventCommand(for value: String) -> IPC.Command? {
    switch value.replacingOccurrences(of: "-", with: "_") {
    case IPC.Command.workspaceChange.rawValue:
      return .workspaceChange
    case IPC.Command.focusChange.rawValue:
      return .focusChange
    case IPC.Command.spaceModeChange.rawValue:
      return .spaceModeChange
    default:
      return nil
    }
  }
}
