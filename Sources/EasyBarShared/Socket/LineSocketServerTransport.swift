import Darwin
import Foundation

/// Serves line-delimited JSON requests over a Unix domain socket and optionally tracks subscribers.
///
/// Sendability is guarded by `LockedState`; server file descriptors, accept
/// tasks, and subscribers are only mutated while holding that lock.
public final class LineSocketServerTransport<
  Subscriber,
  Request: Decodable,
  Response: Encodable
>: @unchecked Sendable {
  /// One currently connected subscriber entry.
  public struct SubscriberEntry {
    public let fd: Int32
    public let subscriber: Subscriber

    /// Creates one subscriber entry.
    public init(fd: Int32, subscriber: Subscriber) {
      self.fd = fd
      self.subscriber = subscriber
    }
  }

  /// Describes what should happen to a client socket after one request was handled.
  public enum ClientDisposition {
    case close
    case keepOpen
  }

  private struct State {
    var serverFD: Int32 = -1
    var running = false
    var acceptTask: Task<Void, Never>?
    var subscribers: [Int32: Subscriber] = [:]
  }

  private let socketPath: String
  private let serverLabel: String
  private let logger: ProcessLogger
  private let onSubscriberRemoved: ((Int32) -> Void)?
  private let state = LockedState(State())

  /// Creates a new Unix socket server transport.
  public init(
    socketPath: String,
    serverLabel: String,
    logger: ProcessLogger,
    onSubscriberRemoved: ((Int32) -> Void)? = nil
  ) {
    self.socketPath = socketPath
    self.serverLabel = serverLabel
    self.logger = logger
    self.onSubscriberRemoved = onSubscriberRemoved
  }

  /// Stops the server before deallocation.
  deinit {
    stop()
  }

  /// Starts listening and dispatches decoded requests to the handler.
  public func start(_ handler: @escaping (Int32, Request) async -> ClientDisposition) {
    let shouldStart = state.withLock { state -> Bool in
      guard !state.running else { return false }
      state.running = true
      return true
    }

    guard shouldStart else { return }

    guard let fd = makeListeningSocket() else {
      state.withLock { state in
        if state.serverFD < 0 {
          state.running = false
        }
      }
      return
    }

    let shouldCancel = state.withLock { state -> Bool in
      guard state.running else { return true }
      state.serverFD = fd
      return false
    }

    if shouldCancel {
      closeListeningSocket(fd)
      return
    }

    logger.info(
      "\(serverLabel) listening",
      .field("socket_path", "\(socketPath)"),
    )

    let task = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      await self.acceptLoop(handler: handler)
    }

    let shouldCancelTask = state.withLock { state -> Bool in
      guard state.running, state.serverFD == fd else { return true }
      state.acceptTask = task
      return false
    }

    if shouldCancelTask {
      task.cancel()
    }
  }

  /// Stops the server, closes subscribers, and removes the socket file.
  public func stop() {
    let snapshot = state.withLock { state -> (Bool, Int32, [Int32], Task<Void, Never>?) in
      let snapshot = (state.running, state.serverFD, Array(state.subscribers.keys), state.acceptTask)
      state.running = false
      state.serverFD = -1
      state.acceptTask = nil
      state.subscribers.removeAll()
      return snapshot
    }

    guard snapshot.0 else { return }

    snapshot.3?.cancel()

    for subscriberFD in snapshot.2 {
      closeClientSocket(subscriberFD)
    }

    if snapshot.1 >= 0 {
      Darwin.shutdown(snapshot.1, SHUT_RDWR)
      close(snapshot.1)
    }

    unlink(socketPath)
    logger.info(
      "\(serverLabel) stopped",
      .field("socket_path", "\(socketPath)"),
    )
  }

  /// Sends one encoded response to the given client file descriptor.
  @discardableResult
  public func send(_ response: Response, to clientFD: Int32) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    do {
      let data = try encoder.encode(response) + Data([0x0A])
      return writeAll(data, to: clientFD)
    } catch {
      logger.error(
        "\(serverLabel) response encode failed",
        .field("error", "\(error)"),
      )
      return false
    }
  }

  /// Adds one subscriber for future broadcasts.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    state.withLock { state in
      state.subscribers[fd] = subscriber
    }

    logger.debug(
      "\(serverLabel) subscriber added",
      .field("fd", "\(fd)"),
    )
  }

  /// Removes one subscriber and closes its socket.
  @discardableResult
  public func removeSubscriber(fd: Int32) -> Bool {
    let existed = removeSubscriberRecord(fd: fd)
    closeClientSocket(fd)

    if existed {
      logger.debug(
        "\(serverLabel) subscriber removed",
        .field("fd", "\(fd)"),
      )
      onSubscriberRemoved?(fd)
    }

    return existed
  }

  /// Returns a stable snapshot of current subscribers.
  public func subscribersSnapshot() -> [SubscriberEntry] {
    state.withLock { state in
      state.subscribers.map {
        SubscriberEntry(fd: $0.key, subscriber: $0.value)
      }
    }
  }

  /// Creates and starts the listening socket.
  private func makeListeningSocket() -> Int32? {
    let socketURL = URL(fileURLWithPath: socketPath)
    let socketDir = socketURL.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(
        at: socketDir,
        withIntermediateDirectories: true
      )
    } catch {
      logger.error(
        "\(serverLabel) failed to create socket directory",
        .field("path", "\(socketDir.path)"),
        .field("error", "\(error)"),
      )
      return nil
    }

    unlink(socketPath)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.error(
        "\(serverLabel) failed to create socket",
        .field("errno", "\(errno)"),
      )
      return nil
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.error(
        "\(serverLabel) failed to configure server socket no-sigpipe",
        .field("fd", "\(fd)"),
      )
      close(fd)
      return nil
    }

    let addr: sockaddr_un
    do {
      addr = try makeSockAddrUn(path: socketPath)
    } catch {
      logger.error(
        "\(serverLabel) invalid socket path",
        .field("path", "\(socketPath)"),
        .field("error", "\(error)"),
      )
      close(fd)
      unlink(socketPath)
      return nil
    }

    var mutableAddr = addr
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &mutableAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      logger.error(
        "\(serverLabel) bind failed",
        .field("path", "\(socketPath)"),
        .field("errno", "\(errno)"),
      )
      close(fd)
      return nil
    }

    if chmod(socketPath, mode_t(0o600)) != 0 {
      logger.warn(
        "\(serverLabel) chmod failed",
        .field("path", "\(socketPath)"),
        .field("errno", "\(errno)"),
      )
    }

    guard listen(fd, 8) == 0 else {
      logger.error(
        "\(serverLabel) listen failed",
        .field("path", "\(socketPath)"),
        .field("errno", "\(errno)"),
      )
      close(fd)
      unlink(socketPath)
      return nil
    }

    return fd
  }

  /// Closes one listening socket and removes its filesystem path.
  private func closeListeningSocket(_ fd: Int32) {
    Darwin.shutdown(fd, SHUT_RDWR)
    close(fd)
    unlink(socketPath)
  }

  /// Accepts client connections until the server stops.
  private func acceptLoop(handler: @escaping (Int32, Request) async -> ClientDisposition) async {
    while isRunning(), !Task.isCancelled {
      let fd = currentServerFD()
      if fd < 0 { break }

      let clientFD = accept(fd, nil, nil)
      if clientFD < 0 {
        if errno == EINTR {
          continue
        }

        if !isRunning() || Task.isCancelled {
          break
        }

        logger.debug(
          "\(serverLabel) accept failed",
          .field("errno", "\(errno)"),
        )
        continue
      }

      guard configureNoSigPipe(fd: clientFD) else {
        logger.error(
          "\(serverLabel) failed to configure client socket no-sigpipe",
          .field("fd", "\(clientFD)"),
        )
        close(clientFD)
        continue
      }

      DetachedTask.run(priority: .utility) { [weak self] in
        guard let self else { return }
        await self.handleClient(clientFD, handler: handler)
      }
    }
  }

  /// Reads requests until the client disconnects and invokes the handler for each line.
  private func handleClient(
    _ clientFD: Int32,
    handler: @escaping (Int32, Request) async -> ClientDisposition
  ) async {
    var lineDecoder = LineDelimitedJSONDecoder<Request>()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while !Task.isCancelled {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(clientFD, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        let disposition = await handleDecodedRequests(
          lineDecoder.append(buffer.prefix(count)),
          clientFD: clientFD,
          handler: handler
        )

        switch disposition {
        case .close:
          closeClientConnection(clientFD)
          return

        case .keepOpen:
          continue
        }
      }

      if count == 0 {
        closeClientConnection(clientFD)
        return
      }

      if errno == EINTR {
        continue
      }

      logger.debug(
        "\(serverLabel) client read failed",
        .field("fd", "\(clientFD)"),
        .field("errno", "\(errno)"),
      )
      closeClientConnection(clientFD)
      return
    }

    closeClientConnection(clientFD)
  }

  /// Dispatches decoded requests and returns the resulting socket disposition.
  private func handleDecodedRequests(
    _ results: [Result<Request, Error>],
    clientFD: Int32,
    handler: @escaping (Int32, Request) async -> ClientDisposition
  ) async -> ClientDisposition {
    for result in results {
      switch result {
      case .success(let request):
        let disposition = await handler(clientFD, request)
        if disposition == .close {
          return .close
        }

      case .failure(let error):
        logger.warn(
          "\(serverLabel) request decode failed",
          .field("error", "\(error)"),
        )
        return .close
      }
    }

    return .keepOpen
  }

  /// Removes one subscriber record without touching the socket.
  private func removeSubscriberRecord(fd: Int32) -> Bool {
    state.withLock { state in
      state.subscribers.removeValue(forKey: fd) != nil
    }
  }

  /// Closes one client socket.
  private func closeClientSocket(_ clientFD: Int32) {
    Darwin.shutdown(clientFD, SHUT_RDWR)
    close(clientFD)
  }

  /// Closes one client socket and removes any active subscriber entry.
  private func closeClientConnection(_ clientFD: Int32) {
    let removedSubscriber = removeSubscriberRecord(fd: clientFD)
    closeClientSocket(clientFD)

    if removedSubscriber {
      logger.debug(
        "\(serverLabel) subscriber removed",
        .field("fd", "\(clientFD)"),
      )
      onSubscriberRemoved?(clientFD)
    }
  }

  /// Returns whether the server is running.
  private func isRunning() -> Bool {
    state.withLock { $0.running }
  }

  /// Returns the current server socket file descriptor.
  private func currentServerFD() -> Int32 {
    state.withLock { $0.serverFD }
  }
}
