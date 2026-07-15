import Darwin
import EasyBarShared
import Foundation

/// Opens AeroSpace's native Unix socket subscription without spawning its CLI client.
final class AeroSpaceSocketSubscriptionLauncher: AeroSpaceSubscriptionLaunching,
  @unchecked Sendable
{
  private let socketPath: String

  init(socketPath: String = "/tmp/bobko.aerospace-\(NSUserName()).sock") {
    self.socketPath = socketPath
  }

  func canLaunchSubscription(arguments: [String]) -> Bool {
    FileManager.default.fileExists(atPath: socketPath)
  }

  func makeSubscription(arguments: [String]) -> AeroSpaceSubscriptionSession? {
    AeroSpaceSocketSubscriptionSession(socketPath: socketPath, arguments: arguments)
  }
}

private final class AeroSpaceSocketSubscriptionSession: AeroSpaceSubscriptionSession,
  @unchecked Sendable
{
  private static let protocolVersion: UInt32 = 1

  private struct State {
    var fd: Int32 = -1
    var stopped = false
    var terminationStatus: Int32 = 0
  }

  private struct Request: Encodable {
    let args: [String]
    let stdin = ""
    let windowId: UInt32? = nil
    let workspace: String? = nil
  }

  private let socketPath: String
  private let arguments: [String]
  private let state = LockedState(State())

  var terminationStatus: Int32 {
    state.withLock(\.terminationStatus)
  }

  init(socketPath: String, arguments: [String]) {
    self.socketPath = socketPath
    self.arguments = arguments
  }

  func start(
    onOutputData: @escaping @Sendable (Data) -> Void,
    onErrorData: @escaping @Sendable (Data) -> Void,
    onTermination: @escaping @Sendable (AeroSpaceSubscriptionSession) -> Void
  ) throws {
    let fd = try openConnectedUnixSocket(at: socketPath)
    do {
      try performHandshake(fd: fd)
      try sendSubscriptionRequest(fd: fd)
    } catch {
      Darwin.close(fd)
      throw error
    }

    let accepted = state.withLock { state -> Bool in
      guard !state.stopped else { return false }
      state.fd = fd
      return true
    }
    guard accepted else {
      Darwin.close(fd)
      return
    }

    DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      self.readEvents(
        fd: fd,
        onOutputData: onOutputData,
        onErrorData: onErrorData
      )
      self.finish(fd: fd)
      onTermination(self)
    }
  }

  func stop() {
    closeSocket(markStopped: true)
  }

  func invalidate() {
    closeSocket(markStopped: true)
  }

  private func performHandshake(fd: Int32) throws {
    try writeUInt32(Self.protocolVersion, to: fd)
    let serverVersion = try readUInt32(from: fd)
    guard serverVersion == Self.protocolVersion else {
      throw SocketError("unsupported AeroSpace socket protocol \(serverVersion)")
    }
  }

  private func sendSubscriptionRequest(fd: Int32) throws {
    let payload = try JSONEncoder().encode(Request(args: arguments))
    try writeUInt32(UInt32(payload.count), to: fd)
    guard writeAll(payload, to: fd) else {
      throw SocketError("failed to write AeroSpace subscription request")
    }
  }

  private func readEvents(
    fd: Int32,
    onOutputData: @escaping @Sendable (Data) -> Void,
    onErrorData: @escaping @Sendable (Data) -> Void
  ) {
    do {
      while !state.withLock(\.stopped) {
        let length = try readUInt32(from: fd)
        guard length > 0, length <= 1_048_576 else {
          throw SocketError("invalid AeroSpace event frame length \(length)")
        }
        var payload = try readExactly(Int(length), from: fd)
        payload.append(0x0A)
        onOutputData(payload)
      }
    } catch {
      guard !state.withLock(\.stopped) else { return }
      state.withLock { $0.terminationStatus = 1 }
      onErrorData(Data("\(error)\n".utf8))
    }
  }

  private func finish(fd: Int32) {
    let shouldClose = state.withLock { state -> Bool in
      guard state.fd == fd else { return false }
      state.fd = -1
      return true
    }
    if shouldClose { Darwin.close(fd) }
  }

  private func closeSocket(markStopped: Bool) {
    let fd = state.withLock { state -> Int32 in
      if markStopped { state.stopped = true }
      let fd = state.fd
      state.fd = -1
      return fd
    }
    guard fd >= 0 else { return }
    _ = shutdown(fd, SHUT_RDWR)
    Darwin.close(fd)
  }

  private func writeUInt32(_ value: UInt32, to fd: Int32) throws {
    var littleEndian = value.littleEndian
    let data = Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size)
    guard writeAll(data, to: fd) else { throw SocketError("AeroSpace socket write failed") }
  }

  private func readUInt32(from fd: Int32) throws -> UInt32 {
    let data = try readExactly(MemoryLayout<UInt32>.size, from: fd)
    return data.withUnsafeBytes { rawBuffer in
      UInt32(littleEndian: rawBuffer.loadUnaligned(as: UInt32.self))
    }
  }

  private func readExactly(_ count: Int, from fd: Int32) throws -> Data {
    var data = Data(count: count)
    var offset = 0
    while offset < count {
      let readCount = data.withUnsafeMutableBytes { buffer in
        Darwin.read(fd, buffer.baseAddress!.advanced(by: offset), count - offset)
      }
      if readCount > 0 {
        offset += readCount
      } else if readCount == 0 {
        throw SocketError("AeroSpace socket closed")
      } else if errno != EINTR {
        throw SocketError("AeroSpace socket read failed errno=\(errno)")
      }
    }
    return data
  }

  private struct SocketError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }
}
