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
  }

  /// Runs the Lua runtime process.
  static func main() {
    exit(AppController().run())
  }

  /// Starts the runtime bootstrap and returns the process exit code.
  func run() -> Int32 {
    let arguments = parseArguments()
    let socketFileDescriptor = connectSocket(path: arguments.socketPath)
    duplicateTransportToStandardIO(fd: socketFileDescriptor)
    execLua(arguments)
  }

  /// Parses the runtime process command-line arguments.
  private func parseArguments() -> RuntimeArguments {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 4 else {
      fail("usage: EasyBarLuaRuntime <socket-path> <lua-path> <runtime-path> <widgets-path>")
    }

    return RuntimeArguments(
      socketPath: args[0],
      luaPath: args[1],
      runtimePath: args[2],
      widgetsPath: args[3]
    )
  }

  /// Connects the runtime process to the configured Lua transport socket.
  private func connectSocket(path: String) -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      fail("socket failed errno=\(errno)")
    }

    guard configureNoSigPipe(fd: fd) else {
      close(fd)
      fail("failed to configure socket no-sigpipe")
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
      fail("connect failed path=\(path) error=\(message)")
    }

    return fd
  }

  /// Maps the connected transport socket onto standard input and output.
  private func duplicateTransportToStandardIO(fd: Int32) {
    guard dup2(fd, STDIN_FILENO) >= 0 else {
      let message = String(cString: strerror(errno))
      close(fd)
      fail("dup2 stdin failed error=\(message)")
    }

    guard dup2(fd, STDOUT_FILENO) >= 0 else {
      let message = String(cString: strerror(errno))
      close(fd)
      fail("dup2 stdout failed error=\(message)")
    }

    if fd > STDERR_FILENO {
      close(fd)
    }
  }

  /// Replaces the runtime process with the configured Lua interpreter.
  private func execLua(_ arguments: RuntimeArguments) -> Never {
    var argv: [UnsafeMutablePointer<CChar>?] = [
      strdup(arguments.luaPath),
      strdup(arguments.runtimePath),
      strdup(arguments.widgetsPath),
      nil,
    ]

    defer {
      for case let pointer? in argv {
        free(pointer)
      }
    }

    let execResult = argv.withUnsafeMutableBufferPointer { buffer in
      execv(arguments.luaPath, buffer.baseAddress)
    }

    guard execResult == -1 else {
      fatalError("execv unexpectedly returned")
    }

    let message = String(cString: strerror(errno))
    fail("execv failed lua=\(arguments.luaPath) error=\(message)")
  }

  /// Prints one startup error and exits the process.
  private func fail(_ message: String) -> Never {
    fputs("EasyBarLuaRuntime: \(message)\n", stderr)
    Foundation.exit(1)
  }
}
