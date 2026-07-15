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

    XCTAssertEqual(guardUnderTest.acquireLock(at: firstPath), .acquired(lockPath: firstPath))
    XCTAssertEqual(guardUnderTest.acquireLock(at: secondPath), .acquired(lockPath: secondPath))

    let firstProbe = SingleInstanceGuard()
    let secondProbe = SingleInstanceGuard()
    XCTAssertEqual(firstProbe.acquireLock(at: firstPath), .acquired(lockPath: firstPath))
    XCTAssertEqual(
      secondProbe.acquireLock(at: secondPath),
      .alreadyRunning(lockPath: secondPath)
    )
  }

  func testFailedRebindKeepsPreviousLock() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let firstPath = directory.appendingPathComponent("first.lock").path
    let blockedPath = directory.appendingPathComponent("blocked.lock").path
    let guardUnderTest = SingleInstanceGuard()
    let blocker = SingleInstanceGuard()

    XCTAssertEqual(guardUnderTest.acquireLock(at: firstPath), .acquired(lockPath: firstPath))
    XCTAssertEqual(blocker.acquireLock(at: blockedPath), .acquired(lockPath: blockedPath))
    XCTAssertEqual(
      guardUnderTest.acquireLock(at: blockedPath),
      .alreadyRunning(lockPath: blockedPath)
    )

    let firstProbe = SingleInstanceGuard()
    XCTAssertEqual(firstProbe.acquireLock(at: firstPath), .alreadyRunning(lockPath: firstPath))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-single-instance-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
