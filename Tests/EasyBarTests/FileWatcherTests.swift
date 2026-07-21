import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class FileWatcherTests: XCTestCase {
  /// Verifies that repeated atomic saves remain visible after each inode replacement.
  func testObservesMultipleAtomicFileReplacements() async throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let configURL = directoryURL.appendingPathComponent("config.toml")
    try "value = 0\n".write(to: configURL, atomically: true, encoding: .utf8)

    let watcher = makeWatcher()
    let stream = await watcher.start(configPath: configURL.path, enabled: true)
    let observed = expectation(description: "observed all atomic replacements")
    observed.expectedFulfillmentCount = 3

    let consumer = Task {
      var count = 0
      for await event in stream {
        guard case .changed = event else { continue }
        count += 1
        observed.fulfill()
        if count == 3 { break }
      }
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    for value in 1...3 {
      try "value = \(value)\n".write(to: configURL, atomically: true, encoding: .utf8)
      try await Task.sleep(nanoseconds: 400_000_000)
    }

    await fulfillment(of: [observed], timeout: 3)
    await watcher.stop()
    consumer.cancel()
  }

  /// Verifies that a missing config can be created and then atomically replaced.
  func testMovesFromParentDirectoryWatchToCreatedConfigFile() async throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let configURL = directoryURL.appendingPathComponent("config.toml")
    let watcher = makeWatcher()
    let stream = await watcher.start(configPath: configURL.path, enabled: true)
    let observed = expectation(description: "observed creation and replacement")
    observed.expectedFulfillmentCount = 2

    let consumer = Task {
      var count = 0
      for await event in stream {
        guard case .changed = event else { continue }
        count += 1
        observed.fulfill()
        if count == 2 { break }
      }
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    try "value = 1\n".write(to: configURL, atomically: true, encoding: .utf8)
    try await Task.sleep(nanoseconds: 400_000_000)
    try "value = 2\n".write(to: configURL, atomically: true, encoding: .utf8)

    await fulfillment(of: [observed], timeout: 3)
    await watcher.stop()
    consumer.cancel()
  }

  /// Verifies that stopping the actor finishes the active event stream.
  func testStopFinishesActiveStream() async throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let configURL = directoryURL.appendingPathComponent("config.toml")
    try "value = 0\n".write(to: configURL, atomically: true, encoding: .utf8)

    let watcher = makeWatcher()
    let stream = await watcher.start(configPath: configURL.path, enabled: true)
    let finished = expectation(description: "stream finished")

    let consumer = Task {
      for await _ in stream {}
      finished.fulfill()
    }

    try await Task.sleep(nanoseconds: 50_000_000)
    await watcher.stop()

    await fulfillment(of: [finished], timeout: 1)
    consumer.cancel()
  }

  private func makeWatcher() -> FileWatcher {
    FileWatcher(
      logger: ProcessLogger(
        label: "file-watcher.tests",
        minimumLevel: .error,
        outputStream: nil,
        errorStream: nil
      )
    )
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-file-watcher-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
