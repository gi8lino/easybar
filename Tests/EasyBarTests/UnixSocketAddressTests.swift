import Darwin
import EasyBarShared
import XCTest

final class UnixSocketAddressTests: XCTestCase {
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
}
