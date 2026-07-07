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
    var connectionThread: Thread?
    var nextReconnectDelayOverride: TimeInterval?
    var activeConnectionID: UInt64 = 0
  }

  private struct StopSnapshot {
    let fd: Int32
    let shouldNotifyDisconnect: Bool
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
  private let writerQueue: DispatchQueue
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
    self.writerQueue = DispatchQueue(label: "easybar.\(label).socket-writer")
    self.reconnectScheduler = BackoffScheduler(
      label: "\(label) reconnect",
      delays: [2, 5, 10, 30],
      logger: logger
    )
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
      return true
    }

    guard shouldConnect else { return }
    reconnectScheduler.cancel()
    connect()
  }

  /// Stops the client and clears published state.
  public func stop() {
    let snapshot = state.withLock { state -> StopSnapshot in
      state.running = false
      state.nextReconnectDelayOverride = nil

      let currentFD = state.socketFD
      state.socketFD = -1
      state.connectionThread = nil
      state.activeConnectionID &+= 1

      return StopSnapshot(
        fd: currentFD,
        shouldNotifyDisconnect: currentFD >= 0
      )
    }

    reconnectScheduler.cancel()
    if snapshot.fd >= 0 {
      shutdown(snapshot.fd, SHUT_RDWR)
      close(snapshot.fd)
    }

    clearState()

    if snapshot.shouldNotifyDisconnect {
      onDisconnected?()
    }
  }

  /// Overrides the delay used for the next reconnect attempt.
  public func setNextReconnectDelay(_ delay: TimeInterval?) {
    state.withLock { state in
      state.nextReconnectDelayOverride = delay
    }
  }

  /// Sends one fresh subscribe request through the active socket.
  public func refresh() {
    let connection = currentConnection()
    guard connection.fd >= 0 else { return }

    guard send(subscribeRequest(), to: connection.fd) else {
      logger.warn("\(label) failed to send refresh request")
      handleDisconnect(fd: connection.fd, connectionID: connection.id)
      return
    }
  }

  /// Starts one connection attempt on a dedicated blocking socket thread.
  private func connect() {
    let thread = Thread { [weak self] in
      self?.runConnectionAttempt()
    }
    thread.name = "\(label) socket client"
    thread.qualityOfService = .utility

    let shouldStart = state.withLock { state -> Bool in
      guard state.running else { return false }
      state.connectionThread = thread
      return true
    }

    if shouldStart {
      thread.start()
    }
  }

  /// Performs one connection attempt and read loop.
  private func runConnectionAttempt() {
    guard isRunning() else { return }

    let resolvedSocketPath = socketPath()
    guard let fd = openConnectedSocket(socketPath: resolvedSocketPath) else {
      scheduleReconnect()
      return
    }

    guard let connectionID = activateConnectedSocketFD(fd) else {
      shutdown(fd, SHUT_RDWR)
      close(fd)
      return
    }

    onConnected?()
    logger.info(
      "\(label) connected",
      .field("socket", resolvedSocketPath),
    )

    guard send(subscribeRequest(), to: fd) else {
      logger.warn("\(label) failed to send subscribe request")
      handleDisconnect(fd: fd, connectionID: connectionID)
      return
    }

    reconnectScheduler.resetDelay()
    readLoop(fd: fd, connectionID: connectionID)
  }

  /// Reads newline-delimited messages until the socket disconnects.
  private func readLoop(fd: Int32, connectionID: UInt64) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var lineDecoder = LineDelimitedJSONDecoder<Message>()

    while isActiveConnection(fd: fd, connectionID: connectionID) {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        handleDecodedMessages(lineDecoder.append(buffer.prefix(count)))
        continue
      }

      if count == 0 {
        handleDecodedMessages(lineDecoder.flush())
        break
      }

      if errno == EINTR {
        continue
      }

      logger.debug(
        "\(label) read failed",
        .field("errno", errno),
      )
      break
    }

    handleDisconnect(fd: fd, connectionID: connectionID)
  }

  /// Handles decoded message payloads and records decode failures.
  private func handleDecodedMessages(_ results: [Result<Message, Error>]) {
    for result in results {
      switch result {
      case .success(let message):
        onDecodedMessage?()
        handleMessage(message)

      case .failure(let error):
        onDecodeError?()
        logger.warn(
          "\(label) failed to decode message",
          .field("error", error),
        )
      }
    }
  }

  /// Handles one socket disconnect and schedules reconnect when still running.
  private func handleDisconnect(fd: Int32, connectionID: UInt64) {
    let wasActive = clearConnectedSocketFD(fd, connectionID: connectionID)
    guard wasActive else { return }

    shutdown(fd, SHUT_RDWR)
    close(fd)

    clearState()
    onDisconnected?()

    guard isRunning() else { return }

    logger.info("\(label) disconnected")
    scheduleReconnect()
  }

  /// Schedules one reconnect attempt.
  private func scheduleReconnect() {
    let reconnect = state.withLock { state -> (running: Bool, delayOverride: TimeInterval?) in
      guard state.running else { return (false, nil) }
      let delay = state.nextReconnectDelayOverride
      state.nextReconnectDelayOverride = nil
      return (true, delay)
    }

    guard reconnect.running else { return }
    reconnectScheduler.schedule(after: reconnect.delayOverride) { [weak self] in
      self?.connect()
    }
  }

  /// Returns whether the client is meant to be running.
  private func isRunning() -> Bool {
    state.withLock { $0.running }
  }

  /// Returns the currently active connection tuple.
  private func currentConnection() -> (fd: Int32, id: UInt64) {
    state.withLock { state in
      (state.socketFD, state.activeConnectionID)
    }
  }

  /// Stores one newly connected socket when still running.
  private func activateConnectedSocketFD(_ fd: Int32) -> UInt64? {
    state.withLock { state -> UInt64? in
      guard state.running else { return nil }

      if state.socketFD >= 0, state.socketFD != fd {
        shutdown(state.socketFD, SHUT_RDWR)
        close(state.socketFD)
      }

      state.socketFD = fd
      state.activeConnectionID &+= 1
      return state.activeConnectionID
    }
  }

  /// Clears the active fd if it still matches the given connection.
  private func clearConnectedSocketFD(_ fd: Int32, connectionID: UInt64) -> Bool {
    state.withLock { state -> Bool in
      guard state.socketFD == fd, state.activeConnectionID == connectionID else {
        return false
      }

      state.socketFD = -1
      state.connectionThread = nil
      return true
    }
  }

  /// Returns whether the fd still represents the active connection.
  private func isActiveConnection(fd: Int32, connectionID: UInt64) -> Bool {
    state.withLock { state in
      state.running && state.socketFD == fd && state.activeConnectionID == connectionID
    }
  }

  /// Opens one connected Unix socket.
  private func openConnectedSocket(socketPath: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.warn(
        "\(label) socket creation failed",
        .field("errno", errno),
      )
      return nil
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.warn(
        "\(label) failed to configure no-sigpipe",
        .field("fd", fd),
      )
      close(fd)
      return nil
    }

    let addr: sockaddr_un
    do {
      addr = try makeSockAddrUn(path: socketPath)
    } catch {
      logger.warn(
        "\(label) invalid socket path",
        .field("socket", socketPath),
        .field("error", error),
      )
      close(fd)
      return nil
    }

    var mutableAddr = addr
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let connectResult = withUnsafePointer(to: &mutableAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, addrLen)
      }
    }

    guard connectResult == 0 else {
      close(fd)
      return nil
    }

    return fd
  }

  /// Encodes and sends one request line.
  private func send(_ request: Request, to fd: Int32) -> Bool {
    return writerQueue.sync {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      encoder.dateEncodingStrategy = .iso8601

      do {
        let data = try encoder.encode(request) + Data([0x0A])
        return writeAll(data, to: fd)
      } catch {
        logger.warn(
          "\(label) failed to encode request",
          .field("error", error),
        )
        return false
      }
    }
  }
}
