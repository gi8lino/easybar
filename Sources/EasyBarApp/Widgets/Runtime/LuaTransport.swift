import Darwin
import EasyBarShared
import Foundation

private enum LuaTransportLimits {
  /// Maximum bytes buffered for one newline-delimited JSON message from Lua.
  static let maxLineBytes = 1024 * 1024
}

/// Handles dedicated socket transport plus stderr logging for the Lua runtime process.
///
/// Sendability is guarded by `LockedState`; file descriptors, task handles, and
/// the current line handler are all read or changed through that lock. Outbound
/// socket writes are additionally serialized by `writerQueue` so JSON lines keep
/// their ordering and cannot interleave on the stream socket.
final class LuaTransport: @unchecked Sendable {
  /// Startup errors surfaced while preparing the transport.
  enum TransportError: LocalizedError {
    case startupFailed(String)

    var errorDescription: String? {
      switch self {
      case .startupFailed(let message):
        return message
      }
    }
  }

  private struct State {
    var generation: UInt64 = 0
    var socketPath: String?
    var listenerFD: Int32 = -1
    var clientFD: Int32 = -1
    var errorPipe: Pipe?
    var acceptTask: Task<Void, Never>?
    var readTask: Task<Void, Never>?
    var stderrTask: Task<Void, Never>?
    var lineHandler: (@Sendable (String) -> Void)?
  }

  private let logger: ProcessLogger
  private let logBridge: LuaLogBridge
  private let state = LockedState(State())
  private let writerQueue = DispatchQueue(label: "easybar.lua-transport.writer")

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
  ) throws {
    shutdown()

    let listenerFD = try makeListeningSocket(at: socketPath)
    let generation = state.withLock { state -> UInt64 in
      state.socketPath = socketPath
      state.errorPipe = error
      state.lineHandler = lineHandler
      state.listenerFD = listenerFD
      state.generation &+= 1
      return state.generation
    }

    let stderrFD = error.fileHandleForReading.fileDescriptor
    let stderrTask = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      self.readLinesFromFD(stderrFD, generation: generation) { [weak self] line in
        Task {
          await MetricsCoordinator.shared.recordLuaStderrLine()
        }
        self?.logBridge.handle(line)
      }
    }

    let acceptTask = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      self.acceptConnection(generation: generation)
    }

    state.withLock { state in
      guard state.generation == generation else {
        stderrTask.cancel()
        acceptTask.cancel()
        return
      }
      state.stderrTask = stderrTask
      state.acceptTask = acceptTask
    }
  }

  /// Stops socket, stderr handling, and all active read tasks.
  func shutdown() {
    let snapshot = state.withLock { state -> State in
      state.generation &+= 1
      let snapshot = state
      state.socketPath = nil
      state.listenerFD = -1
      state.clientFD = -1
      state.errorPipe = nil
      state.acceptTask = nil
      state.readTask = nil
      state.stderrTask = nil
      state.lineHandler = nil
      return snapshot
    }

    snapshot.acceptTask?.cancel()
    snapshot.readTask?.cancel()
    snapshot.stderrTask?.cancel()

    // Drain queued writes after the generation was invalidated but before the
    // file descriptors are closed. This prevents a stale queued send from
    // writing to a descriptor after the OS has reused it for another resource.
    writerQueue.sync {}

    if snapshot.clientFD >= 0 {
      Darwin.shutdown(snapshot.clientFD, SHUT_RDWR)
      close(snapshot.clientFD)
    }

    if snapshot.listenerFD >= 0 {
      Darwin.shutdown(snapshot.listenerFD, SHUT_RDWR)
      close(snapshot.listenerFD)
    }

    if let socketPath = snapshot.socketPath {
      unlink(socketPath)
    }

    try? snapshot.errorPipe?.fileHandleForReading.close()
    try? snapshot.errorPipe?.fileHandleForWriting.close()
  }

  /// Sends one encoded event line to the Lua runtime socket.
  func send(_ string: String) {
    guard let data = (string + "\n").data(using: .utf8) else { return }

    let snapshot = state.withLock { state in
      (generation: state.generation, clientFD: state.clientFD)
    }

    guard snapshot.clientFD >= 0 else {
      logger.debug("cannot send event, lua socket not connected")
      return
    }

    let byteCount = string.utf8.count
    writerQueue.async { [weak self, data, snapshot, byteCount] in
      guard let self else { return }
      guard self.isCurrentClientFD(snapshot.clientFD, generation: snapshot.generation) else {
        self.logger.debug("dropping stale lua socket write")
        return
      }

      if writeAll(data, to: snapshot.clientFD) {
        Task {
          await MetricsCoordinator.shared.recordLuaWrite()
        }
        self.logger.trace("sent to lua socket", .field("bytes", byteCount))
      } else {
        self.logger.error("failed writing to lua socket")
      }
    }
  }

  /// Creates and binds the listening Unix socket.
  private func makeListeningSocket(at socketPath: String) throws -> Int32 {
    let socketURL = URL(fileURLWithPath: socketPath)
    let socketDir = socketURL.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)
    } catch {
      throw TransportError.startupFailed(
        "failed to create lua socket directory path=\(socketDir.path) error=\(error)"
      )
    }

    unlink(socketPath)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw TransportError.startupFailed("failed to create lua socket errno=\(errno)")
    }

    guard configureNoSigPipe(fd: fd) else {
      close(fd)
      throw TransportError.startupFailed("failed to configure lua socket no-sigpipe fd=\(fd)")
    }

    let addr: sockaddr_un
    do {
      addr = try makeSockAddrUn(path: socketPath)
    } catch {
      close(fd)
      unlink(socketPath)
      throw TransportError.startupFailed("invalid lua socket path path=\(socketPath) error=\(error)")
    }

    var mutableAddr = addr
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &mutableAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      close(fd)
      throw TransportError.startupFailed("lua socket bind failed path=\(socketPath) errno=\(errno)")
    }

    if chmod(socketPath, mode_t(0o600)) != 0 {
      logger.warn(
        "lua socket chmod failed",
        .field("path", socketPath),
        .field("errno", errno)
      )
    }

    guard listen(fd, 1) == 0 else {
      close(fd)
      unlink(socketPath)
      throw TransportError.startupFailed("lua socket listen failed path=\(socketPath) errno=\(errno)")
    }

    logger.debug("lua socket listening", .field("socket_path", socketPath))
    return fd
  }

  /// Accepts one runtime connection when still current.
  private func acceptConnection(generation: UInt64) {
    let listenerFD = state.withLock { state in
      state.generation == generation ? state.listenerFD : -1
    }

    guard listenerFD >= 0 else { return }

    let clientFD = accept(listenerFD, nil, nil)
    guard clientFD >= 0 else {
      if shouldLogAcceptFailure(errnoValue: errno) {
        logger.error("lua socket accept failed", .field("errno", errno))
      }
      return
    }

    guard configureNoSigPipe(fd: clientFD) else {
      logger.error("failed to configure lua client socket no-sigpipe", .field("fd", clientFD))
      close(clientFD)
      return
    }

    let lineHandler = state.withLock { state -> (@Sendable (String) -> Void)? in
      guard state.generation == generation else {
        return nil
      }

      state.clientFD = clientFD
      return state.lineHandler
    }

    guard let lineHandler else {
      close(clientFD)
      return
    }

    let readTask = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      self.readLinesFromFD(clientFD, generation: generation) { [weak self] line in
        Task {
          await MetricsCoordinator.shared.recordLuaTransportLine()
        }
        self?.logger.debug("lua socket line received", .field("bytes", line.utf8.count))
        lineHandler(line)
      }

      self.clearClientFD(clientFD, generation: generation)
    }

    state.withLock { state in
      guard state.generation == generation, state.clientFD == clientFD else {
        readTask.cancel()
        return
      }
      state.readTask = readTask
    }

    logger.debug("lua socket connected", .field("fd", clientFD))
  }

  /// Reads buffered newline-delimited UTF-8 lines from one fd until it closes.
  private func readLinesFromFD(
    _ fd: Int32,
    generation: UInt64,
    handleLine: @escaping @Sendable (String) -> Void
  ) {
    var pending = Data()
    var isDroppingOversizedLine = false
    var buffer = [UInt8](repeating: 0, count: 4096)

    while !Task.isCancelled, isCurrent(generation: generation) {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        let bytes = buffer.prefix(count)

        if isDroppingOversizedLine {
          guard let newlineIndex = bytes.firstIndex(of: 0x0A) else {
            continue
          }

          pending.removeAll(keepingCapacity: true)
          let afterNewline = bytes.index(after: newlineIndex)
          if afterNewline < bytes.endIndex {
            pending.append(contentsOf: bytes[afterNewline...])
          }
          isDroppingOversizedLine = false
        } else {
          pending.append(contentsOf: bytes)
        }

        while let newlineIndex = pending.firstIndex(of: 0x0A) {
          let lineData = pending.prefix(upTo: newlineIndex)
          pending.removeSubrange(...newlineIndex)

          guard lineData.count <= LuaTransportLimits.maxLineBytes else {
            logger.warn(
              "dropping oversized lua transport line",
              .field("bytes", lineData.count),
              .field("max_bytes", LuaTransportLimits.maxLineBytes),
              .field("fd", fd)
            )
            continue
          }

          guard let line = decodeLine(from: lineData) else { continue }
          handleLine(line)
        }

        if pending.count > LuaTransportLimits.maxLineBytes {
          logger.warn(
            "dropping oversized lua transport line",
            .field("bytes", pending.count),
            .field("max_bytes", LuaTransportLimits.maxLineBytes),
            .field("fd", fd)
          )
          pending.removeAll(keepingCapacity: true)
          isDroppingOversizedLine = true
        }
        continue
      }

      if count == 0 {
        if !isDroppingOversizedLine, let line = decodeLine(from: pending[...]) {
          handleLine(line)
        }
        return
      }

      if shouldRetryInterruptedRead(count: count, errnoValue: errno) {
        continue
      }

      return
    }
  }

  /// Clears one client fd when it still matches the active generation.
  private func clearClientFD(_ fd: Int32, generation: UInt64) {
    let shouldClose = state.withLock { state -> Bool in
      guard state.generation == generation, state.clientFD == fd else { return false }
      state.clientFD = -1
      state.readTask = nil
      return true
    }

    guard shouldClose else { return }
    Darwin.shutdown(fd, SHUT_RDWR)
    close(fd)
  }

  /// Returns whether the generation is still active.
  private func isCurrent(generation: UInt64) -> Bool {
    state.withLock { $0.generation == generation }
  }

  /// Returns whether one client fd still belongs to the current Lua generation.
  private func isCurrentClientFD(_ fd: Int32, generation: UInt64) -> Bool {
    state.withLock { state in
      state.generation == generation && state.clientFD == fd
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

  /// Returns whether an `accept` failure is unexpected enough to log.
  private func shouldLogAcceptFailure(errnoValue: Int32) -> Bool {
    return errnoValue != EINVAL && errnoValue != EBADF
  }

  /// Returns whether the current read failure should simply retry the socket read loop.
  private func shouldRetryInterruptedRead(count: Int, errnoValue: Int32) -> Bool {
    return count < 0 && errnoValue == EINTR
  }
}
