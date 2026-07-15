import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class LuaProcessControllerTerminationTests: XCTestCase, @unchecked Sendable {
  func testUnexpectedExitReportsExitCode() async throws {
    let scriptURL = try makeExecutableScript("exit 7")
    defer { try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent()) }

    let controller = LuaProcessController(
      logger: ProcessLogger(label: "lua.termination.tests", minimumLevel: .error)
    )
    let resources = LuaProcessController.LaunchResources()
    defer { close(resources) }

    let terminated = expectation(description: "unexpected termination delivered")
    let result = LockedState<LuaProcessController.Termination?>(nil)

    XCTAssertNotNil(
      controller.start(
        context: makeContext(executablePath: scriptURL.path),
        resources: resources,
        terminationHandler: { termination in
          result.withLock { $0 = termination }
          terminated.fulfill()
        }
      )
    )

    await fulfillment(of: [terminated], timeout: 2)

    let termination = try XCTUnwrap(result.withLock { $0 })
    XCTAssertEqual(termination.reason, .exited(code: 7))
    XCTAssertFalse(termination.wasRequested)
    XCTAssertNil(controller.processIdentifier)
  }

  func testShutdownMarksTerminationAsRequested() async throws {
    let scriptURL = try makeExecutableScript("while true; do sleep 1; done")
    defer { try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent()) }

    let controller = LuaProcessController(
      logger: ProcessLogger(label: "lua.termination.tests", minimumLevel: .error)
    )
    let resources = LuaProcessController.LaunchResources()
    defer { close(resources) }

    let terminated = expectation(description: "requested termination delivered")
    let result = LockedState<LuaProcessController.Termination?>(nil)

    XCTAssertNotNil(
      controller.start(
        context: makeContext(executablePath: scriptURL.path),
        resources: resources,
        terminationHandler: { termination in
          result.withLock { $0 = termination }
          terminated.fulfill()
        }
      )
    )

    await controller.shutdownAndWait()
    await fulfillment(of: [terminated], timeout: 2)

    let termination = try XCTUnwrap(result.withLock { $0 })
    XCTAssertTrue(termination.wasRequested)
    XCTAssertNil(controller.processIdentifier)
  }

  private func makeContext(executablePath: String) -> LuaProcessController.LaunchContext {
    LuaProcessController.LaunchContext(
      runtimeAgentPath: executablePath,
      runtimePath: "/tmp/runtime.lua",
      luaPath: "/usr/bin/lua",
      luaSocketPath: "/tmp/easybar-test.sock",
      widgetsPath: "/tmp/widgets",
      defaultCommandTimeoutSeconds: 5,
      defaultCommandMaxOutputBytes: 65_536,
      widgetFiles: [],
      environment: [:]
    )
  }

  private func makeExecutableScript(_ body: String) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-lua-termination-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    let scriptURL = directoryURL.appendingPathComponent("runtime-agent.sh")
    try "#!/bin/sh\n\(body)\n".write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )
    return scriptURL
  }

  private func close(_ resources: LuaProcessController.LaunchResources) {
    try? resources.error.fileHandleForReading.close()
    try? resources.error.fileHandleForWriting.close()
  }
}
