import EasyBarShared

/// Parses CLI arguments.
func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
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
