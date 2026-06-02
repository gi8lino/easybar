import Darwin
import EasyBarShared
import Foundation

/// App-level controller for the Lua runtime process.
///
/// This process stays intentionally small. It connects the configured Lua
/// transport socket, maps that connection onto standard input and output, and
/// then replaces itself with the configured Lua interpreter.
@main
final class AppController {
  /// Captures the command-line inputs for the Lua runtime process.
  private struct RuntimeArguments {
    let socketPath: String
    let luaPath: String
    let runtimePath: String
    let widgetsPath: String
    let widgetFiles: [String]
  }

  /// Runs the Lua runtime process.
  static func main() {
    Darwin.exit(AppController().run())
  }

  /// Starts the runtime bootstrap and returns the process exit code.
  func run() -> Int32 {
    do {
      let arguments = try parseArguments()
      let socketFileDescriptor = try connectSocket(path: arguments.socketPath)
      try duplicateTransportToStandardIO(fd: socketFileDescriptor)
      try execLua(arguments)
    } catch {
      fputs("EasyBarLuaRuntime: \(error.localizedDescription)\n", stderr)
      return 1
    }
  }

  /// Parses the runtime process command-line arguments.
  private func parseArguments() throws -> RuntimeArguments {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count >= 4 else {
      throw RuntimeBootstrapError.usage
    }

    return RuntimeArguments(
      socketPath: args[0],
      luaPath: args[1],
      runtimePath: args[2],
      widgetsPath: args[3],
      widgetFiles: Array(args.dropFirst(4))
    )
  }

  /// Connects the runtime process to the configured Lua transport socket.
  private func connectSocket(path: String) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw RuntimeBootstrapError.socketFailed(errno: errno)
    }

    guard configureNoSigPipe(fd: fd) else {
      close(fd)
      throw RuntimeBootstrapError.noSigPipeFailed
    }

    var address = makeSockAddrUn(path: path)
    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)

    let connectResult = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, addressLength)
      }
    }

    guard connectResult == 0 else {
      let message = String(cString: strerror(errno))
      close(fd)
      throw RuntimeBootstrapError.connectFailed(path: path, message: message)
    }

    return fd
  }

  /// Maps the connected transport socket onto standard input and output.
  private func duplicateTransportToStandardIO(fd: Int32) throws {
    guard dup2(fd, STDIN_FILENO) >= 0 else {
      let message = String(cString: strerror(errno))
      close(fd)
      throw RuntimeBootstrapError.dup2Failed(stream: "stdin", message: message)
    }

    guard dup2(fd, STDOUT_FILENO) >= 0 else {
      let message = String(cString: strerror(errno))
      close(fd)
      throw RuntimeBootstrapError.dup2Failed(stream: "stdout", message: message)
    }

    if fd > STDERR_FILENO {
      close(fd)
    }
  }

  /// Replaces the runtime process with the configured Lua interpreter.
  private func execLua(_ arguments: RuntimeArguments) throws -> Never {
    var argv: [UnsafeMutablePointer<CChar>?] = [
      strdup(arguments.luaPath),
      strdup(arguments.runtimePath),
      strdup(arguments.widgetsPath),
    ]

    argv.append(contentsOf: arguments.widgetFiles.map { strdup($0) })
    argv.append(nil)

    defer {
      for case let pointer? in argv {
        free(pointer)
      }
    }

    let execResult = argv.withUnsafeMutableBufferPointer { buffer in
      execv(arguments.luaPath, buffer.baseAddress)
    }

    guard execResult == -1 else {
      throw RuntimeBootstrapError.execUnexpectedlyReturned
    }

    let message = String(cString: strerror(errno))
    throw RuntimeBootstrapError.execFailed(luaPath: arguments.luaPath, message: message)
  }
}

/// Startup errors produced by the Lua runtime bootstrap process.
private enum RuntimeBootstrapError: LocalizedError {
  case usage
  case socketFailed(errno: Int32)
  case noSigPipeFailed
  case connectFailed(path: String, message: String)
  case dup2Failed(stream: String, message: String)
  case execUnexpectedlyReturned
  case execFailed(luaPath: String, message: String)

  /// Returns the user-facing startup error message.
  var errorDescription: String? {
    switch self {
    case .usage:
      return "usage: EasyBarLuaRuntime <socket-path> <lua-path> <runtime-path> <widgets-path> [widget-file...]"
    case .socketFailed(let errno):
      return "socket failed errno=\(errno)"
    case .noSigPipeFailed:
      return "failed to configure socket no-sigpipe"
    case .connectFailed(let path, let message):
      return "connect failed path=\(path) error=\(message)"
    case .dup2Failed(let stream, let message):
      return "dup2 \(stream) failed error=\(message)"
    case .execUnexpectedlyReturned:
      return "execv unexpectedly returned"
    case .execFailed(let luaPath, let message):
      return "execv failed lua=\(luaPath) error=\(message)"
    }
  }
}
