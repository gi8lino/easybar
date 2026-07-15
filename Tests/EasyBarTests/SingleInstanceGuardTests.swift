import EasyBarShared
import Foundation
import XCTest

final class SingleInstanceGuardTests: XCTestCase {
  func testSuccessfulRebindReleasesPreviousLock() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let firstPath = directory.appendingPathComponent("first.lock").path
    let secondPath = directory.appendingPathComponent("second.lock").path
    let guardUnderTest = SingleInstanceGuard()

    XCTAssertEqual(guardUnderTest.acquireLock(at: firstPath), .acquired)
    XCTAssertEqual(guardUnderTest.acquireLock(at: secondPath), .acquired)

    let firstProbe = SingleInstanceGuard()
    let secondProbe = SingleInstanceGuard()
    XCTAssertEqual(firstProbe.acquireLock(at: firstPath), .acquired)
    XCTAssertEqual(secondProbe.acquireLock(at: secondPath), .alreadyRunning)
  }

  func testFailedRebindKeepsPreviousLock() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let firstPath = directory.appendingPathComponent("first.lock").path
    let blockedPath = directory.appendingPathComponent("blocked.lock").path
    let guardUnderTest = SingleInstanceGuard()
    let blocker = SingleInstanceGuard()

    XCTAssertEqual(guardUnderTest.acquireLock(at: firstPath), .acquired)
    XCTAssertEqual(blocker.acquireLock(at: blockedPath), .acquired)
    XCTAssertEqual(guardUnderTest.acquireLock(at: blockedPath), .alreadyRunning)

    let firstProbe = SingleInstanceGuard()
    XCTAssertEqual(firstProbe.acquireLock(at: firstPath), .alreadyRunning)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-single-instance-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
