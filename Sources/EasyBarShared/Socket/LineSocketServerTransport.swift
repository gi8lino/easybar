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

  /// Describes what should happen to a client socket after one request was handled.
  public enum ClientDisposition {
    case close
    case keepOpen
  }

  private let socketPath: String
  private let serverLabel: String
  private let logger: ProcessLogger

  private let stateLock = NSLock()
  private let acceptQueue: DispatchQueue
  private let clientQueue: DispatchQueue

  private var serverFD: Int32 = -1
  private var running = false
  private var subscribers: [Int32: Subscriber] = [:]

  /// Creates a new Unix socket server transport.
  public init(
    socketPath: String,
    serverLabel: String,
    logger: ProcessLogger
  ) {
    self.socketPath = socketPath
    self.serverLabel = serverLabel
    self.logger = logger

    acceptQueue = DispatchQueue(
      label: "\(serverLabel).socket.accept",
      qos: .utility
    )

    clientQueue = DispatchQueue(
      label: "\(serverLabel).socket.client",
      qos: .utility,
      attributes: .concurrent
    )
  }

  deinit {
    stop()
  }

  /// Starts listening and dispatches decoded requests to the handler.
  public func start(_ handler: @escaping (Int32, Request) -> ClientDisposition) {
    stateLock.lock()
    defer { stateLock.unlock() }

    guard !running else { return }

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
        "path", "\(socketDir.path)",
        "error", "\(error)",
      )
      return
    }

    unlink(socketPath)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      logger.error(
        "\(serverLabel) failed to create socket",
        "errno", "\(errno)",
      )
      return
    }

    guard configureNoSigPipe(fd: fd) else {
      logger.error(
        "\(serverLabel) failed to configure server socket no-sigpipe",
        "fd", "\(fd)",
      )
      close(fd)
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
      logger.error(
        "\(serverLabel) bind failed",
        "path", "\(socketPath)",
        "errno", "\(errno)",
      )
      close(fd)
      return
    }

    if chmod(socketPath, mode_t(0o600)) != 0 {
      logger.warn(
        "\(serverLabel) chmod failed",
        "path", "\(socketPath)",
        "errno", "\(errno)",
      )
    }

    guard listen(fd, 8) == 0 else {
      logger.error(
        "\(serverLabel) listen failed",
        "path", "\(socketPath)",
        "errno", "\(errno)",
      )
      close(fd)
      unlink(socketPath)
      return
    }

    serverFD = fd
    running = true

    logger.info(
      "\(serverLabel) listening",
      "socket_path", "\(socketPath)",
    )

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
    logger.info(
      "\(serverLabel) stopped",
      "socket_path=\(socketPath)",
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
        "error", "\(error)",
      )
      return false
    }
  }

  /// Adds one subscriber for future broadcasts.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    stateLock.lock()
    subscribers[fd] = subscriber
    stateLock.unlock()

    logger.debug(
      "\(serverLabel) subscriber added",
      "fd", "\(fd)",
    )
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
      logger.debug(
        "\(serverLabel) subscriber removed",
        "fd", "\(fd)",
      )
    }

    return existed
  }

  /// Returns a stable snapshot of current subscribers.
  public func subscribersSnapshot() -> [SubscriberEntry] {
    stateLock.lock()
    let snapshot = subscribers.map {
      SubscriberEntry(fd: $0.key, subscriber: $0.value)
    }
    stateLock.unlock()

    return snapshot
  }

  /// Accepts client connections until the server stops.
  private func acceptLoop(handler: @escaping (Int32, Request) -> ClientDisposition) {
    while isRunning() {
      let fd = currentServerFD()
      if fd < 0 { break }

      let clientFD = accept(fd, nil, nil)
      if clientFD < 0 {
        if errno == EINTR {
          continue
        }

        if !isRunning() {
          break
        }

        logger.debug(
          "\(serverLabel) accept failed",
          "errno", "\(errno)",
        )
        continue
      }

      guard configureNoSigPipe(fd: clientFD) else {
        logger.error(
          "\(serverLabel) failed to configure client socket no-sigpipe",
          "fd", "\(clientFD)",
        )
        close(clientFD)
        continue
      }

      clientQueue.async { [weak self] in
        self?.handleClient(clientFD, handler: handler)
      }
    }
  }

  /// Reads requests until the client disconnects and invokes the handler for each line.
  private func handleClient(
    _ clientFD: Int32,
    handler: @escaping (Int32, Request) -> ClientDisposition
  ) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var pending = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
      if let requestData = nextLine(from: &pending) {
        do {
          let request = try decoder.decode(Request.self, from: requestData)
          let disposition = handler(clientFD, request)

          switch disposition {
          case .close:
            close(clientFD)
            return

          case .keepOpen:
            return
          }
        } catch {
          logger.warn(
            "\(serverLabel) request decode failed",
            "error", "\(error)",
          )
          close(clientFD)
          return
        }
      }

      let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.read(clientFD, baseAddress, rawBuffer.count)
      }

      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        continue
      }

      if count == 0 {
        close(clientFD)
        return
      }

      if errno == EINTR {
        continue
      }

      logger.debug(
        "\(serverLabel) client read failed",
        "fd", "\(clientFD)",
        "errno", "\(errno)",
      )
      close(clientFD)
      return
    }
  }

  /// Returns the next complete non-empty line from the pending buffer when available.
  private func nextLine(from pending: inout Data) -> Data? {
    while let newlineIndex = pending.firstIndex(of: 0x0A) {
      let line = Data(pending.prefix(upTo: newlineIndex))
      pending.removeSubrange(...newlineIndex)

      if !line.isEmpty {
        return line
      }
    }

    return nil
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
}
