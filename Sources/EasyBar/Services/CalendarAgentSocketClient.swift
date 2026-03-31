import Darwin
import Foundation

/// Small newline-delimited Unix-domain socket client used by calendar services.
final class CalendarAgentSocketClient {

  private let socketPath: String
  private let queue = DispatchQueue(label: "easybar.calendar.socket-client")
  private let encoder = JSONEncoder()

  private var socketFD: Int32 = -1
  private var readSource: DispatchSourceRead?
  private var readBuffer = Data()

  var onMessage: ((String) -> Void)?
  var onDisconnect: (() -> Void)?

  /// Builds one socket client for the given Unix socket path.
  init(socketPath: String) {
    self.socketPath = socketPath
    encoder.dateEncodingStrategy = .iso8601
  }

  /// Starts the socket connection and line reader.
  func start() {
    queue.async { [weak self] in
      self?.startOnQueue()
    }
  }

  /// Stops the socket connection and reader.
  func stop() {
    queue.async { [weak self] in
      self?.stopOnQueue(notifyDisconnect: false)
    }
  }

  /// Sends one JSON-encodable request line to the server.
  func send<T: Encodable>(_ value: T) {
    queue.async { [weak self] in
      self?.sendOnQueue(value)
    }
  }
}

// MARK: - Internal Lifecycle

extension CalendarAgentSocketClient {
  /// Starts the socket connection on the internal queue.
  private func startOnQueue() {
    guard socketFD == -1 else { return }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      notifyDisconnect()
      return
    }

    guard connectSocket(fd: fd, path: socketPath) else {
      close(fd)
      notifyDisconnect()
      return
    }

    socketFD = fd
    installReadSource(fd: fd)
  }

  /// Stops the socket connection and tears down readers.
  private func stopOnQueue(notifyDisconnect: Bool) {
    readSource?.cancel()
    readSource = nil
    readBuffer.removeAll()

    if socketFD >= 0 {
      close(socketFD)
      socketFD = -1
    }

    if notifyDisconnect {
      self.notifyDisconnect()
    }
  }

  /// Sends one encoded payload as a newline-delimited JSON line.
  private func sendOnQueue<T: Encodable>(_ value: T) {
    guard socketFD >= 0 else { return }

    do {
      var data = try encoder.encode(value)
      data.append(0x0A)

      data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }

        var bytesSent = 0
        while bytesSent < data.count {
          let result = write(
            socketFD,
            baseAddress.advanced(by: bytesSent),
            data.count - bytesSent
          )

          if result <= 0 {
            stopOnQueue(notifyDisconnect: true)
            return
          }

          bytesSent += result
        }
      }
    } catch {
      stopOnQueue(notifyDisconnect: true)
    }
  }
}

// MARK: - Reading

extension CalendarAgentSocketClient {
  /// Installs the read source that decodes newline-delimited messages.
  private func installReadSource(fd: Int32) {
    let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
    readSource = source

    source.setEventHandler { [weak self] in
      self?.handleReadableSocket()
    }

    source.setCancelHandler {}

    source.resume()
  }

  /// Reads available bytes and emits complete UTF-8 lines.
  private func handleReadableSocket() {
    guard socketFD >= 0 else { return }

    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
      let count = read(socketFD, &buffer, buffer.count)

      if count > 0 {
        readBuffer.append(buffer, count: count)
        emitBufferedLines()
        continue
      }

      if count == 0 {
        stopOnQueue(notifyDisconnect: true)
        return
      }

      if errno == EAGAIN || errno == EWOULDBLOCK {
        return
      }

      stopOnQueue(notifyDisconnect: true)
      return
    }
  }

  /// Emits all complete buffered UTF-8 lines.
  private func emitBufferedLines() {
    while let newlineIndex = readBuffer.firstIndex(of: 0x0A) {
      let lineData = readBuffer.prefix(upTo: newlineIndex)
      readBuffer.removeSubrange(...newlineIndex)

      guard
        let line = String(data: lineData, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines),
        !line.isEmpty
      else {
        continue
      }

      DispatchQueue.main.async { [weak self] in
        self?.onMessage?(line)
      }
    }
  }
}

// MARK: - Socket Helpers

extension CalendarAgentSocketClient {
  /// Connects one Unix-domain socket to the given filesystem path.
  private func connectSocket(fd: Int32, path: String) -> Bool {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)

    let maxLength = MemoryLayout.size(ofValue: address.sun_path)

    let utf8 = Array(path.utf8)
    guard utf8.count < maxLength else {
      return false
    }

    withUnsafeMutablePointer(to: &address.sun_path) { pointer in
      let raw = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
      raw.initialize(repeating: 0, count: maxLength)

      for (index, byte) in utf8.enumerated() {
        raw[index] = byte
      }
    }

    let length = socklen_t(MemoryLayout<sa_family_t>.size + utf8.count + 1)

    return withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        connect(fd, sockaddrPointer, length) == 0
      }
    }
  }

  /// Notifies listeners that the connection was lost.
  private func notifyDisconnect() {
    DispatchQueue.main.async { [weak self] in
      self?.onDisconnect?()
    }
  }
}
