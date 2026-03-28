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
  let command: String?
  let description: String
  let placeholder: String?

  init(
    flag: String,
    short: String? = nil,
    command: String? = nil,
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
  let command: String
  let socketPath: String
  let debugEnabled: Bool
}

private struct AppContext {
  private let logger: ProcessLogger

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
}

private enum AppError: Error {
  case showUsage
  case showVersion
  case message(String)
}

private enum CLI {
  static let cmdOptions: [CLIOption] = [
    .init(
      flag: "--workspace-changed",
      command: "workspace_changed",
      description: "Send workspace_changed"
    ),
    .init(
      flag: "--focus-changed",
      command: "focus_changed",
      description: "Send focus_changed"
    ),
    .init(
      flag: "--refresh",
      command: "refresh",
      description: "Send refresh"
    ),
    .init(
      flag: "--reload-config",
      command: "reload_config",
      description: "Send reload_config"
    ),
  ]

  static let appOptions: [CLIOption] = [
    .init(
      flag: "--socket",
      short: "-s",
      description: "Override socket path",
      placeholder: "path"
    ),
    .init(
      flag: "--debug",
      short: "-d",
      description: "Enable debug output"
    ),
    .init(
      flag: "--version",
      short: "-v",
      description: "Show the easybarctl version"
    ),
    .init(
      flag: "--help",
      short: "-h",
      description: "Show this help"
    ),
  ]

  /// Formats one help row with aligned option text.
  static func formatOption(_ option: String, _ description: String) -> String {
    "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
  }

  /// Returns all options in help-display order.
  static var options: [CLIOption] {
    cmdOptions + appOptions
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

  /// Returns the rendered placeholder suffix for one option.
  static func placeholderText(for option: CLIOption) -> String {
    guard let placeholder = option.placeholder else { return "" }
    return " <\(placeholder)>"
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
    let commandList = cmdOptions.map(\.flag).joined(separator: " | ")
    let optionLines = options.map {
      formatOption(optionText(for: $0), $0.description)
    }

    let usageLong = appOptions.map { option in
      option.flag + placeholderText(for: option)
    }.joined(separator: " ")
    let usageShort = appOptions.compactMap { option in
      guard let short = option.short else { return nil }
      return short + placeholderText(for: option)
    }.joined(separator: " ")

    let lines: [String] =
      [
        "usage:",
        "  easybarctl <\(commandList)> [\(usageLong)]",
        "  easybarctl <\(commandList)> [\(usageShort)]",
        "",
        "options:",
      ] + optionLines

    fputs(lines.joined(separator: "\n") + "\n", stderr)
  }
}

/// Parses CLI arguments into one validated command request.
private func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedCommand: String?
  var socketPath = defaultSocketPath()
  var debugEnabled = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if arg == "--help" || arg == "-h" {
      throw AppError.showUsage
    }

    if arg == "--version" || arg == "-v" {
      throw AppError.showVersion
    }

    if arg == "--debug" || arg == "-d" {
      debugEnabled = true
      i += 1
      continue
    }

    if arg == "--socket" || arg == "-s" {
      i += 1
      guard i < arguments.count else {
        throw AppError.message("missing value for \(arg)")
      }

      socketPath = arguments[i]
      guard !socketPath.isEmpty else {
        throw AppError.message("missing value for \(arg)")
      }

      i += 1
      continue
    }

    if arg.hasPrefix("--socket=") {
      socketPath = String(arg.dropFirst("--socket=".count))
      guard !socketPath.isEmpty else {
        throw AppError.message("missing value for --socket")
      }

      i += 1
      continue
    }

    if let match = CLI.cmdOptions.first(where: { $0.flag == arg || $0.short == arg }) {
      guard selectedCommand == nil else {
        throw AppError.message("only one command flag may be specified")
      }

      guard let command = match.command else {
        throw AppError.message("unknown argument '\(arg)'")
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

/// Connects to the EasyBar socket and sends one command string.
private func sendCommand(_ command: String, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command)' to \(socketPath)")

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

  let writeResult = command.withCString {
    write(fd, $0, strlen($0))
  }

  guard writeResult >= 0 else {
    throw AppError.message("failed to send command")
  }

  context.debug("command sent")
}
