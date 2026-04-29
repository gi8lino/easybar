import Darwin
import Foundation

/// Shared newline-delimited client transport used by app-side and helper-process agent clients.
public final class AgentSocketClient<Request: Encodable, Message: Decodable> {
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

  private let lock = NSLock()
  private let queue: DispatchQueue
  private let reconnectDelay: TimeInterval = 2

  private var socketFD: Int32 = -1
  private var running = false
  private var reconnectWorkItem: DispatchWorkItem?
  private var nextReconnectDelayOverride: TimeInterval?
  private var activeConnectionID: UInt64 = 0

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

    queue = DispatchQueue(
      label: "easybar.\(label.replacingOccurrences(of: " ", with: "-"))",
      qos: .utility
    )
  }

  /// Returns whether the client currently has an open socket.
  public var isConnected: Bool {
    withLock {
      running && socketFD >= 0
    }
  }

  /// Starts the client connection loop.
  public func start() {
    let shouldConnect = withLock { () -> Bool in
      guard !running else { return false }

      running = true
      return true
    }

    guard shouldConnect else { return }

    connect()
  }

  /// Stops the client and clears published state.
  public func stop() {
    let currentFD = withLock { () -> Int32 in
      running = false
      reconnectWorkItem?.cancel()
      reconnectWorkItem = nil
      nextReconnectDelayOverride = nil

      let currentFD = socketFD
      socketFD = -1
      activeConnectionID &+= 1

      return currentFD
    }

    if currentFD >= 0 {
      shutdown(currentFD, SHUT_RDWR)
      close(currentFD)
    }

    clearState()
  }

  /// Overrides the delay used for the next reconnect attempt.
  public func setNextReconnectDelay(_ delay: TimeInterval?) {
    withLock {
      nextReconnectDelayOverride = delay
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

  /// Starts one connection attempt on the internal queue.
  private func connect() {
    queue.async {
      guard self.isRunning() else { return }

      let resolvedSocketPath = self.socketPath()
      guard let fd = self.openConnectedSocket(socketPath: resolvedSocketPath) else {
        self.scheduleReconnect()
        return
      }

      guard let connectionID = self.activateConnectedSocketFD(fd) else {
        shutdown(fd, SHUT_RDWR)
        close(fd)
        return
      }

      self.onConnected?()
      self.logger.info(
        "\(self.label) connected",
        .field("socket", resolvedSocketPath),
      )

      guard self.send(self.subscribeRequest(), to: fd) else {
        self.logger.warn("\(self.label) failed to send subscribe request")
        self.handleDisconnect(fd: fd, connectionID: connectionID)
        return
      }

      self.readLoop(fd: fd, connectionID: connectionID)
    }
  }

  /// Reads newline-delimited messages until the socket disconnects.
  private func readLoop(fd: Int32, connectionID: UInt64) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var pending = Data()

    while isActiveConnection(fd: fd, connectionID: connectionID) {
      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        processPendingLines(&pending)
        continue
      }

      if count == 0 {
        flushPendingLine(&pending)
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

  /// Decodes and handles one or more pending newline-delimited messages.
  private func processPendingLines(_ pending: inout Data) {
    while let newlineIndex = pending.firstIndex(of: 0x0A) {
      let line = pending.prefix(upTo: newlineIndex)
      pending.removeSubrange(...newlineIndex)

      guard !line.isEmpty else { continue }

      handleMessageData(Data(line))
    }
  }

  /// Decodes one trailing line without a terminating newline when present.
  private func flushPendingLine(_ pending: inout Data) {
    guard !pending.isEmpty else { return }

    handleMessageData(pending)
    pending.removeAll()
  }

  /// Decodes one message payload and forwards it to the caller.
  private func handleMessageData(_ data: Data) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      let message = try decoder.decode(Message.self, from: data)
      onDecodedMessage?()
      handleMessage(message)
    } catch {
      onDecodeError?()
      logger.warn(
        "\(label) failed to decode message",
        .field("error", error),
      )
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
    let workItem = DispatchWorkItem { [weak self] in
      self?.connect()
    }

    let (shouldSchedule, scheduledDelay) = withLock { () -> (Bool, TimeInterval) in
      reconnectWorkItem?.cancel()

      guard running else {
        return (false, reconnectDelay)
      }

      reconnectWorkItem = workItem

      let delay = nextReconnectDelayOverride ?? reconnectDelay
      nextReconnectDelayOverride = nil

      return (true, delay)
    }

    guard shouldSchedule else { return }

    logger.debug(
      "\(label) scheduling reconnect",
      .field("delay", scheduledDelay),
    )
    queue.asyncAfter(deadline: .now() + scheduledDelay, execute: workItem)
  }

  /// Sends one encoded request line to the connected socket.
  private func send(_ request: Request, to fd: Int32) -> Bool {
    let encoder = JSONEncoder()
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

  /// Returns whether the client is still running.
  private func isRunning() -> Bool {
    withLock {
      running
    }
  }

  /// Returns whether the given socket still belongs to the active connection.
  private func isActiveConnection(fd: Int32, connectionID: UInt64) -> Bool {
    withLock {
      running && socketFD == fd && activeConnectionID == connectionID
    }
  }

  /// Returns the current connection snapshot.
  private func currentConnection() -> (fd: Int32, id: UInt64) {
    withLock {
      (socketFD, activeConnectionID)
    }
  }

  /// Opens and connects one Unix socket.
  private func openConnectedSocket(socketPath: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.error(
        "\(label) failed to create socket",
        .field("errno", errno),
      )
      return nil
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.error(
        "\(label) failed to configure socket no-sigpipe",
        .field("fd", fd),
      )
      close(fd)
      return nil
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let connectResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, addrLen)
      }
    }

    guard connectResult == 0 else {
      logger.debug(
        "\(label) connect failed",
        .field("socket", socketPath),
        .field("errno", errno)
      )
      close(fd)
      return nil
    }

    return fd
  }

  /// Stores one connected socket descriptor and returns its connection id.
  private func activateConnectedSocketFD(_ fd: Int32) -> UInt64? {
    withLock {
      guard running else { return nil }

      reconnectWorkItem?.cancel()
      reconnectWorkItem = nil

      socketFD = fd
      activeConnectionID &+= 1

      return activeConnectionID
    }
  }

  /// Clears the current socket descriptor when it matches one disconnected client.
  private func clearConnectedSocketFD(_ fd: Int32, connectionID: UInt64) -> Bool {
    withLock {
      guard socketFD == fd, activeConnectionID == connectionID else {
        return false
      }

      socketFD = -1
      return true
    }
  }

  /// Runs one closure while holding the client lock.
  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }

    return body()
  }
}
