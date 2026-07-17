import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class LuaWidgetLibraryTests: LuaRenderRuntimeTestCase, @unchecked Sendable {
  func testWidgetCanRequireDirectAndPackageModulesFromLibDirectory() async throws {
    let widgets = try makeWidgetsDirectory()
    let library = widgets.appendingPathComponent("lib", isDirectory: true)
    let packageDirectory = library.appendingPathComponent("format", isDirectory: true)
    try FileManager.default.createDirectory(
      at: packageDirectory,
      withIntermediateDirectories: true
    )

    try "return { value = 'direct' }\n".write(
      to: library.appendingPathComponent("direct.lua"),
      atomically: true,
      encoding: .utf8
    )
    try "return { value = 'package' }\n".write(
      to: packageDirectory.appendingPathComponent("init.lua"),
      atomically: true,
      encoding: .utf8
    )

    let node = try await renderWidget(
      """
      local direct = require("direct")
      local format = require("format")

      easybar.add("item", "module_test", {
        label = direct.value .. ":" .. format.value,
      })
      """,
      rootID: "module_test",
      in: widgets
    )

    XCTAssertEqual(node.text, "direct:package")
  }

  func testWidgetLibraryModulesAreCachedByRequire() async throws {
    let widgets = try makeWidgetsDirectory()
    let library = widgets.appendingPathComponent("lib", isDirectory: true)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)

    try "return { token = {} }\n".write(
      to: library.appendingPathComponent("cached.lua"),
      atomically: true,
      encoding: .utf8
    )

    let node = try await renderWidget(
      """
      local first = require("cached")
      local second = require("cached")
      easybar.add("item", "cache_test", { label = tostring(first == second) })
      """,
      rootID: "cache_test",
      in: widgets
    )

    XCTAssertEqual(node.text, "true")
  }

  func testWidgetDiscoveryIgnoresLuaModulesBelowLibDirectory() throws {
    let widgets = try makeWidgetsDirectory()
    let library = widgets.appendingPathComponent("lib", isDirectory: true)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    try "return {}\n".write(
      to: library.appendingPathComponent("helper.lua"),
      atomically: true,
      encoding: .utf8
    )
    try "return nil\n".write(
      to: widgets.appendingPathComponent("widget.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(label: "lua.widget-library.test", minimumLevel: .error)
    let controller = LuaProcessController(logger: logger)

    XCTAssertEqual(controller.resolvedWidgetFiles(in: widgets.path), ["widget.lua"])
  }

  private func renderWidget(
    _ source: String,
    rootID: String,
    in widgetsDirectoryURL: URL
  ) async throws -> WidgetNodeState {
    let widgetFile = "widget.lua"
    try source.write(
      to: widgetsDirectoryURL.appendingPathComponent(widgetFile),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(label: "lua.widget-library.test", minimumLevel: .error)
    let controller = LuaProcessController(logger: logger)
    let runtimePath = try XCTUnwrap(controller.resolvedRuntimePath())
    let recorder = RuntimeUpdateRecorder()
    let runtime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: widgetFile,
      recorder: recorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: true
    )
    defer { runtime.stop() }

    let update = try await nextTreeUpdate(from: recorder) { update in
      update.treePayload?.nodes.contains(where: { $0.id == rootID }) == true
    }

    return try XCTUnwrap(update.treePayload?.nodes.first(where: { $0.id == rootID }))
  }
}
