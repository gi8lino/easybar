import EasyBarShared
import Foundation

struct CommandFlag {
  let flag: String
  let command: String
}

let commandFlags: [CommandFlag] = [
  .init(flag: "--workspace-changed", command: "workspace_changed"),
  .init(flag: "--focus-changed", command: "focus_changed"),
  .init(flag: "--refresh", command: "refresh"),
  .init(flag: "--reload-config", command: "reload_config"),
]

func formatOption(_ option: String, _ description: String) -> String {
  "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
}

func usage() -> Never {
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
  exit(1)
}

func parseArguments(_ arguments: [String]) -> (command: String, socketPath: String, debug: Bool)? {
  var selectedCommand: String?
  var socketPath = defaultSocketPath()
  var debugEnabled = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if arg == "--help" || arg == "-h" {
      usage()
    }

    if arg == "--debug" || arg == "-d" {
      debugEnabled = true
      i += 1
      continue
    }

    if arg == "--socket" || arg == "-s" {
      i += 1
      guard i < arguments.count else {
        fputs("easybarctl: missing value for \(arg)\n", stderr)
        usage()
      }

      socketPath = arguments[i]
      i += 1
      continue
    }

    if arg.hasPrefix("--socket=") {
      socketPath = String(arg.dropFirst("--socket=".count))
      guard !socketPath.isEmpty else {
        fputs("easybarctl: missing value for --socket\n", stderr)
        usage()
      }

      i += 1
      continue
    }

    if let match = commandFlags.first(where: { $0.flag == arg }) {
      guard selectedCommand == nil else {
        fputs("easybarctl: only one command flag may be specified\n", stderr)
        usage()
      }

      selectedCommand = match.command
      i += 1
      continue
    }

    fputs("easybarctl: unknown argument '\(arg)'\n", stderr)
    usage()
  }

  guard let command = selectedCommand else {
    fputs("easybarctl: no command flag provided\n", stderr)
    usage()
  }

  return (command, socketPath, debugEnabled)
}

guard let parsed = parseArguments(CommandLine.arguments) else {
  usage()
}

let command = parsed.command
let socketPath = parsed.socketPath
let debugEnabled = parsed.debug

func debug(_ message: String) {
  let envEnabled = ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1"
  guard debugEnabled || envEnabled else { return }
  fputs("easybarctl: \(message)\n", stderr)
}

debug("sending command '\(command)' to \(socketPath)")

let fd = socket(AF_UNIX, SOCK_STREAM, 0)

guard fd >= 0 else {
  debug("failed to create socket")
  exit(1)
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
  debug("could not connect to \(socketPath)")
  exit(1)
}

debug("connected to socket")

let writeResult = command.withCString {
  write(fd, $0, strlen($0))
}

guard writeResult >= 0 else {
  debug("failed to send command")
  exit(1)
}

debug("command sent")
