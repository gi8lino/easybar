import EasyBarShared
import Foundation

/// The EasyBar CLI entry point.
@main
enum EasyBarCtlApp {
  /// Runs the CLI process.
  static func main() {
    exit(AppController().run())
  }
}

/// Coordinates argument parsing, command dispatch, and CLI output.
private struct AppController {
  /// Runs the CLI command flow and returns the process exit code.
  func run() -> Int32 {
    do {
      let parsed = try parseArguments(CommandLine.arguments)
      let context = AppContext(debugEnabled: parsed.debugEnabled)
      try sendCommand(parsed.command, to: parsed.socketPath, context: context)
      return 0
    } catch AppError.showUsage {
      CLI.printUsage()
      return 1
    } catch AppError.showVersion {
      CLI.printVersion()
      return 0
    } catch AppError.message(let message) {
      CLI.printError(message)
    } catch {
      CLI.printError("\(error)")
    }

    CLI.printUsage()
    return 1
  }
}

private struct CLIOption {
  let flag: String
  let short: String?
  let command: IPC.Command?
  let description: String
  let placeholder: String?

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

private struct ParsedArguments {
  let command: IPC.Command
  let socketPath: String
  let debugEnabled: Bool
}

private struct AppContext {
  private let logger: ProcessLogger
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(debugEnabled: Bool) {
    logger = ProcessLogger(label: "easybarctl") {
      let envEnabled = ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1"
      return debugEnabled || envEnabled
    }
  }

  /// Writes one debug line when CLI debug logging is enabled.
  func debug(_ message: String) {
    logger.debug(message)
  }

  /// Encodes one IPC request.
  func encode(_ request: IPC.Request) throws -> Data {
    try encoder.encode(request)
  }

  /// Decodes one IPC response.
  func decodeResponse(from data: Data) throws -> IPC.Response {
    try decoder.decode(IPC.Response.self, from: data)
  }
}

private enum AppError: Error {
  case showUsage
  case showVersion
  case message(String)
}

private enum CLI {
  static let socketOption = CLIOption(
    flag: "--socket",
    short: "-s",
    description: "Override socket path",
    placeholder: "path"
  )
  static let debugOption = CLIOption(
    flag: "--debug",
    short: "-d",
    description: "Enable debug output"
  )
  static let versionOption = CLIOption(
    flag: "--version",
    short: "-v",
    description: "Show the easybarctl version"
  )
  static let helpOption = CLIOption(
    flag: "--help",
    short: "-h",
    description: "Show this help"
  )

  static let cmdOptions: [CLIOption] = [
    .init(
      flag: "--workspace-changed",
      command: .workspaceChanged,
      description: "Send workspace_changed"
    ),
    .init(
      flag: "--focus-changed",
      command: .focusChanged,
      description: "Send focus_changed"
    ),
    .init(
      flag: "--refresh",
      command: .refresh,
      description: "Send refresh"
    ),
    .init(
      flag: "--reload-config",
      command: .reloadConfig,
      description: "Send reload_config"
    ),
  ]

  static let appOptions: [CLIOption] = [
    socketOption,
    debugOption,
    versionOption,
    helpOption,
  ]

  /// Formats one help row with aligned option text.
  static func formatOption(_ option: String, _ description: String) -> String {
    "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
  }

  /// Returns the rendered text for one option, including short flag and placeholder.
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

  /// Returns whether one argument matches an option's long or short flag.
  static func matches(_ option: CLIOption, argument: String) -> Bool {
    option.flag == argument || option.short == argument
  }

  /// Returns the inline `--flag=value` payload when present.
  static func inlineValue(for option: CLIOption, argument: String) -> String? {
    let prefix = "\(option.flag)="
    guard argument.hasPrefix(prefix) else { return nil }
    return String(argument.dropFirst(prefix.count))
  }

  /// Returns the command string associated with one argument when it is a command option.
  static func command(for argument: String) -> IPC.Command? {
    cmdOptions.first { matches($0, argument: argument) }?.command
  }

  /// Writes one plain error line.
  static func printError(_ message: String) {
    fputs("easybarctl: \(message)\n", stderr)
  }

  /// Writes one plain version line.
  static func printVersion() {
    fputs("easybarctl \(BuildInfo.appVersion)\n", stdout)
  }

  /// Writes usage text.
  static func printUsage() {
    let commandLines = cmdOptions.map {
      formatOption(optionText(for: $0), $0.description)
    }
    let appOptionLines = appOptions.map {
      formatOption(optionText(for: $0), $0.description)
    }

    let lines: [String] =
      [
        "usage:",
        "  easybarctl <command> [options]",
        "",
        "commands:",
      ] + commandLines + [
        "",
        "options:",
      ] + appOptionLines

    fputs(lines.joined(separator: "\n") + "\n", stderr)
  }
}

/// Parses CLI arguments into one validated command request.
private func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedCommand: IPC.Command?
  var socketPath = SharedRuntimeConfig.current.easyBarSocketPath
  var debugEnabled = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if CLI.matches(CLI.helpOption, argument: arg) {
      throw AppError.showUsage
    }

    if CLI.matches(CLI.versionOption, argument: arg) {
      throw AppError.showVersion
    }

    if CLI.matches(CLI.debugOption, argument: arg) {
      debugEnabled = true
      i += 1
      continue
    }

    if let parsedSocketArgument = try parseSocketArgument(
      arg,
      arguments: arguments,
      index: i
    ) {
      socketPath = parsedSocketArgument.socketPath
      i = parsedSocketArgument.nextIndex
      continue
    }

    if let command = CLI.command(for: arg) {
      guard selectedCommand == nil else {
        throw AppError.message("only one command flag may be specified")
      }

      selectedCommand = command
      i += 1
      continue
    }

    throw AppError.message("unknown argument '\(arg)'")
  }

  guard let command = selectedCommand else {
    throw AppError.message("no command flag provided")
  }

  return ParsedArguments(
    command: command,
    socketPath: socketPath,
    debugEnabled: debugEnabled
  )
}

/// Parses one socket option and returns the resolved value plus next index.
private func parseSocketArgument(
  _ argument: String,
  arguments: [String],
  index: Int
) throws -> (socketPath: String, nextIndex: Int)? {
  if let value = CLI.inlineValue(for: CLI.socketOption, argument: argument) {
    guard !value.isEmpty else {
      throw AppError.message("missing value for \(CLI.socketOption.flag)")
    }

    return (value, index + 1)
  }

  guard CLI.matches(CLI.socketOption, argument: argument) else {
    return nil
  }

  let nextIndex = index + 1
  guard nextIndex < arguments.count else {
    throw AppError.message("missing value for \(argument)")
  }

  let socketPath = arguments[nextIndex]
  guard !socketPath.isEmpty else {
    throw AppError.message("missing value for \(argument)")
  }

  return (socketPath, nextIndex + 1)
}

/// Connects to the EasyBar socket and sends one IPC command.
private func sendCommand(_ command: IPC.Command, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command.rawValue)' to \(socketPath)")

  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  guard fd >= 0 else {
    throw AppError.message("failed to create socket")
  }

  defer { close(fd) }

  var addr = makeSockAddrUn(path: socketPath)
  let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

  let result = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      connect(fd, $0, addrLen)
    }
  }

  guard result >= 0 else {
    throw AppError.message("could not connect to \(socketPath)")
  }

  context.debug("connected to socket")

  let requestData = try context.encode(IPC.Request(command: command))
  let writeResult = requestData.withUnsafeBytes {
    guard let baseAddress = $0.baseAddress else { return -1 }
    return write(fd, baseAddress, $0.count)
  }

  guard writeResult >= 0 else {
    throw AppError.message("failed to send command")
  }

  var buffer = [UInt8](repeating: 0, count: 256)
  let readResult = read(fd, &buffer, 255)
  guard readResult >= 0 else {
    throw AppError.message("failed to read IPC response")
  }

  let responseData = Data(buffer.prefix(readResult))
  let response = try context.decodeResponse(from: responseData)
  guard response.accepted else {
    throw AppError.message(response.message ?? "command rejected")
  }

  context.debug("command sent")
}
