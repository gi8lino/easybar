import Darwin
import Foundation

/// Serves line-delimited JSON requests over a Unix domain socket and optionally tracks subscribers.
public final class LineSocketServerTransport<
  Subscriber,
  Request: Decodable,
  Response: Encodable
> {
  /// One currently connected subscriber entry.
  public struct SubscriberEntry {
    public let fd: Int32
    public let subscriber: Subscriber

    public init(fd: Int32, subscriber: Subscriber) {
      self.fd = fd
      self.subscriber = subscriber
    }
  }

  private let socketPath: String
  private let serverLabel: String
  private let debugLog: (String) -> Void
  private let infoLog: (String) -> Void
  private let warnLog: (String) -> Void
  private let errorLog: (String) -> Void

  private let stateLock = NSLock()
  private let acceptQueue: DispatchQueue
  private let clientQueue: DispatchQueue
  private let requestDecoder: JSONDecoder
  private let responseEncoder: JSONEncoder

  private var serverFD: Int32 = -1
  private var running = false
  private var subscribers: [Int32: Subscriber] = [:]

  /// Creates a new Unix socket server transport.
  public init(
    socketPath: String,
    serverLabel: String,
    debugLog: @escaping (String) -> Void = { _ in },
    infoLog: @escaping (String) -> Void = { _ in },
    warnLog: @escaping (String) -> Void = { _ in },
    errorLog: @escaping (String) -> Void = { _ in }
  ) {
    self.socketPath = socketPath
    self.serverLabel = serverLabel
    self.debugLog = debugLog
    self.infoLog = infoLog
    self.warnLog = warnLog
    self.errorLog = errorLog

    acceptQueue = DispatchQueue(label: "\(serverLabel).socket.accept", qos: .utility)
    clientQueue = DispatchQueue(
      label: "\(serverLabel).socket.client",
      qos: .utility,
      attributes: .concurrent
    )

    requestDecoder = JSONDecoder()
    requestDecoder.dateDecodingStrategy = .iso8601

    responseEncoder = JSONEncoder()
    responseEncoder.outputFormatting = [.sortedKeys]
    responseEncoder.dateEncodingStrategy = .iso8601
  }

  deinit {
    stop()
  }

  /// Starts listening and dispatches decoded requests to the handler.
  public func start(_ handler: @escaping (Int32, Request) -> Void) {
    stateLock.lock()
    defer { stateLock.unlock() }

    guard !running else { return }

    let socketURL = URL(fileURLWithPath: socketPath)
    let socketDir = socketURL.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)
    } catch {
      errorLog(
        "\(serverLabel) failed to create socket directory path=\(socketDir.path) error=\(error)"
      )
      return
    }

    unlink(socketPath)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      errorLog("\(serverLabel) failed to create socket")
      return
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      errorLog("\(serverLabel) bind failed path=\(socketPath) errno=\(errno)")
      close(fd)
      return
    }

    chmod(socketPath, mode_t(0o600))

    guard listen(fd, 8) == 0 else {
      errorLog("\(serverLabel) listen failed path=\(socketPath) errno=\(errno)")
      close(fd)
      unlink(socketPath)
      return
    }

    serverFD = fd
    running = true

    infoLog("\(serverLabel) listening socket_path=\(socketPath)")

    acceptQueue.async { [weak self] in
      self?.acceptLoop(handler: handler)
    }
  }

  /// Stops the server, closes subscribers, and removes the socket file.
  public func stop() {
    stateLock.lock()

    let fd = serverFD
    let wasRunning = running
    let subscriberFDs = Array(subscribers.keys)

    running = false
    serverFD = -1
    subscribers.removeAll()

    stateLock.unlock()

    guard wasRunning else { return }

    for subscriberFD in subscriberFDs {
      shutdown(subscriberFD, SHUT_RDWR)
      close(subscriberFD)
    }

    if fd >= 0 {
      shutdown(fd, SHUT_RDWR)
      close(fd)
    }

    unlink(socketPath)
    infoLog("\(serverLabel) stopped socket_path=\(socketPath)")
  }

  /// Sends one encoded response to the given client file descriptor.
  @discardableResult
  public func send(_ response: Response, to clientFD: Int32) -> Bool {
    guard let data = try? responseEncoder.encode(response) else {
      errorLog("\(serverLabel) response encode failed")
      return false
    }

    return writeAll(data + Data([0x0A]), to: clientFD)
  }

  /// Adds one subscriber for future broadcasts.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    stateLock.lock()
    subscribers[fd] = subscriber
    stateLock.unlock()

    debugLog("\(serverLabel) subscriber added fd=\(fd)")
  }

  /// Removes one subscriber and closes its socket.
  @discardableResult
  public func removeSubscriber(fd: Int32) -> Bool {
    stateLock.lock()
    let existed = subscribers.removeValue(forKey: fd) != nil
    stateLock.unlock()

    shutdown(fd, SHUT_RDWR)
    close(fd)

    if existed {
      debugLog("\(serverLabel) subscriber removed fd=\(fd)")
    }

    return existed
  }

  /// Returns a stable snapshot of current subscribers.
  public func subscribersSnapshot() -> [SubscriberEntry] {
    stateLock.lock()
    let snapshot = subscribers.map { SubscriberEntry(fd: $0.key, subscriber: $0.value) }
    stateLock.unlock()
    return snapshot
  }

  /// Accepts client connections until the server stops.
  private func acceptLoop(handler: @escaping (Int32, Request) -> Void) {
    while isRunning() {
      let fd = currentServerFD()
      if fd < 0 { break }

      let clientFD = accept(fd, nil, nil)
      if clientFD < 0 {
        if !isRunning() {
          break
        }
        continue
      }

      clientQueue.async { [weak self] in
        self?.handleClient(clientFD, handler: handler)
      }
    }
  }

  /// Reads one request, decodes it, and invokes the handler.
  private func handleClient(_ clientFD: Int32, handler: @escaping (Int32, Request) -> Void) {
    guard let data = readOneLine(from: clientFD), !data.isEmpty else {
      close(clientFD)
      return
    }

    do {
      let request = try requestDecoder.decode(Request.self, from: data)
      handler(clientFD, request)
    } catch {
      warnLog("\(serverLabel) request decode failed error=\(error)")
      close(clientFD)
    }
  }

  /// Returns whether the server is running.
  private func isRunning() -> Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return running
  }

  /// Returns the current server socket file descriptor.
  private func currentServerFD() -> Int32 {
    stateLock.lock()
    defer { stateLock.unlock() }
    return serverFD
  }

  /// Reads bytes until a newline or EOF is reached.
  private func readOneLine(from fd: Int32) -> Data? {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while true {
      let n = read(fd, &buffer, buffer.count)
      if n < 0 { return nil }
      if n == 0 { break }

      if let newlineIndex = buffer[..<n].firstIndex(of: 0x0A) {
        let count = buffer.distance(from: 0, to: newlineIndex)
        data.append(buffer, count: count)
        break
      }

      data.append(buffer, count: n)
    }

    return data
  }
}
