import Darwin
import Foundation

/// Serves line-delimited JSON requests over a Unix domain socket and optionally tracks subscribers.
///
/// Sendability is guarded by `LockedState`; server file descriptors, accept
/// tasks, client tasks, and subscribers are only mutated while holding that lock.
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
    var clientFDs: Set<Int32> = []
    var clientTasks: [Int32: Task<Void, Never>] = [:]
    var subscribers: [Int32: Subscriber] = [:]
  }

  private struct StopSnapshot {
    let serverFD: Int32
    let acceptTask: Task<Void, Never>?
    let clientFDs: Set<Int32>
    let clientTasks: [Int32: Task<Void, Never>]
    let subscriberFDs: Set<Int32>
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

    let shouldClose = state.withLock { state -> Bool in
      guard state.running else { return true }
      state.serverFD = fd
      return false
    }

    if shouldClose {
      closeSocket(fd)
      return
    }

    logger.info(
      "\(serverLabel) listening",
      .field("socket_path", "\(socketPath)")
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

  /// Stops accepting clients and closes every active client and subscriber fd.
  public func stop() {
    let snapshot = state.withLock { state -> StopSnapshot in
      let snapshot = StopSnapshot(
        serverFD: state.serverFD,
        acceptTask: state.acceptTask,
        clientFDs: state.clientFDs,
        clientTasks: state.clientTasks,
        subscriberFDs: Set(state.subscribers.keys)
      )

      state = State()
      return snapshot
    }

    snapshot.acceptTask?.cancel()
    snapshot.clientTasks.values.forEach { $0.cancel() }

    var fdsToClose = snapshot.clientFDs
    fdsToClose.formUnion(snapshot.subscriberFDs)
    if snapshot.serverFD >= 0 {
      fdsToClose.insert(snapshot.serverFD)
    }

    for fd in fdsToClose {
      closeSocket(fd)
    }

    unlink(socketPath)

    for fd in snapshot.subscriberFDs {
      onSubscriberRemoved?(fd)
    }
  }

  /// Tracks one subscriber on an already accepted client fd.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    let shouldClose = state.withLock { state -> Bool in
      guard state.running else { return true }
      state.subscribers[fd] = subscriber
      return false
    }

    if shouldClose {
      closeSocket(fd)
    }
  }

  /// Removes and closes one subscriber fd.
  public func removeSubscriber(for fd: Int32) {
    let shouldNotify = state.withLock { state -> Bool in
      state.subscribers.removeValue(forKey: fd) != nil
    }

    closeClient(fd)

    if shouldNotify {
      onSubscriberRemoved?(fd)
    }
  }

  /// Sends one response message to the given client fd.
  @discardableResult
  public func send(_ response: Response, to fd: Int32) -> Bool {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      encoder.dateEncodingStrategy = .iso8601

      let payload = try encoder.encode(response) + Data([0x0A])
      try writeAll(payload, to: fd)
      return true
    } catch {
      logger.warn(
        "\(serverLabel) send failed",
        .field("fd", fd),
        .field("error", error)
      )
      return false
    }
  }

  /// Broadcasts one message to every current subscriber and removes failed subscribers.
  public func broadcast(_ makeMessage: (Subscriber) -> Response) {
    let entries = state.withLock { state in
      state.subscribers.map { SubscriberEntry(fd: $0.key, subscriber: $0.value) }
    }

    for entry in entries {
      guard send(makeMessage(entry.subscriber), to: entry.fd) else {
        removeSubscriber(for: entry.fd)
        continue
      }
    }
  }

  /// Accepts client sockets until the listening fd is closed.
  private func acceptLoop(handler: @escaping (Int32, Request) async -> ClientDisposition) async {
    while !Task.isCancelled {
      guard let serverFD = currentServerFD() else { return }

      let clientFD = Darwin.accept(serverFD, nil, nil)

      if clientFD >= 0 {
        startClientTask(clientFD, handler: handler)
        continue
      }

      if errno == EINTR {
        continue
      }

      if isRunning, shouldLogAcceptFailure(errnoValue: errno) {
        logger.warn("\(serverLabel) accept failed", .field("errno", errno))
      }

      return
    }
  }

  /// Starts a read task for one accepted client fd.
  private func startClientTask(
    _ clientFD: Int32,
    handler: @escaping (Int32, Request) async -> ClientDisposition
  ) {
    guard configureNoSigPipe(fd: clientFD) else {
      closeSocket(clientFD)
      return
    }

    let shouldClose = state.withLock { state -> Bool in
      guard state.running else { return true }
      state.clientFDs.insert(clientFD)
      return false
    }

    if shouldClose {
      closeSocket(clientFD)
      return
    }

    let task = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      await self.handleClient(clientFD, handler: handler)
    }

    let shouldCancelTask = state.withLock { state -> Bool in
      guard state.running, state.clientFDs.contains(clientFD) else { return true }
      state.clientTasks[clientFD] = task
      return false
    }

    if shouldCancelTask {
      task.cancel()
      closeClient(clientFD)
    }
  }

  /// Reads one request from a client and applies the requested close/keep-open disposition.
  private func handleClient(
    _ clientFD: Int32,
    handler: @escaping (Int32, Request) async -> ClientDisposition
  ) async {
    guard let request = readRequest(from: clientFD) else {
      closeClient(clientFD)
      return
    }

    let disposition = await handler(clientFD, request)

    switch disposition {
    case .close:
      closeClient(clientFD)

    case .keepOpen:
      finishClientTask(clientFD)
    }
  }

  /// Reads and decodes one newline-delimited request.
  private func readRequest(from fd: Int32) -> Request? {
    var decoder = makeDecoder()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while !Task.isCancelled, isClientOpen(fd) {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        if let request = firstDecodedRequest(from: decoder.append(buffer.prefix(count))) {
          return request
        }
        continue
      }

      if count == 0 {
        return firstDecodedRequest(from: decoder.flush())
      }

      if errno == EINTR {
        continue
      }

      return nil
    }

    return nil
  }

  /// Returns the first successfully decoded request, logging decode failures.
  private func firstDecodedRequest(from results: [Result<Request, Error>]) -> Request? {
    for result in results {
      switch result {
      case .success(let request):
        return request

      case .failure(let error):
        logger.warn("\(serverLabel) request decode failed", .field("error", error))
      }
    }

    return nil
  }

  /// Removes the per-client read task after a handler keeps the fd open as a subscriber.
  private func finishClientTask(_ fd: Int32) {
    let shouldClose = state.withLock { state -> Bool in
      state.clientTasks.removeValue(forKey: fd)
      state.clientFDs.remove(fd)
      return state.running && state.subscribers[fd] == nil
    }

    if shouldClose {
      closeSocket(fd)
    }
  }

  /// Removes a client and subscriber entry and closes the fd.
  private func closeClient(_ fd: Int32) {
    let shouldNotify = state.withLock { state -> Bool in
      state.clientTasks.removeValue(forKey: fd)?.cancel()
      state.clientFDs.remove(fd)
      return state.subscribers.removeValue(forKey: fd) != nil
    }

    closeSocket(fd)

    if shouldNotify {
      onSubscriberRemoved?(fd)
    }
  }

  /// Returns the active listening fd, or nil when stopped.
  private func currentServerFD() -> Int32? {
    state.withLock { state in
      guard state.running, state.serverFD >= 0 else { return nil }
      return state.serverFD
    }
  }

  /// Returns whether the server is currently running.
  private var isRunning: Bool {
    state.withLock { $0.running }
  }

  /// Returns whether one accepted client fd is still tracked.
  private func isClientOpen(_ fd: Int32) -> Bool {
    state.withLock { state in
      state.running && (state.clientFDs.contains(fd) || state.subscribers[fd] != nil)
    }
  }

  /// Creates and starts listening on the Unix domain socket.
  private func makeListeningSocket() -> Int32? {
    let socketURL = URL(fileURLWithPath: socketPath)
    let socketDirectory = socketURL.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(
        at: socketDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      logger.error(
        "failed to create \(serverLabel) socket directory",
        .field("path", socketDirectory.path),
        .field("error", error)
      )
      return nil
    }

    unlink(socketPath)

    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.error("failed to create \(serverLabel) socket", .field("errno", errno))
      return nil
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.error("failed to configure \(serverLabel) socket no-sigpipe")
      closeSocket(fd)
      return nil
    }

    do {
      var address = try makeSockAddrUn(path: socketPath)
      let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)

      let bindResult = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.bind(fd, $0, addressLength)
        }
      }

      guard bindResult == 0 else {
        logger.error("failed to bind \(serverLabel) socket", .field("errno", errno))
        closeSocket(fd)
        return nil
      }

      guard Darwin.listen(fd, SOMAXCONN) == 0 else {
        logger.error("failed to listen on \(serverLabel) socket", .field("errno", errno))
        closeSocket(fd)
        unlink(socketPath)
        return nil
      }

      return fd
    } catch {
      logger.error("invalid \(serverLabel) socket path", .field("error", error))
      closeSocket(fd)
      return nil
    }
  }

  /// Builds a fresh request decoder.
  private func makeDecoder() -> LineDelimitedJSONDecoder<Request> {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return LineDelimitedJSONDecoder(decoder: decoder)
  }

  /// Writes all bytes to the client fd.
  private func writeAll(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
      guard let baseAddress = rawBuffer.baseAddress else { return }

      var sent = 0
      while sent < data.count {
        let count = Darwin.write(fd, baseAddress.advanced(by: sent), data.count - sent)

        if count > 0 {
          sent += count
          continue
        }

        if count < 0, errno == EINTR {
          continue
        }

        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: Int(errno),
          userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))]
        )
      }
    }
  }

  /// Shuts down and closes a fd, waking blocking accept/read calls in other tasks.
  private func closeSocket(_ fd: Int32) {
    guard fd >= 0 else { return }
    Darwin.shutdown(fd, SHUT_RDWR)
    Darwin.close(fd)
  }

  /// Returns whether an `accept` failure is expected during shutdown.
  private func shouldLogAcceptFailure(errnoValue: Int32) -> Bool {
    errnoValue != EINVAL && errnoValue != EBADF
  }
}
