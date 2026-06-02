import Darwin
import EasyBarShared
import Foundation

/// CLI entry point.
@main
enum EasyBarCtlApp {
  /// Runs the CLI.
  static func main() {
    exit(AppController().run())
  }
}

/// Runs the CLI flow.
private struct AppController {
  /// Returns the exit code.
  func run() -> Int32 {
    do {
      let parsed = try parseArguments(CommandLine.arguments)
      let context = AppContext(debugEnabled: parsed.debugEnabled)

      switch parsed.action {
      case .validateConfig:
        try validateConfig(configPath: parsed.configPath, context: context)
      case .command(let command):
        let socketPath = parsed.socketPath ?? SharedRuntimeConfig.current.easyBarSocketPath

        if command == .metrics {
          if parsed.watchMetrics {
            try streamMetrics(to: socketPath, context: context)
          } else {
            let snapshot = try fetchMetricsSnapshot(from: socketPath, context: context)
            CLIOutput.printMetricsSnapshot(snapshot)
          }
        } else {
          try sendCommand(command, to: socketPath, context: context)
        }
      }

      return 0
    } catch AppError.showUsage {
      CLIOutput.printUsage()
      return 1
    } catch AppError.showVersion {
      CLIOutput.printVersion()
      return 0
    } catch AppError.message(let message) {
      CLIOutput.printError(message)
    } catch {
      CLIOutput.printError("\(error)")
    }

    CLIOutput.printUsage()
    return 1
  }
}

/// Describes a command-line option accepted by `easybarctl`.
private struct CLIOption {
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
private struct ParsedArguments {
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
private enum CLIAction: Equatable {
  case command(IPC.Command)
  case validateConfig
}

/// Shared runtime context for CLI operations.
private struct AppContext {
  /// Logger used for optional debug output.
  private let logger: ProcessLogger

  /// Creates a context and enables debug logging when requested.
  init(debugEnabled: Bool) {
    let envEnabled = boolEnvironmentValue(named: "EASYBAR_DEBUG") ?? false
    logger = ProcessLogger(
      label: "easybarctl", minimumLevel: (debugEnabled || envEnabled) ? .debug : .info)
  }

  /// Logs a debug line.
  func debug(_ message: String) {
    logger.debug(message)
  }
}

/// Errors used to control CLI flow and user-facing output.
private enum AppError: Error {
  /// Requests usage output.
  case showUsage
  /// Requests version output.
  case showVersion
  /// Carries a user-facing error message.
  case message(String)
}

/// Prints user-facing CLI output.
private enum CLIOutput {
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

/// Defines supported command-line options and formatting helpers.
private enum CLI {
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
  /// Option used to validate config without contacting the running app.
  static let validateConfigOption = CLIOption(
    flag: "--validate-config",
    description: "Validate config without starting EasyBar"
  )

  /// Command options that map directly to IPC commands.
  static let cmdOptions: [CLIOption] = [
    .init(
      flag: "--workspace-changed",
      command: .workspaceChanged,
      description: "Notify EasyBar that the focused workspace changed"
    ),
    .init(
      flag: "--focus-changed",
      command: .focusChanged,
      description: "Notify EasyBar that the focused app or window changed"
    ),
    .init(
      flag: "--space-mode-changed",
      command: .spaceModeChanged,
      description: "Notify EasyBar that the AeroSpace layout mode changed"
    ),
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

/// Parses CLI arguments.
private func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedAction: CLIAction?
  var socketPath: String?
  var configPath: String?
  var debugEnabled = false
  var watchMetrics = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if let nextIndex = try parseAppArgument(
      arg,
      arguments: arguments,
      index: i,
      socketPath: &socketPath,
      configPath: &configPath,
      debugEnabled: &debugEnabled,
      watchMetrics: &watchMetrics,
      selectedAction: &selectedAction
    ) {
      i = nextIndex
      continue
    }

    if let command = CLI.command(for: arg) {
      guard selectedAction == nil else {
        throw AppError.message("only one command flag may be specified")
      }

      selectedAction = .command(command)
      i += 1
      continue
    }

    throw AppError.message("unknown argument '\(arg)'")
  }

  guard let action = selectedAction else {
    throw AppError.message("no command flag provided")
  }

  if watchMetrics, action != .command(.metrics) {
    throw AppError.message("--watch may only be used with --metrics")
  }

  if socketPath != nil, action == .validateConfig {
    throw AppError.message("--socket may not be used with --validate-config")
  }

  if configPath != nil, action != .validateConfig {
    throw AppError.message("--config may only be used with --validate-config")
  }

  return ParsedArguments(
    action: action,
    socketPath: socketPath,
    configPath: configPath,
    debugEnabled: debugEnabled,
    watchMetrics: watchMetrics
  )
}

/// Parses one app-level option.
private func parseAppArgument(
  _ argument: String,
  arguments: [String],
  index: Int,
  socketPath: inout String?,
  configPath: inout String?,
  debugEnabled: inout Bool,
  watchMetrics: inout Bool,
  selectedAction: inout CLIAction?
) throws -> Int? {
  if CLI.matches(CLI.helpOption, argument: argument) {
    throw AppError.showUsage
  }

  if CLI.matches(CLI.versionOption, argument: argument) {
    throw AppError.showVersion
  }

  if CLI.matches(CLI.debugOption, argument: argument) {
    debugEnabled = true
    return index + 1
  }

  if CLI.matches(CLI.watchOption, argument: argument) {
    watchMetrics = true
    return index + 1
  }

  if CLI.matches(CLI.validateConfigOption, argument: argument) {
    guard selectedAction == nil else {
      throw AppError.message("only one command flag may be specified")
    }

    selectedAction = .validateConfig
    return index + 1
  }

  if let parsedSocketArgument = try parseSocketArgument(
    argument,
    arguments: arguments,
    index: index
  ) {
    socketPath = parsedSocketArgument.socketPath
    return parsedSocketArgument.nextIndex
  }

  if let parsedConfigArgument = try parseValueArgument(
    option: CLI.configOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    configPath = parsedConfigArgument.value
    return parsedConfigArgument.nextIndex
  }

  return nil
}

/// Parses one `--flag value` or `--flag=value` option.
private func parseValueArgument(
  option: CLIOption,
  _ argument: String,
  arguments: [String],
  index: Int
) throws -> (value: String, nextIndex: Int)? {
  if let value = CLI.inlineValue(for: option, argument: argument) {
    guard !value.isEmpty else {
      throw AppError.message("missing value for \(option.flag)")
    }

    return (value, index + 1)
  }

  guard CLI.matches(option, argument: argument) else {
    return nil
  }

  let nextIndex = index + 1
  guard nextIndex < arguments.count else {
    throw AppError.message("missing value for \(argument)")
  }

  let value = arguments[nextIndex]
  guard !value.isEmpty else {
    throw AppError.message("missing value for \(argument)")
  }

  return (value, nextIndex + 1)
}

/// Parses `--socket`.
private func parseSocketArgument(
  _ argument: String,
  arguments: [String],
  index: Int
) throws -> (socketPath: String, nextIndex: Int)? {
  if let parsed = try parseValueArgument(
    option: CLI.socketOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    return (socketPath: parsed.value, nextIndex: parsed.nextIndex)
  }

  return nil
}

/// Sends one IPC command.
private func sendCommand(_ command: IPC.Command, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command.rawValue)' to \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: .makeCommand(command))

  switch response {
  case .accepted:
    context.debug("decoded response kind='accepted' message='<nil>'")

  case .rejected(let message):
    context.debug("decoded response kind='rejected' message='\(message ?? "<nil>")'")
    throw AppError.message(message ?? "command rejected")

  case .metrics:
    context.debug("decoded response kind='metrics' message='<nil>'")
    throw AppError.message("unexpected metrics response")
  }

  context.debug("command sent")
}

/// Fetches one metrics snapshot.
private func fetchMetricsSnapshot(from socketPath: String, context: AppContext) throws
  -> IPC.MetricsSnapshot
{
  context.debug("requesting metrics snapshot from \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: .makeMetrics())

  switch response {
  case .metrics(let metrics):
    return metrics

  case .rejected(let message):
    throw AppError.message(message ?? "metrics unavailable")

  case .accepted:
    throw AppError.message("metrics unavailable")
  }
}

/// Streams live metrics.
private func streamMetrics(to socketPath: String, context: AppContext) throws {
  let client = MetricsStreamClient(socketPath: socketPath)
  var history = MetricsHistory(limit: 32)
  let terminal = WatchTerminal()
  terminal.activate()
  defer { terminal.restore() }

  try client.stream(request: .makeMetrics(watch: true)) { message in
    switch message {
    case .metrics(let snapshot):
      history.append(snapshot)
      fputs(
        terminal.redrawPrefix + MetricsRenderer.watchText(snapshot, history: history),
        stdout
      )
      fflush(stdout)

    case .rejected(let message):
      throw AppError.message(message ?? "metrics rejected")

    case .accepted:
      return
    }
  }

  context.debug("metrics stream ended")
}

/// Validates config by running the EasyBar app in dry-run validation mode.
private func validateConfig(configPath: String?, context: AppContext) throws {
  let appPath = try resolveEasyBarExecutablePath()
  context.debug("validating config with app executable at \(appPath)")

  let process = Process()
  let outputPipe = Pipe()
  let errorPipe = Pipe()

  process.executableURL = URL(fileURLWithPath: appPath)
  process.standardOutput = outputPipe
  process.standardError = errorPipe

  var environment = ProcessInfo.processInfo.environment
  environment["EASYBAR_VALIDATE_CONFIG_ONLY"] = "1"
  if let configPath {
    environment[SharedEnvironmentKeys.configPath] = configPath
  }
  process.environment = environment

  try process.run()
  process.waitUntilExit()

  let output =
    String(
      data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
      encoding: .utf8
    ) ?? ""
  let errorOutput =
    String(
      data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
      encoding: .utf8
    ) ?? ""

  if process.terminationStatus == 0 {
    if !output.isEmpty {
      fputs(output, stdout)
    }
    return
  }

  let message =
    errorOutput
    .split(whereSeparator: \.isNewline)
    .joined(separator: "\n")
    .trimmingCharacters(in: .whitespacesAndNewlines)

  if !message.isEmpty {
    throw AppError.message(message)
  }

  throw AppError.message("config validation failed")
}

/// Resolves the EasyBar app executable used for dry-run validation.
private func resolveEasyBarExecutablePath() throws -> String {
  let fileManager = FileManager.default

  if let configuredPath = ProcessInfo.processInfo.environment["EASYBAR_APP_PATH"],
    fileManager.isExecutableFile(atPath: configuredPath)
  {
    return configuredPath
  }

  let cliExecutableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
  let executableDirectory = cliExecutableURL.deletingLastPathComponent()
  let candidates = [
    executableDirectory.appendingPathComponent("EasyBar").path,
    executableDirectory
      .appendingPathComponent("EasyBar.app")
      .appendingPathComponent("Contents")
      .appendingPathComponent("MacOS")
      .appendingPathComponent("EasyBar")
      .path,
  ]

  if let match = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
    return match
  }

  throw AppError.message(
    "unable to locate EasyBar executable for config validation; set EASYBAR_APP_PATH"
  )
}
