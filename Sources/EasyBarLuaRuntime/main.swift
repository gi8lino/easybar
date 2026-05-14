import Darwin
import EasyBarShared
import Foundation

/// Captures the command-line inputs for the Lua runtime agent.
private struct RuntimeArguments {
  let socketPath: String
  let luaPath: String
  let runtimePath: String
  let widgetsPath: String
}

/// Prints one startup error and exits the process.
private func fail(_ message: String) -> Never {
  fputs("EasyBarLuaRuntime: \(message)\n", stderr)
  exit(1)
}

/// Parses the runtime agent command-line arguments.
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

/// Connects the runtime agent to the configured Lua transport socket.
private func connectSocket(path: String) -> Int32 {
  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  guard fd >= 0 else {
    fail("socket failed errno=\(errno)")
  }

  guard configureNoSigPipe(fd: fd) else {
    close(fd)
    fail("failed to configure socket no-sigpipe")
  }

  var addr = makeSockAddrUn(path: path)
  let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

  let connectResult = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      connect(fd, $0, addrLen)
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

/// Replaces the runtime agent process with the configured Lua interpreter.
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

/// Starts the Lua runtime agent.
private func main() -> Never {
  let arguments = parseArguments()
  let fd = connectSocket(path: arguments.socketPath)
  duplicateTransportToStandardIO(fd: fd)
  execLua(arguments)
}

main()
