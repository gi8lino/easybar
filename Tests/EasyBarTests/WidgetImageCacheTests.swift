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
}
