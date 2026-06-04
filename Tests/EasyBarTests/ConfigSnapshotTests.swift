import XCTest

@testable import EasyBarApp

final class ConfigSnapshotTests: XCTestCase {
  private var originalSnapshot: ConfigSnapshot!

  /// Handles set up with error.
  override func setUpWithError() throws {
    try super.setUpWithError()
    originalSnapshot = Config.makeUnloadedConfig().snapshot()
  }

  /// Handles tear down with error.
  override func tearDownWithError() throws {
    Config.makeUnloadedConfig().apply(originalSnapshot)
    try super.tearDownWithError()
  }

  /// Handles test apply restores app bar and builtin state from snapshot.
  func testApplyRestoresAppBarAndBuiltinStateFromSnapshot() {
    let config = Config.makeUnloadedConfig()

    config.widgetsPath = "/tmp/widgets-before"
    config.loggingLevel = .debug
    config.barHeight = 41
    config.barBackgroundHex = "#112233"
    config.builtinTime.enabled = true
    config.builtinTime.position = .left
    config.builtinTime.format = "HH:mm:ss"
    config.builtinCPU.enabled = true
    config.builtinCPU.historySize = 18

    let snapshot = config.snapshot()

    config.widgetsPath = "/tmp/widgets-after"
    config.loggingLevel = .error
    config.barHeight = 22
    config.barBackgroundHex = "#abcdef"
    config.builtinTime.enabled = false
    config.builtinTime.position = .right
    config.builtinTime.format = "mm"
    config.builtinCPU.enabled = false
    config.builtinCPU.historySize = 4

    config.apply(snapshot)

    XCTAssertEqual(config.widgetsPath, "/tmp/widgets-before")
    XCTAssertEqual(config.loggingLevel, .debug)
    XCTAssertEqual(config.barHeight, 41)
    XCTAssertEqual(config.barBackgroundHex, "#112233")
    XCTAssertTrue(config.builtinTime.enabled)
    XCTAssertEqual(config.builtinTime.position, .left)
    XCTAssertEqual(config.builtinTime.format, "HH:mm:ss")
    XCTAssertTrue(config.builtinCPU.enabled)
    XCTAssertEqual(config.builtinCPU.historySize, 18)
  }
}
