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

    let socketDirectory = socketDirectoryPath(for: socketPath)

    do {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
        withIntermediateDirectories: true
      )
    } catch {
      errorLog("failed to create \(serverLabel) socket directory at \(socketDirectory): \(error)")
      return
    }

    unlink(socketPath)

    listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard listenFD >= 0 else {
      errorLog("failed to create \(serverLabel) socket")
      return
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(self.listenFD, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      errorLog("failed to bind \(serverLabel) socket at \(socketPath)")
      close(listenFD)
      listenFD = -1
      return
    }

    guard listen(listenFD, 8) == 0 else {
      errorLog("failed to listen on \(serverLabel) socket at \(socketPath)")
      close(listenFD)
      listenFD = -1
      return
    }

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
    subscribersLock.lock()
    subscribers[fd] = subscriber
    subscribersLock.unlock()
  }

  /// Removes one subscriber and closes its socket.
  @discardableResult
  public func removeSubscriber(fd: Int32) -> Subscriber? {
    subscribersLock.lock()
    let existing = subscribers.removeValue(forKey: fd)
    subscribersLock.unlock()

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
      return sendAll(fd, data)
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

      DispatchQueue.global(qos: .utility).async {
        self.handleClient(clientFD, handleRequest: handleRequest)
      }
    }
  }

  private func handleClient(_ clientFD: Int32, handleRequest: @escaping (Int32, Request) -> Void) {
    guard let request = readRequest(from: clientFD) else {
      close(clientFD)
      return
    }

    handleRequest(clientFD, request)
  }

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

  private func sendAll(_ fd: Int32, _ data: Data) -> Bool {
    data.withUnsafeBytes { rawBuffer in
      guard let base = rawBuffer.baseAddress else { return false }

      var sent = 0
      while sent < data.count {
        let written = write(fd, base.advanced(by: sent), data.count - sent)
        if written <= 0 {
          return false
        }
        sent += written
      }

      return true
    }
  }

  private func isRunning() -> Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return running
  }
}
