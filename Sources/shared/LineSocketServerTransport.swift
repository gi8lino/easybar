import Darwin
import Foundation

/// Shared newline-delimited Unix socket transport used by agent servers.
public final class LineSocketServerTransport<Subscriber, Request: Decodable, Message: Encodable> {
  private let socketPath: String
  private let serverLabel: String
  private let debugLog: (String) -> Void
  private let infoLog: (String) -> Void
  private let warnLog: (String) -> Void
  private let errorLog: (String) -> Void
  private let stateLock = NSLock()
  private let subscribersLock = NSLock()
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private var listenFD: Int32 = -1
  private var running = false
  private var subscribers: [Int32: Subscriber] = [:]

  /// Creates one shared agent socket transport.
  public init(
    socketPath: String,
    serverLabel: String,
    debugLog: @escaping (String) -> Void,
    infoLog: @escaping (String) -> Void,
    warnLog: @escaping (String) -> Void,
    errorLog: @escaping (String) -> Void
  ) {
    self.socketPath = socketPath
    self.serverLabel = serverLabel
    self.debugLog = debugLog
    self.infoLog = infoLog
    self.warnLog = warnLog
    self.errorLog = errorLog
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  /// Starts the Unix socket listener.
  public func start(handleRequest: @escaping (Int32, Request) -> Void) {
    stateLock.lock()
    defer { stateLock.unlock() }

    guard !running else { return }

    guard prepareSocketDirectory() else { return }
    guard openListeningSocket() else { return }
    guard bindListeningSocket() else { return }
    guard startListening() else { return }

    running = true
    infoLog("\(serverLabel) socket listening on \(socketPath)")

    DispatchQueue.global(qos: .userInitiated).async {
      self.acceptLoop(handleRequest: handleRequest)
    }
  }

  /// Stops the listener and closes all subscriber sockets.
  public func stop() {
    stateLock.lock()
    let currentListenFD = listenFD
    let wasRunning = running
    running = false
    listenFD = -1
    stateLock.unlock()

    guard wasRunning else { return }

    if currentListenFD >= 0 {
      shutdown(currentListenFD, SHUT_RDWR)
      close(currentListenFD)
    }

    subscribersLock.lock()
    let currentSubscriberFDs = Array(subscribers.keys)
    subscribers.removeAll()
    subscribersLock.unlock()

    for fd in currentSubscriberFDs {
      shutdown(fd, SHUT_RDWR)
      close(fd)
    }

    unlink(socketPath)
  }

  /// Returns a snapshot of current subscribers.
  public func subscribersSnapshot() -> [(fd: Int32, subscriber: Subscriber)] {
    subscribersLock.lock()
    defer { subscribersLock.unlock() }
    return subscribers.map { (fd: $0.key, subscriber: $0.value) }
  }

  /// Stores one subscriber for future broadcasts.
  public func addSubscriber(_ subscriber: Subscriber, for fd: Int32) {
    withSubscribersLock {
      subscribers[fd] = subscriber
    }
  }

  /// Removes one subscriber and closes its socket.
  @discardableResult
  public func removeSubscriber(fd: Int32) -> Subscriber? {
    let existing = withSubscribersLock {
      subscribers.removeValue(forKey: fd)
    }

    guard existing != nil else { return nil }

    infoLog("\(serverLabel) subscriber removed fd=\(fd)")
    shutdown(fd, SHUT_RDWR)
    close(fd)
    return existing
  }

  /// Sends one encoded message to one connected client.
  public func send(_ message: Message, to fd: Int32) -> Bool {
    do {
      let data = try encoder.encode(message) + Data("\n".utf8)
      return writeAll(data, to: fd)
    } catch {
      warnLog("failed to encode \(serverLabel) message: \(error)")
      return false
    }
  }

  private func acceptLoop(handleRequest: @escaping (Int32, Request) -> Void) {
    while isRunning() {
      let clientFD = accept(listenFD, nil, nil)
      if clientFD < 0 {
        if !isRunning() {
          break
        }
        continue
      }

      debugLog("\(serverLabel) accepted client fd=\(clientFD)")
      readAndHandleClient(clientFD, handleRequest: handleRequest)
    }
  }

  /// Reads and dispatches one connected client request.
  private func readAndHandleClient(_ clientFD: Int32, handleRequest: @escaping (Int32, Request) -> Void) {
    guard let request = readRequest(from: clientFD) else {
      close(clientFD)
      return
    }

    handleRequest(clientFD, request)
  }

  /// Reads one newline-delimited request from one client socket.
  private func readRequest(from fd: Int32) -> Request? {
    var buffer = [UInt8](repeating: 0, count: 4096)
    let count = read(fd, &buffer, buffer.count)

    guard count > 0 else { return nil }

    let raw = String(decoding: buffer.prefix(count), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let data = raw.data(using: .utf8) else { return nil }

    do {
      return try decoder.decode(Request.self, from: data)
    } catch {
      warnLog("failed to decode \(serverLabel) request: \(error)")
      return nil
    }
  }

  /// Creates the socket directory when it does not exist yet.
  private func prepareSocketDirectory() -> Bool {
    let socketDirectory = socketDirectoryPath(for: socketPath)

    do {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
        withIntermediateDirectories: true
      )
      return true
    } catch {
      errorLog("failed to create \(serverLabel) socket directory at \(socketDirectory): \(error)")
      return false
    }
  }

  /// Opens the listening file descriptor for this transport.
  private func openListeningSocket() -> Bool {
    unlink(socketPath)

    listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard listenFD >= 0 else {
      errorLog("failed to create \(serverLabel) socket")
      return false
    }

    return true
  }

  /// Binds the listening file descriptor to the configured path.
  private func bindListeningSocket() -> Bool {
    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(self.listenFD, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      errorLog("failed to bind \(serverLabel) socket at \(socketPath)")
      closeListeningSocket()
      return false
    }

    return true
  }

  /// Starts listening for client connections.
  private func startListening() -> Bool {
    guard listen(listenFD, 8) == 0 else {
      errorLog("failed to listen on \(serverLabel) socket at \(socketPath)")
      closeListeningSocket()
      return false
    }

    return true
  }

  /// Closes the current listening socket and clears its state.
  private func closeListeningSocket() {
    guard listenFD >= 0 else { return }
    close(listenFD)
    listenFD = -1
  }

  /// Runs one closure while holding the subscribers lock.
  private func withSubscribersLock<T>(_ body: () -> T) -> T {
    subscribersLock.lock()
    defer { subscribersLock.unlock() }
    return body()
  }

  /// Returns whether the transport is still accepting clients.
  private func isRunning() -> Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return running
  }
}
