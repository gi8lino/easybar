import Darwin
import EasyBarShared
import Foundation

/// Handles dedicated socket transport plus stderr logging for the Lua runtime process.
final class LuaTransport {
  private let logger: ProcessLogger
  private let logBridge: LuaLogBridge

  private let stateQueue = DispatchQueue(label: "easybar.lua.transport.state")
  private let writeQueue = DispatchQueue(label: "easybar.lua.transport.write")
  private let acceptQueue = DispatchQueue(label: "easybar.lua.transport.accept", qos: .utility)
  private let readQueue = DispatchQueue(label: "easybar.lua.transport.read", qos: .utility)

  private var generation: UInt64 = 0
  private var socketPath: String?
  private var listenerFD: Int32 = -1
  private var clientFD: Int32 = -1
  private var errorPipe: Pipe?
  private var readSource: DispatchSourceRead?
  private var lineHandler: (@Sendable (String) -> Void)?

  /// Creates one Lua transport.
  init(logger: ProcessLogger) {
    self.logger = logger
    self.logBridge = LuaLogBridge(logger: logger.child("stderr"))
  }

  /// Starts listening on the configured Lua socket and installs stderr handling.
  func startListening(
    socketPath: String,
    error: Pipe,
    lineHandler: @escaping @Sendable (String) -> Void
  ) {
    stateQueue.sync {
      shutdownLocked()

      self.socketPath = socketPath
      self.errorPipe = error
      self.lineHandler = lineHandler
      generation &+= 1

      installErrorReadabilityHandler(generation: generation)
      listenerFD = makeListeningSocket(at: socketPath)
      let currentGeneration = generation

      acceptQueue.async { [weak self] in
        self?.acceptConnection(generation: currentGeneration)
      }
    }
  }

  /// Stops socket, stderr handling, and all active read sources.
  func shutdown() {
    stateQueue.sync {
      shutdownLocked()
    }
  }

  /// Sends one encoded event line to the Lua runtime socket.
  func send(_ string: String) {
    guard let data = (string + "\n").data(using: .utf8) else { return }

    writeQueue.async { [weak self] in
      guard let self else { return }

      let fd = self.stateQueue.sync { self.clientFD }
      guard fd >= 0 else {
        self.logger.debug("cannot send event, lua socket not connected")
        return
      }

      if writeAll(data, to: fd) {
        MetricsCoordinator.shared.recordLuaWrite()
        self.logger.trace("sent to lua socket", .field("payload", string))
      } else {
        self.logger.error("failed writing to lua socket", .field("path", self.stateQueue.sync { self.socketPath ?? "" }))
      }
    }
  }

  /// Stops all transport resources under the state lock.
  private func shutdownLocked() {
    generation &+= 1

    readSource?.cancel()
    readSource = nil

    stopReadabilityHandler(for: errorPipe)

    let currentListener = listenerFD
    let currentClient = clientFD
    let currentSocketPath = socketPath
    let currentErrorPipe = errorPipe

    listenerFD = -1
    clientFD = -1
    socketPath = nil
    errorPipe = nil
    lineHandler = nil

    if currentClient >= 0 {
      Darwin.shutdown(currentClient, SHUT_RDWR)
      close(currentClient)
    }

    if currentListener >= 0 {
      Darwin.shutdown(currentListener, SHUT_RDWR)
      close(currentListener)
    }

    if let currentSocketPath {
      unlink(currentSocketPath)
    }

    try? currentErrorPipe?.fileHandleForReading.close()
    try? currentErrorPipe?.fileHandleForWriting.close()
  }

  /// Creates and binds the listening Unix socket.
  private func makeListeningSocket(at socketPath: String) -> Int32 {
    let socketURL = URL(fileURLWithPath: socketPath)
    let socketDir = socketURL.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)
    } catch {
      logger.error(
        "failed to create lua socket directory",
        .field("path", socketDir.path),
        .field("error", "\(error)")
      )
      return -1
    }

    unlink(socketPath)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.error("failed to create lua socket", .field("errno", errno))
      return -1
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.error("failed to configure lua socket no-sigpipe", .field("fd", fd))
      close(fd)
      return -1
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      logger.error(
        "lua socket bind failed",
        .field("path", socketPath),
        .field("errno", errno)
      )
      close(fd)
      return -1
    }

    if chmod(socketPath, mode_t(0o600)) != 0 {
      logger.warn(
        "lua socket chmod failed",
        .field("path", socketPath),
        .field("errno", errno)
      )
    }

    guard listen(fd, 1) == 0 else {
      logger.error(
        "lua socket listen failed",
        .field("path", socketPath),
        .field("errno", errno)
      )
      close(fd)
      unlink(socketPath)
      return -1
    }

    logger.info("lua socket listening", .field("socket_path", socketPath))
    return fd
  }

  /// Accepts one runtime connection when still current.
  private func acceptConnection(generation: UInt64) {
    let listenerFD = stateQueue.sync {
      self.generation == generation ? self.listenerFD : -1
    }

    guard listenerFD >= 0 else { return }

    let clientFD = accept(listenerFD, nil, nil)
    guard clientFD >= 0 else {
      if errno != EINVAL && errno != EBADF {
        logger.error("lua socket accept failed", .field("errno", errno))
      }
      return
    }

    guard configureNoSigPipe(fd: clientFD) else {
      logger.error("failed to configure lua client socket no-sigpipe", .field("fd", clientFD))
      close(clientFD)
      return
    }

    let shouldInstall = stateQueue.sync { () -> Bool in
      guard self.generation == generation else {
        return false
      }

      self.clientFD = clientFD
      self.installReadSourceLocked(fd: clientFD, generation: generation)
      return true
    }

    if shouldInstall {
      logger.debug("lua socket connected", .field("fd", clientFD))
    } else {
      close(clientFD)
    }
  }

  /// Installs the raw line reader for one connected Lua socket.
  private func installReadSourceLocked(fd: Int32, generation: UInt64) {
    let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: readQueue)
    var buffer = Data()

    source.setEventHandler { [weak self] in
      guard let self else { return }

      let stillCurrent = self.stateQueue.sync {
        self.generation == generation && self.clientFD == fd
      }
      guard stillCurrent else {
        source.cancel()
        return
      }

      var chunk = [UInt8](repeating: 0, count: 4096)
      let count = read(fd, &chunk, chunk.count)

      if count <= 0 {
        if count < 0 && errno == EINTR {
          return
        }

        source.cancel()
        self.stateQueue.sync {
          if self.clientFD == fd {
            self.clientFD = -1
          }
        }
        close(fd)
        return
      }

      buffer.append(chunk, count: count)

      while let newlineIndex = buffer.firstIndex(of: 0x0A) {
        let lineData = buffer.prefix(upTo: newlineIndex)
        buffer.removeSubrange(...newlineIndex)

        guard let line = self.decodeLine(from: lineData) else { continue }
        MetricsCoordinator.shared.recordLuaTransportLine()
        self.logger.debug("lua socket raw: \(line)")
        self.lineHandler?(line)
      }
    }

    source.setCancelHandler {
      buffer.removeAll()
    }

    source.resume()
    readSource = source
  }

  /// Installs the stderr handler used for Lua/widget logs and runtime failures.
  private func installErrorReadabilityHandler(generation: UInt64) {
    guard let pipe = errorPipe else { return }

    installReadabilityHandler(on: pipe, generation: generation) { [logBridge] line in
      MetricsCoordinator.shared.recordLuaStderrLine()
      logBridge.handle(line)
    }
  }

  /// Installs one buffered newline-delimited readability handler on a pipe.
  private func installReadabilityHandler(
    on pipe: Pipe,
    generation: UInt64,
    handleLine: @escaping (String) -> Void
  ) {
    var buffer = Data()

    pipe.fileHandleForReading.readabilityHandler = { [weak self, weak pipe] handle in
      guard let self, let pipe else { return }

      let stillCurrent = self.stateQueue.sync {
        self.generation == generation && pipe === self.errorPipe
      }

      guard stillCurrent else {
        handle.readabilityHandler = nil
        return
      }

      let data = handle.availableData

      if data.isEmpty {
        if let line = self.decodeLine(from: buffer[...]) {
          handleLine(line)
        }

        buffer.removeAll()
        handle.readabilityHandler = nil
        return
      }

      buffer.append(data)

      while let newlineIndex = buffer.firstIndex(of: 0x0A) {
        let lineData = buffer.prefix(upTo: newlineIndex)
        buffer.removeSubrange(...newlineIndex)

        guard let line = self.decodeLine(from: lineData) else { continue }
        handleLine(line)
      }
    }
  }

  /// Decodes one non-empty UTF-8 line.
  private func decodeLine(from data: Data.SubSequence) -> String? {
    guard
      let line = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !line.isEmpty
    else {
      return nil
    }

    return line
  }

  /// Stops the readability handler for one error pipe.
  private func stopReadabilityHandler(for pipe: Pipe?) {
    pipe?.fileHandleForReading.readabilityHandler = nil
  }
}
