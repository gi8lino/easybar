import Foundation
import XCTest

@testable import EasyBarApp

final class WidgetImageCacheTests: XCTestCase {
  private static let pixelPNG = Data(
    base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )!

  private func loadedImage(from result: WidgetImageLoadResult) throws -> LoadedWidgetImage {
    guard case .loaded(let image) = result else {
      throw XCTSkip("Expected a decoded test image")
    }
    return image
  }

  @MainActor
  func testLoaderPublishesDecodedCustomImage() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("pixel.png")
    try Self.pixelPNG.write(to: url)

    let loader = WidgetImageLoader()
    XCTAssertNil(loader.image(for: url.path))

    let shouldLogFailure = await loader.load(path: url.path)

    let loaded = try XCTUnwrap(loader.image(for: url.path))
    XCTAssertFalse(shouldLogFailure)
    XCTAssertEqual(loaded.image.size, CGSize(width: 1, height: 1))
  }

  @MainActor
  func testLoaderReportsDecodeFailureOnlyOncePerPath() async throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("png").path
    let loader = WidgetImageLoader()

    let firstShouldLog = await loader.load(path: path)
    let secondShouldLog = await loader.load(path: path)

    XCTAssertTrue(firstShouldLog)
    XCTAssertFalse(secondShouldLog)
    XCTAssertNil(loader.image(for: path))
  }

  func testUnchangedPathReusesDecodedImage() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let path = directory.appendingPathComponent("image.png").path
    try Self.pixelPNG.write(to: URL(fileURLWithPath: path))
    let cache = WidgetImageCache()
    let first = try loadedImage(from: await cache.image(for: path))
    let second = try loadedImage(from: await cache.image(for: path))

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
    try Self.pixelPNG.write(to: URL(fileURLWithPath: firstPath))
    try Self.pixelPNG.write(to: URL(fileURLWithPath: secondPath))
    try Self.pixelPNG.write(to: URL(fileURLWithPath: thirdPath))
    let cache = WidgetImageCache(capacity: 2)

    let first = try loadedImage(from: await cache.image(for: firstPath))
    let second = try loadedImage(from: await cache.image(for: secondPath))
    _ = await cache.image(for: firstPath)
    _ = await cache.image(for: thirdPath)
    let reloadedFirst = try loadedImage(from: await cache.image(for: firstPath))
    let reloadedSecond = try loadedImage(from: await cache.image(for: secondPath))

    XCTAssertTrue(first === reloadedFirst)
    XCTAssertFalse(second === reloadedSecond)
  }

  func testChangedModificationDateReloadsSamePath() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("changing.png")
    try Self.pixelPNG.write(to: url)
    let cache = WidgetImageCache()
    let first = try loadedImage(from: await cache.image(for: url.path))

    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: 10)],
      ofItemAtPath: url.path
    )
    let second = try loadedImage(from: await cache.image(for: url.path))

    XCTAssertFalse(first === second)
  }

  func testImageRevisionChangesWhenFileSizeChanges() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("changing.png")
    try Self.pixelPNG.write(to: url)
    let first = WidgetImageRevision(path: url.path)

    var enlarged = Self.pixelPNG
    enlarged.append(0)
    try enlarged.write(to: url)
    let second = WidgetImageRevision(path: url.path)

    XCTAssertNotEqual(first, second)
  }
}
