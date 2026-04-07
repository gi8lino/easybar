import Darwin
import Foundation

/// Shared newline-delimited client transport used by app-side and helper-process agent clients.
public final class AgentSocketClient<Request: Encodable, Message: Decodable> {
  private let label: String
  private let socketPath: () -> String
  private let subscribeRequest: () -> Request
  private let handleMessage: (Message) -> Void
  private let clearState: () -> Void

  private let debugLog: (String) -> Void
  private let infoLog: (String) -> Void
  private let warnLog: (String) -> Void
  private let errorLog: (String) -> Void

  private let lock = NSLock()
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let queue: DispatchQueue
  private let reconnectDelay: TimeInterval = 2

  private var socketFD: Int32 = -1
  private var running = false
  private var reconnectWorkItem: DispatchWorkItem?
  private var nextReconnectDelayOverride: TimeInterval?

  /// Creates one shared agent client transport.
  public init(
    label: String,
    socketPath: @escaping () -> String,
    subscribeRequest: @escaping () -> Request,
    handleMessage: @escaping (Message) -> Void,
    clearState: @escaping () -> Void,
    debugLog: @escaping (String) -> Void = { _ in },
    infoLog: @escaping (String) -> Void = { _ in },
    warnLog: @escaping (String) -> Void = { _ in },
    errorLog: @escaping (String) -> Void = { _ in }
  ) {
    self.label = label
    self.socketPath = socketPath
    self.subscribeRequest = subscribeRequest
    self.handleMessage = handleMessage
    self.clearState = clearState
    self.debugLog = debugLog
    self.infoLog = infoLog
    self.warnLog = warnLog
    self.errorLog = errorLog

    queue = DispatchQueue(
      label: "easybar.\(label.replacingOccurrences(of: " ", with: "-"))",
      qos: .utility
    )

    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  /// Returns whether the client currently has an open socket.
  public var isConnected: Bool {
    withLock { socketFD >= 0 }
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

      let currentFD = socketFD
      socketFD = -1
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
    let currentFD = withLock { socketFD }
    guard currentFD >= 0 else { return }

    guard send(subscribeRequest(), to: currentFD) else {
      warnLog("\(label) failed to send refresh request")
      handleDisconnect(fd: currentFD)
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

      self.setConnectedSocketFD(fd)
      self.infoLog("\(self.label) connected socket=\(resolvedSocketPath)")

      guard self.send(self.subscribeRequest(), to: fd) else {
        self.warnLog("\(self.label) failed to send subscribe request")
        self.handleDisconnect(fd: fd)
        return
      }

      self.readLoop(fd: fd)
    }
  }

  /// Reads newline-delimited messages until the socket disconnects.
  private func readLoop(fd: Int32) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var pending = Data()

    while isRunning() {
      let count = read(fd, &buffer, buffer.count)

      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        processPendingLines(&pending)
        continue
      }

      if count == 0 {
        break
      }

      if errno == EINTR {
        continue
      }

      debugLog("\(label) read failed errno=\(errno)")
      break
    }

    handleDisconnect(fd: fd)
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

  /// Decodes one message payload and forwards it to the caller.
  private func handleMessageData(_ data: Data) {
    do {
      let message = try decoder.decode(Message.self, from: data)
      handleMessage(message)
    } catch {
      warnLog("\(label) failed to decode message: \(error)")
    }
  }

  /// Handles one socket disconnect and schedules reconnect when still running.
  private func handleDisconnect(fd: Int32) {
    clearConnectedSocketFD(fd)

    shutdown(fd, SHUT_RDWR)
    close(fd)

    clearState()

    guard isRunning() else { return }

    infoLog("\(label) disconnected")
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

    debugLog("\(label) scheduling reconnect delay=\(scheduledDelay)")
    queue.asyncAfter(deadline: .now() + scheduledDelay, execute: workItem)
  }

  /// Sends one encoded request line to the connected socket.
  private func send(_ request: Request, to fd: Int32) -> Bool {
    do {
      let data = try encoder.encode(request) + Data("\n".utf8)
      return writeAll(data, to: fd)
    } catch {
      warnLog("\(label) failed to encode request: \(error)")
      return false
    }
  }

  /// Returns whether the client is still running.
  private func isRunning() -> Bool {
    withLock { running }
  }

  /// Opens and connects one Unix socket.
  private func openConnectedSocket(socketPath: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      errorLog("\(label) failed to create socket")
      return nil
    }

    guard configureNoSigPipe(fd: fd) else {
      errorLog("\(label) failed to configure socket no-sigpipe")
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
      debugLog("\(label) connect failed socket=\(socketPath)")
      close(fd)
      return nil
    }

    return fd
  }

  /// Stores one connected socket descriptor.
  private func setConnectedSocketFD(_ fd: Int32) {
    withLock {
      socketFD = fd
    }
  }

  /// Clears the current socket descriptor when it matches one disconnected client.
  private func clearConnectedSocketFD(_ fd: Int32) {
    withLock {
      guard socketFD == fd else { return }
      socketFD = -1
    }
  }

  /// Runs one closure while holding the client lock.
  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}
