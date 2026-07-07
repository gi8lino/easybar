import Darwin
import Foundation

/// Shared newline-delimited client transport used by app-side and helper-process agent clients.
///
/// Sendability is guarded by `LockedState`; all mutable socket/task state is
/// accessed through that lock, and callbacks are invoked outside the lock.
public final class AgentSocketClient<Request: Encodable, Message: Decodable>: @unchecked Sendable {
  private struct State {
    var socketFD: Int32 = -1
    var running = false
    var connectionTask: Task<Void, Never>?
    var nextReconnectDelayOverride: TimeInterval?
    var activeConnectionID: UInt64 = 0
  }

  private struct StopSnapshot {
    let fd: Int32
    let task: Task<Void, Never>?
    let wasConnected: Bool
  }

  private struct ConnectionEndSnapshot {
    let shouldNotifyDisconnect: Bool
    let shouldReconnect: Bool
    let reconnectDelayOverride: TimeInterval?
  }

  private let label: String
  private let socketPath: () -> String
  private let subscribeRequest: () -> Request
  private let handleMessage: (Message) -> Void
  private let clearState: () -> Void
  private let onConnected: (() -> Void)?
  private let onDisconnected: (() -> Void)?
  private let onDecodedMessage: (() -> Void)?
  private let onDecodeError: (() -> Void)?
  private let logger: ProcessLogger
  private let reconnectScheduler: BackoffScheduler
  private let state = LockedState(State())

  /// Creates one shared agent client transport.
  public init(
    label: String,
    socketPath: @escaping () -> String,
    subscribeRequest: @escaping () -> Request,
    handleMessage: @escaping (Message) -> Void,
    clearState: @escaping () -> Void,
    onConnected: (() -> Void)? = nil,
    onDisconnected: (() -> Void)? = nil,
    onDecodedMessage: (() -> Void)? = nil,
    onDecodeError: (() -> Void)? = nil,
    logger: ProcessLogger
  ) {
    self.label = label
    self.socketPath = socketPath
    self.subscribeRequest = subscribeRequest
    self.handleMessage = handleMessage
    self.clearState = clearState
    self.onConnected = onConnected
    self.onDisconnected = onDisconnected
    self.onDecodedMessage = onDecodedMessage
    self.onDecodeError = onDecodeError
    self.logger = logger
    self.reconnectScheduler = BackoffScheduler(
      label: "\(label) reconnect",
      delays: [2, 5, 10, 30],
      logger: logger
    )
  }

  deinit {
    stop()
  }

  /// Returns whether the client currently has an open socket.
  public var isConnected: Bool {
    state.withLock { state in
      state.running && state.socketFD >= 0
    }
  }

  /// Starts the client connection loop.
  public func start() {
    let shouldConnect = state.withLock { state -> Bool in
      guard !state.running else { return false }
      state.running = true
      state.activeConnectionID &+= 1
      return true
    }

    guard shouldConnect else { return }
    reconnectScheduler.cancel()
    connect()
  }

  /// Stops the client, closes any blocking socket read, and clears published state.
  public func stop() {
    reconnectScheduler.cancel()

    let snapshot = state.withLock { state -> StopSnapshot in
      state.running = false
      state.nextReconnectDelayOverride = nil
      state.activeConnectionID &+= 1

      let snapshot = StopSnapshot(
        fd: state.socketFD,
        task: state.connectionTask,
        wasConnected: state.socketFD >= 0
      )

      state.socketFD = -1
      state.connectionTask = nil

      return snapshot
    }

    snapshot.task?.cancel()
    closeSocket(snapshot.fd)
    clearState()

    if snapshot.wasConnected {
      onDisconnected?()
    }
  }

  /// Reconnects the stream immediately, usually to force a fresh subscription snapshot.
  public func refresh() {
    reconnect(after: 0)
  }

  /// Reconnects the stream using the provided delay override.
  public func reconnect(after delayOverride: TimeInterval? = nil) {
    let snapshot = state.withLock { state -> StopSnapshot? in
      guard state.running else { return nil }

      state.nextReconnectDelayOverride = delayOverride
      state.activeConnectionID &+= 1

      let snapshot = StopSnapshot(
        fd: state.socketFD,
        task: state.connectionTask,
        wasConnected: state.socketFD >= 0
      )

      state.socketFD = -1
      state.connectionTask = nil

      return snapshot
    }

    guard let snapshot else { return }

    snapshot.task?.cancel()
    closeSocket(snapshot.fd)

    if snapshot.wasConnected {
      clearState()
      onDisconnected?()
    }

    scheduleReconnectIfStillRunning(delayOverride: delayOverride)
  }

  /// Starts one background connection attempt.
  private func connect() {
    let connectionID = state.withLock { state -> UInt64? in
      guard state.running else { return nil }
      state.activeConnectionID &+= 1
      return state.activeConnectionID
    }

    guard let connectionID else { return }

    let task = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      self.runConnectionAttempt(connectionID: connectionID)
    }

    let update = state.withLock { state -> (cancelNew: Bool, oldTask: Task<Void, Never>?) in
      guard state.running, state.activeConnectionID == connectionID else {
        return (cancelNew: true, oldTask: nil)
      }

      let oldTask = state.connectionTask
      state.connectionTask = task
      return (cancelNew: false, oldTask: oldTask)
    }

    if update.cancelNew {
      task.cancel()
    } else {
      update.oldTask?.cancel()
    }
  }

  /// Performs one connect, subscribe, read, and disconnect cycle.
  private func runConnectionAttempt(connectionID: UInt64) {
    let path = socketPath()
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

    guard fd >= 0 else {
      logger.warn("\(label) socket creation failed", .field("errno", errno))
      finishConnection(fd: -1, connectionID: connectionID)
      return
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.warn("\(label) socket no-sigpipe setup failed")
      closeSocket(fd)
      finishConnection(fd: -1, connectionID: connectionID)
      return
    }

    do {
      try connect(fd: fd, path: path)
    } catch {
      logger.debug(
        "\(label) connect failed",
        .field("socket", path),
        .field("error", error)
      )
      closeSocket(fd)
      finishConnection(fd: -1, connectionID: connectionID)
      return
    }

    guard registerConnectedSocket(fd, connectionID: connectionID) else {
      closeSocket(fd)
      return
    }

    do {
      try sendSubscribeRequest(to: fd)
    } catch {
      logger.warn("\(label) subscribe request failed", .field("error", error))
      finishConnection(fd: fd, connectionID: connectionID)
      return
    }

    guard isCurrentConnection(fd: fd, connectionID: connectionID) else {
      closeSocket(fd)
      return
    }

    logger.debug("\(label) connected", .field("socket", path))
    onConnected?()

    readLoop(fd: fd, connectionID: connectionID)
    finishConnection(fd: fd, connectionID: connectionID)
  }

  /// Opens the Unix socket connection.
  private func connect(fd: Int32, path: String) throws {
    var address = try makeSockAddrUn(path: path)
    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)

    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, addressLength)
      }
    }

    guard result == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(errno),
        userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))]
      )
    }
  }

  /// Marks the socket as the currently active stream when the generation still matches.
  private func registerConnectedSocket(_ fd: Int32, connectionID: UInt64) -> Bool {
    state.withLock { state in
      guard state.running, state.activeConnectionID == connectionID else { return false }
      state.socketFD = fd
      return true
    }
  }

  /// Sends the configured subscribe request as one newline-delimited JSON message.
  private func sendSubscribeRequest(to fd: Int32) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let payload = try encoder.encode(subscribeRequest()) + Data([0x0A])
    try writeAll(payload, to: fd)
  }

  /// Reads and decodes newline-delimited messages until the socket closes.
  private func readLoop(fd: Int32, connectionID: UInt64) {
    var decoder = makeDecoder()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while !Task.isCancelled, isCurrentConnection(fd: fd, connectionID: connectionID) {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        handleDecodeResults(decoder.append(buffer.prefix(count)))
        continue
      }

      if count == 0 {
        handleDecodeResults(decoder.flush())
        return
      }

      if errno == EINTR {
        continue
      }

      return
    }
  }

  /// Handles decoded messages and reports decode failures.
  private func handleDecodeResults(_ results: [Result<Message, Error>]) {
    for result in results {
      switch result {
      case .success(let message):
        handleMessage(message)
        onDecodedMessage?()

      case .failure(let error):
        logger.warn("\(label) decode failed", .field("error", error))
        onDecodeError?()
      }
    }
  }

  /// Clears the active connection if it still matches the generation and schedules a reconnect if needed.
  private func finishConnection(fd: Int32, connectionID: UInt64) {
    let snapshot = state.withLock { state -> ConnectionEndSnapshot? in
      guard state.activeConnectionID == connectionID else { return nil }

      let wasCurrentSocket = fd >= 0 && state.socketFD == fd
      if wasCurrentSocket {
        state.socketFD = -1
      }

      state.connectionTask = nil

      let shouldReconnect = state.running
      let reconnectDelayOverride = state.nextReconnectDelayOverride
      state.nextReconnectDelayOverride = nil

      return ConnectionEndSnapshot(
        shouldNotifyDisconnect: wasCurrentSocket,
        shouldReconnect: shouldReconnect,
        reconnectDelayOverride: reconnectDelayOverride
      )
    }

    closeSocket(fd)

    guard let snapshot else { return }

    if snapshot.shouldNotifyDisconnect {
      logger.debug("\(label) disconnected")
      clearState()
      onDisconnected?()
    }

    if snapshot.shouldReconnect {
      scheduleReconnectIfStillRunning(delayOverride: snapshot.reconnectDelayOverride)
    }
  }

  /// Schedules a reconnect only while the client is still running.
  private func scheduleReconnectIfStillRunning(delayOverride: TimeInterval?) {
    let shouldReconnect = state.withLock { $0.running }
    guard shouldReconnect else { return }

    reconnectScheduler.schedule(after: delayOverride) { [weak self] in
      self?.connect()
    }
  }

  /// Returns whether the provided fd still belongs to the active connection.
  private func isCurrentConnection(fd: Int32, connectionID: UInt64) -> Bool {
    state.withLock { state in
      state.running && state.activeConnectionID == connectionID && state.socketFD == fd
    }
  }

  /// Builds a fresh line-delimited decoder for agent messages.
  private func makeDecoder() -> LineDelimitedJSONDecoder<Message> {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return LineDelimitedJSONDecoder(decoder: decoder)
  }

  /// Writes all bytes to the connected socket.
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

  /// Shuts down and closes a socket fd, waking any blocking read in another task.
  private func closeSocket(_ fd: Int32) {
    guard fd >= 0 else { return }
    Darwin.shutdown(fd, SHUT_RDWR)
    Darwin.close(fd)
  }
}
