import Darwin
import EasyBarShared
import XCTest

final class UnixSocketAddressTests: XCTestCase {
  private var temporaryDirectory: URL?

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
    try super.tearDownWithError()
  }

  func testMakeSockAddrUnAcceptsMaximumLengthPath() throws {
    let maxPathBytes = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1
    let path = "/" + String(repeating: "a", count: maxPathBytes - 1)

    XCTAssertNoThrow(try makeSockAddrUn(path: path))
  }

  func testMakeSockAddrUnRejectsOverlongPath() {
    let maxPathBytes = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1
    let path = "/" + String(repeating: "a", count: maxPathBytes)

    XCTAssertThrowsError(try makeSockAddrUn(path: path)) { error in
      guard case UnixSocketAddressError.pathTooLong(let rejectedPath, let rejectedMaxBytes) = error
      else {
        return XCTFail("Expected pathTooLong, got \(error)")
      }

      XCTAssertEqual(rejectedPath, path)
      XCTAssertEqual(rejectedMaxBytes, maxPathBytes)
    }
  }

  func testMakeListeningUnixSocketReplacesStalePathAndAppliesPrivateMode() throws {
    let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("eb-\(UUID().uuidString.prefix(8))", isDirectory: true)
    temporaryDirectory = directory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let socketPath = directory.appendingPathComponent("server.sock").path
    try "stale".write(toFile: socketPath, atomically: true, encoding: .utf8)

    let fd = try makeListeningUnixSocket(at: socketPath, backlog: 1)
    defer {
      closeListeningUnixSocket(fd, at: socketPath)
    }

    var info = stat()
    XCTAssertEqual(lstat(socketPath, &info), 0)
    XCTAssertEqual(info.st_mode & S_IFMT, S_IFSOCK)
    XCTAssertEqual(info.st_mode & 0o777, 0o600)
  }
}
