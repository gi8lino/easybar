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
}

/// Supported top-level CLI actions.
enum CLIAction: Equatable {
  case command(IPC.Command)
  case validateConfig
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
    validateConfigOption,
  ]

  /// App-level options that configure CLI behavior.
  static let appOptions: [CLIOption] = [
    socketOption,
    configOption,
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
}
