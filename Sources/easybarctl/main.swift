import EasyBarShared
import Foundation

/// The EasyBar CLI entry point.
@main
enum EasyBarCtlApp {
  /// Runs the CLI process.
  static func main() {
    exit(run())
  }
}

struct CommandFlag {
  let flag: String
  let command: String
}

struct ParsedArguments {
  let command: String
  let socketPath: String
  let debugEnabled: Bool
}

struct AppContext {
  let debugEnabled: Bool

  /// Writes one debug line when CLI debug logging is enabled.
  func debug(_ message: String) {
    let envEnabled = ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1"
    guard debugEnabled || envEnabled else { return }
    fputs("easybarctl: \(message)\n", stderr)
  }
}

enum AppError: Error {
  case showUsage
  case missingSocketValue(String)
  case emptySocketValue
  case duplicateCommand
  case unknownArgument(String)
  case missingCommand
  case socketCreationFailed
  case socketConnectionFailed(String)
  case commandSendFailed
}

let commandFlags: [CommandFlag] = [
  .init(flag: "--workspace-changed", command: "workspace_changed"),
  .init(flag: "--focus-changed", command: "focus_changed"),
  .init(flag: "--refresh", command: "refresh"),
  .init(flag: "--reload-config", command: "reload_config"),
]

/// Formats one help row with aligned option text.
func formatOption(_ option: String, _ description: String) -> String {
  "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
}

/// Prints usage text and exits the process.
func usage() {
  let commandList = commandFlags.map(\.flag).joined(separator: " | ")

  var lines: [String] = [
    "usage:",
    "  easybarctl <\(commandList)> [--socket <path>] [--debug]",
    "  easybarctl <\(commandList)> [-s <path>] [-d]",
    "",
    "options:",
  ]

  for item in commandFlags {
    lines.append(formatOption(item.flag, "Send \(item.command)"))
  }

  lines.append(formatOption("--socket, -s <path>", "Override socket path"))
  lines.append(formatOption("--debug, -d", "Enable debug output"))
  lines.append(formatOption("--help, -h", "Show this help"))

  fputs(lines.joined(separator: "\n") + "\n", stderr)
}

/// Parses CLI arguments into one validated command request.
func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedCommand: String?
  var socketPath = defaultSocketPath()
  var debugEnabled = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if arg == "--help" || arg == "-h" {
      throw AppError.showUsage
    }

    if arg == "--debug" || arg == "-d" {
      debugEnabled = true
      i += 1
      continue
    }

    if arg == "--socket" || arg == "-s" {
      i += 1
      guard i < arguments.count else {
        throw AppError.missingSocketValue(arg)
      }

      socketPath = arguments[i]
      i += 1
      continue
    }

    if arg.hasPrefix("--socket=") {
      socketPath = String(arg.dropFirst("--socket=".count))
      guard !socketPath.isEmpty else {
        throw AppError.emptySocketValue
      }

      i += 1
      continue
    }

    if let match = commandFlags.first(where: { $0.flag == arg }) {
      guard selectedCommand == nil else {
        throw AppError.duplicateCommand
      }

      selectedCommand = match.command
      i += 1
      continue
    }

    throw AppError.unknownArgument(arg)
  }

  guard let command = selectedCommand else {
    throw AppError.missingCommand
  }

  return ParsedArguments(
    command: command,
    socketPath: socketPath,
    debugEnabled: debugEnabled
  )
}

/// Connects to the EasyBar socket and sends one command string.
func sendCommand(_ command: String, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command)' to \(socketPath)")

  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  guard fd >= 0 else {
    context.debug("failed to create socket")
    throw AppError.socketCreationFailed
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
    context.debug("could not connect to \(socketPath)")
    throw AppError.socketConnectionFailed(socketPath)
  }

  context.debug("connected to socket")

  let writeResult = command.withCString {
    write(fd, $0, strlen($0))
  }

  guard writeResult >= 0 else {
    context.debug("failed to send command")
    throw AppError.commandSendFailed
  }

  context.debug("command sent")
}

/// Runs the CLI command flow and returns the process exit code.
func run() -> Int32 {
  do {
    let parsed = try parseArguments(CommandLine.arguments)
    let context = AppContext(debugEnabled: parsed.debugEnabled)
    try sendCommand(parsed.command, to: parsed.socketPath, context: context)
    return 0
  } catch AppError.showUsage {
    usage()
    return 1
  } catch AppError.missingSocketValue(let flag) {
    fputs("easybarctl: missing value for \(flag)\n", stderr)
  } catch AppError.emptySocketValue {
    fputs("easybarctl: missing value for --socket\n", stderr)
  } catch AppError.duplicateCommand {
    fputs("easybarctl: only one command flag may be specified\n", stderr)
  } catch AppError.unknownArgument(let arg) {
    fputs("easybarctl: unknown argument '\(arg)'\n", stderr)
  } catch AppError.missingCommand {
    fputs("easybarctl: no command flag provided\n", stderr)
  } catch {
    fputs("easybarctl: \(error)\n", stderr)
  }

  usage()
  return 1
}
