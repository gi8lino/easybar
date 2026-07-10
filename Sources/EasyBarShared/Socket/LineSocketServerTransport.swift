import Darwin
import Dispatch
import Foundation

/// Serves line-delimited JSON requests over a Unix domain socket and optionally tracks subscribers.
///
/// Sendability is guarded by `LockedState`; server file descriptors, accept
/// threads, connected clients, and subscribers are only mutated while holding
/// that lock. Request handlers are invoked outside the lock so user code cannot
/// block state cleanup or socket shutdown.
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
    var generation: UInt64 = 0
    var acceptThread: Thread?
    var clientFDs: Set<Int32> = []
    var subscribers: [Int32: Subscriber] = [:]
  }

  private struct StopSnapshot {
    let wasRunning: Bool
    let serverFD: Int32
    let clientFDs: [Int32]
    let subscriberFDs: [Int32]
  }

  private let socketPath: String
  private let serverLabel: String
  private let logger: ProcessLogger
  private let onSubscriberRemoved: ((Int32) -> Void)?
  private let initialRequestTimeout: TimeInterval
  private let writerQueue: DispatchQueue
  private let state = LockedState(State())

  /// Creates a new Unix socket server transport.
  public init(
    socketPath: String,
    serverLabel: String,
    logger: ProcessLogger,
    initialRequestTimeout: TimeInterval = 5,
    onSubscriberRemoved: ((Int32) -> Void)? = nil
  ) {
    self.socketPath = socketPath
    self.serverLabel = serverLabel
    self.logger = logger
    self.initialRequestTimeout = max(0.001, initialRequestTimeout)
    self.onSubscriberRemoved = onSubscriberRemoved
    self.writerQueue = DispatchQueue(label: "easybar.\(serverLabel).socket-writer")
  }

  /// Stops the server before deallocation.
  deinit {
    stop()
  }

  /// Starts listening and dispatches decoded requests to the handler.
  @discardableResult
  public func start(_ handler: @escaping (Int32, Request) -> ClientDisposition) -> Bool {
    let generation = state.withLock { state -> UInt64? in
      guard !state.running else { return nil }
      state.running = true
      state.generation &+= 1
      return state.generation
    }

    guard let generation else { return false }

    guard let fd = makeListeningSocket() else {
      state.withLock { state in
        if state.serverFD < 0 {
          state.running = false
        }
      }
      return false
    }

    let shouldCancel = state.withLock { state -> Bool in
      guard state.running, state.generation == generation else { return true }
      state.serverFD = fd
      return false
    }

    if shouldCancel {
      closeListeningUnixSocket(fd, at: socketPath)
      return false
    }

    logger.info(
      "\(serverLabel) listening",
      .field("socket_path", "\(socketPath)"),
    )

    let thread = Thread { [weak self] in
      self?.acceptLoop(serverFD: fd, generation: generation, handler: handler)
    }
    thread.name = "\(serverLabel) socket accept"
    thread.qualityOfService = .utility

    let shouldStartThread = state.withLock { state -> Bool in
      guard
        state.running,
        state.generation == generation,
        state.serverFD == fd
      else { return false }
      state.acceptThread = thread
      return true
    }

    if shouldStartThread {
      thread.start()
    }

    return shouldStartThread
  }

  /// Stops the server, closes connected clients, and removes the socket file.
  public func stop() {
    let snapshot = state.withLock { state -> StopSnapshot in
      let snapshot = StopSnapshot(
        wasRunning: state.running,
        serverFD: state.serverFD,
        clientFDs: Array(state.clientFDs.union(state.subscribers.keys)),
        subscriberFDs: Array(state.subscribers.keys)
      )

      state.running = false
      state.generation &+= 1
      state.serverFD = -1
      state.acceptThread = nil
      state.clientFDs.removeAll()
      state.subscribers.removeAll()
      return snapshot
    }

    guard snapshot.wasRunning else { return }

    for clientFD in snapshot.clientFDs {
      closeClientSocket(clientFD)
    }

    for subscriberFD in snapshot.subscriberFDs {
      onSubscriberRemoved?(subscriberFD)
    }

    if snapshot.serverFD >= 0 {
      Darwin.shutdown(snapshot.serverFD, SHUT_RDWR)
      close(snapshot.serverFD)
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
    writerQueue.sync {
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
  }

  /// Adds one subscriber for future broadcasts.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    let added = state.withLock { state -> Bool in
      guard state.running, state.clientFDs.contains(fd) else { return false }
      state.subscribers[fd] = subscriber
      return true
    }

    guard added else { return }

    logger.debug(
      "\(serverLabel) subscriber added",
      .field("fd", "\(fd)"),
    )
  }

  /// Removes one subscriber and closes its socket.
  @discardableResult
  public func removeSubscriber(fd: Int32) -> Bool {
    let removed = removeClientConnectionRecords(fd: fd)

    if removed.shouldClose {
      closeClientSocket(fd)
    }

    if removed.subscriber {
      logger.debug(
        "\(serverLabel) subscriber removed",
        .field("fd", "\(fd)"),
      )
      onSubscriberRemoved?(fd)
    }

    return removed.subscriber
  }

  /// Returns a stable snapshot of current subscribers.
  public func subscribersSnapshot() -> [SubscriberEntry] {
    state.withLock { state in
      state.subscribers.map {
        SubscriberEntry(fd: $0.key, subscriber: $0.value)
      }
    }
  }

  /// Sends one derived response to every subscriber and drops sockets that can no longer receive.
  public func broadcast(_ response: (Subscriber) -> Response) {
    for entry in subscribersSnapshot() {
      guard send(response(entry.subscriber), to: entry.fd) else {
        _ = removeSubscriber(fd: entry.fd)
        continue
      }
    }
  }

  /// Creates and starts the listening socket.
  private func makeListeningSocket() -> Int32? {
    do {
      return try makeListeningUnixSocket(
        at: socketPath,
        backlog: 8,
        onChmodFailure: { [logger, serverLabel, socketPath] errnoValue in
          logger.warn(
            "\(serverLabel) chmod failed",
            .field("path", "\(socketPath)"),
            .field("errno", "\(errnoValue)"),
          )
        }
      )
    } catch {
      logger.error(
        "\(serverLabel) listen socket setup failed",
        .field("path", "\(socketPath)"),
        .field("error", "\(error)"),
      )
      return nil
    }
  }

  /// Accepts client connections until the server stops.
  private func acceptLoop(
    serverFD: Int32,
    generation: UInt64,
    handler: @escaping (Int32, Request) -> ClientDisposition
  ) {
    while isActiveServer(fd: serverFD, generation: generation) {
      let clientFD = accept(serverFD, nil, nil)
      if clientFD < 0 {
        if errno == EINTR {
          continue
        }

        if !isActiveServer(fd: serverFD, generation: generation) {
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

      guard registerClientFD(clientFD, generation: generation) else {
        closeClientSocket(clientFD)
        continue
      }

      let clientThread = Thread { [weak self] in
        self?.handleClient(clientFD, handler: handler)
      }
      clientThread.name = "\(serverLabel) socket client"
      clientThread.qualityOfService = .utility
      clientThread.start()
    }
  }

  /// Reads requests until the client disconnects and invokes the handler for each line.
  private func handleClient(
    _ clientFD: Int32,
    handler: @escaping (Int32, Request) -> ClientDisposition
  ) {
    var lineDecoder = LineDelimitedJSONDecoder<Request>()
    var buffer = [UInt8](repeating: 0, count: 4096)
    var isWaitingForInitialRequest = true

    while true {
      if isWaitingForInitialRequest && !waitForInitialRequest(on: clientFD) {
        closeClientConnection(clientFD)
        return
      }

      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(clientFD, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        let result = handleDecodedRequests(
          lineDecoder.append(buffer.prefix(count)),
          clientFD: clientFD,
          handler: handler
        )

        if result.handledRequest {
          isWaitingForInitialRequest = false
        }

        switch result.disposition {
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
  }

  /// Dispatches decoded requests and returns the resulting socket disposition.
  private func handleDecodedRequests(
    _ results: [Result<Request, Error>],
    clientFD: Int32,
    handler: @escaping (Int32, Request) -> ClientDisposition
  ) -> (disposition: ClientDisposition, handledRequest: Bool) {
    for result in results {
      switch result {
      case .success(let request):
        let disposition = handler(clientFD, request)
        if disposition == .close {
          return (.close, true)
        }

      case .failure(let error):
        logger.warn(
          "\(serverLabel) request decode failed",
          .field("error", "\(error)"),
        )
        return (.close, false)
      }
    }

    return (.keepOpen, !results.isEmpty)
  }

  /// Waits for an initial request without allowing idle clients to retain a thread forever.
  private func waitForInitialRequest(on clientFD: Int32) -> Bool {
    var descriptor = pollfd(fd: clientFD, events: Int16(POLLIN), revents: 0)
    let timeoutMilliseconds = Int32(min(initialRequestTimeout * 1_000, Double(Int32.max)))

    while true {
      let result = poll(&descriptor, 1, timeoutMilliseconds)
      if result > 0 {
        return (descriptor.revents & Int16(POLLIN)) != 0
      }

      if result < 0 && errno == EINTR {
        continue
      }

      if result == 0 {
        logger.debug(
          "\(serverLabel) initial request timed out",
          .field("fd", "\(clientFD)")
        )
      }
      return false
    }
  }

  /// Tracks one accepted client when the server is still running.
  private func registerClientFD(_ fd: Int32, generation: UInt64) -> Bool {
    state.withLock { state -> Bool in
      guard state.running, state.generation == generation else { return false }
      state.clientFDs.insert(fd)
      return true
    }
  }

  /// Removes one connected client and any active subscriber entry.
  private func removeClientConnectionRecords(
    fd: Int32
  ) -> (shouldClose: Bool, subscriber: Bool) {
    state.withLock { state in
      let clientRemoved = state.clientFDs.remove(fd) != nil
      let subscriberRemoved = state.subscribers.removeValue(forKey: fd) != nil
      return (clientRemoved || subscriberRemoved, subscriberRemoved)
    }
  }

  /// Closes one client socket.
  private func closeClientSocket(_ clientFD: Int32) {
    Darwin.shutdown(clientFD, SHUT_RDWR)
    close(clientFD)
  }

  /// Closes one client socket and removes any active subscriber entry.
  private func closeClientConnection(_ clientFD: Int32) {
    let removed = removeClientConnectionRecords(fd: clientFD)

    if removed.shouldClose {
      closeClientSocket(clientFD)
    }

    if removed.subscriber {
      logger.debug(
        "\(serverLabel) subscriber removed",
        .field("fd", "\(clientFD)"),
      )
      onSubscriberRemoved?(clientFD)
    }
  }

  /// Returns whether one accept loop still owns the active server run.
  private func isActiveServer(fd: Int32, generation: UInt64) -> Bool {
    state.withLock {
      $0.running && $0.generation == generation && $0.serverFD == fd
    }
  }
}
