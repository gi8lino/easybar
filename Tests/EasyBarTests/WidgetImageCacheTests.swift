import Foundation
import XCTest

@testable import EasyBarApp

final class WidgetImageCacheTests: XCTestCase {
  func testUnchangedPathReusesDecodedImage() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let path = directory.appendingPathComponent("missing-image.png").path
    let cache = WidgetImageCache()
    let first = await cache.image(for: path)
    let second = await cache.image(for: path)

    XCTAssertTrue(first === second)
  }

  func testLeastRecentlyUsedImageIsEvictedAtCapacity() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let firstPath = directory.appendingPathComponent("first.png").path
    let secondPath = directory.appendingPathComponent("second.png").path
    let thirdPath = directory.appendingPathComponent("third.png").path
    let cache = WidgetImageCache(capacity: 2)

    let first = await cache.image(for: firstPath)
    let second = await cache.image(for: secondPath)
    _ = await cache.image(for: firstPath)
    _ = await cache.image(for: thirdPath)
    let reloadedFirst = await cache.image(for: firstPath)
    let reloadedSecond = await cache.image(for: secondPath)

    XCTAssertTrue(first === reloadedFirst)
    XCTAssertFalse(second === reloadedSecond)
  }
}
