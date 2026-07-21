import EasyBarShared

/// Parses CLI arguments.
func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedAction: CLIAction?
  var socketPath: String?
  var configPath: String?
  var debugEnabled = false
  var watchMetrics = false
  var logOptionState = LogCommandOptionState()

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if arg == "logs" {
      guard selectedAction == nil else {
        throw AppError.message("only one command may be specified")
      }
      selectedAction = .logs
      i += 1
      continue
    }

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

    if let nextIndex = try parseLogArgument(
      arg,
      arguments: arguments,
      index: i,
      state: &logOptionState
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

  if configPath != nil, action != .validateConfig {
    throw AppError.message("--config may only be used with --validate-config")
  }

  if logOptionState.wasUsed, action != .logs {
    throw AppError.message("log options may only be used with the logs command")
  }

  if socketPath != nil, action == .logs {
    throw AppError.message("--socket cannot be used with the logs command")
  }

  let logOptions = try logOptionState.finalize()

  return ParsedArguments(
    action: action,
    socketPath: socketPath,
    configPath: configPath,
    debugEnabled: debugEnabled,
    watchMetrics: watchMetrics,
    logOptions: logOptions
  )
}

/// Parses one option accepted only by the `logs` command.
private func parseLogArgument(
  _ argument: String,
  arguments: [String],
  index: Int,
  state: inout LogCommandOptionState
) throws -> Int? {
  if let parsed = try parseValueArgument(
    option: CLI.logWidgetOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    state.options.widget = parsed.value
    state.wasUsed = true
    return parsed.nextIndex
  }

  if let parsed = try parseValueArgument(
    option: CLI.logRuntimeOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    guard let runtime = ProcessLogRuntime.normalized(parsed.value) else {
      throw AppError.message("--runtime expects lua, native, or agent")
    }
    state.options.runtime = runtime
    state.wasUsed = true
    return parsed.nextIndex
  }

  if let parsed = try parseValueArgument(
    option: CLI.logLevelOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    guard let level = ProcessLogLevel.normalized(parsed.value) else {
      throw AppError.message("--level expects trace, debug, info, warn, or error")
    }
    state.options.minimumLevel = level
    state.wasUsed = true
    return parsed.nextIndex
  }

  if let parsed = try parseValueArgument(
    option: CLI.logRequestIDOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    state.options.requestID = parsed.value
    state.wasUsed = true
    return parsed.nextIndex
  }

  if let parsed = try parseValueArgument(
    option: CLI.logSinceOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    state.options.since = parsed.value
    state.wasUsed = true
    return parsed.nextIndex
  }

  if let parsed = try parseValueArgument(
    option: CLI.logLinesOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    guard let count = Int(parsed.value), count > 0 else {
      throw AppError.message("--lines expects a positive integer")
    }
    state.options.historyLimit = count
    state.linesSpecified = true
    state.wasUsed = true
    return parsed.nextIndex
  }

  if CLI.matches(CLI.logAllOption, argument: argument) {
    state.allHistory = true
    state.wasUsed = true
    return index + 1
  }

  if CLI.matches(CLI.logNoFollowOption, argument: argument) {
    state.options.follow = false
    state.wasUsed = true
    return index + 1
  }

  if CLI.matches(CLI.logJSONOption, argument: argument) {
    state.options.json = true
    state.wasUsed = true
    return index + 1
  }

  return nil
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

  let restartOptions: [(CLIOption, CLIAction)] = [
    (CLI.restartCalendarAgentOption, .restartCalendarAgent),
    (CLI.restartNetworkAgentOption, .restartNetworkAgent),
    (CLI.restartAgentsOption, .restartAgents),
  ]
  if let restartAction = restartOptions.first(where: { CLI.matches($0.0, argument: argument) })?.1 {
    guard selectedAction == nil else {
      throw AppError.message("only one command flag may be specified")
    }
    selectedAction = restartAction
    return index + 1
  }

  if let parsedEventArgument = try parseValueArgument(
    option: CLI.eventOption,
    argument,
    arguments: arguments,
    index: index
  ) {
    guard selectedAction == nil else {
      throw AppError.message("only one command flag may be specified")
    }

    guard let command = CLI.eventCommand(for: parsedEventArgument.value) else {
      throw AppError.message("unknown event '\(parsedEventArgument.value)'")
    }

    selectedAction = .command(command)
    return parsedEventArgument.nextIndex
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
