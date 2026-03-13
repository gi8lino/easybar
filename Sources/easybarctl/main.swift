import Foundation

let socketPath = "/tmp/easybar.sock"

/// Allowed commands sent to EasyBar.
let allowedCommands = [
    "workspace_changed",
    "focus_changed",
    "refresh",
    "reload_config"
]

/// Prints debug messages when EASYBAR_DEBUG=1 is set.
func debug(_ message: String) {
    if ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1" {
        fputs("easybarctl: \(message)\n", stderr)
    }
}

/// Ensure a command was provided.
guard CommandLine.arguments.count > 1 else {
    fputs("usage: easybarctl <command>\n", stderr)
    exit(1)
}

let command = CommandLine.arguments[1]

/// Validate command
guard allowedCommands.contains(command) else {
    fputs("easybarctl: unknown command '\(command)'\n", stderr)
    exit(1)
}

debug("sending command '\(command)'")

/// Create Unix socket
let fd = socket(AF_UNIX, SOCK_STREAM, 0)

guard fd >= 0 else {
    debug("failed to create socket")
    exit(1)
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)

_ = socketPath.withCString { path in
    strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path))
}

let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

/// Connect to EasyBar socket
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

/// Send command
_ = command.withCString {
    write(fd, $0, strlen($0))
}

debug("command sent")

close(fd)
