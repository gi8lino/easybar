import Darwin
import EasyBarShared
import Foundation

private struct LauncherArguments {
  let socketPath: String
  let luaPath: String
  let runtimePath: String
  let widgetsPath: String
}

private func fail(_ message: String) -> Never {
  fputs("EasyBarLuaLauncher: \(message)\n", stderr)
  exit(1)
}

private func parseArguments() -> LauncherArguments {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 4 else {
    fail("usage: EasyBarLuaLauncher <socket-path> <lua-path> <runtime-path> <widgets-path>")
  }

  return LauncherArguments(
    socketPath: args[0],
    luaPath: args[1],
    runtimePath: args[2],
    widgetsPath: args[3]
  )
}

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

private func execLua(_ arguments: LauncherArguments) -> Never {
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

private func main() -> Never {
  let arguments = parseArguments()
  let fd = connectSocket(path: arguments.socketPath)
  duplicateTransportToStandardIO(fd: fd)
  execLua(arguments)
}

main()
