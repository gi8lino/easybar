import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSnapshotLoaderTests: XCTestCase {
  func testLoadParsesJSONWorkspaceAndWindowOutput() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1", "workspace-is-focused": true, "workspace-is-visible": true},
          {"workspace": "2", "workspace-is-focused": false, "workspace-is-visible": false}
        ]
        """,
      jsonWindows:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app"
          }
        ]
        """,
      jsonFocusedWindow:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app",
            "window-layout": "h_tiles"
          }
        ]
        """
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [true, false])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, false])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Safari"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.bundlePath), ["/Applications/Safari.app"])
    XCTAssertEqual(snapshot.focusedApp?.name, "Safari")
    XCTAssertEqual(snapshot.focusedApp?.bundlePath, "/Applications/Safari.app")
    XCTAssertEqual(snapshot.focusedLayoutMode, .hTiles)
  }

  func testLoadParsesJSONWorkspacesWithoutFocusedFieldUsingTextState() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1", "workspace-is-visible": true},
          {"workspace": "2", "workspace-is-visible": false}
        ]
        """,
      jsonWindows: "[]",
      jsonFocusedWindow: "[]",
      workspaceState: "1 | true | true\n2 | false | false"
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [true, false])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, false])
  }

  func testLoadFallsBackToTextProviderWhenJSONFails() {
    var requestedArguments: [[String]] = []

    let snapshot = AeroSpaceSnapshotLoader.load(
      run: { arguments in
        requestedArguments.append(arguments)
        switch arguments {
        case ["list-workspaces", "--all", "--json"]:
          return nil
        case ["list-windows", "--all", "--json"]:
          return nil
        case ["list-windows", "--focused", "--json"]:
          return nil
        case ["list-workspaces", "--all", "--format", "%{workspace}"]:
          return "1"
        case [
          "list-workspaces", "--all", "--format",
          "%{workspace} | %{workspace-is-focused} | %{workspace-is-visible}",
        ]:
          return "1 | true | true"
        case ["list-windows", "--all", "--format", "%{workspace} | %{app-name} | %{app-bundle-path}"]:
          return "1 | Ghostty | /Applications/Ghostty.app"
        case ["list-windows", "--focused", "--format", "%{app-bundle-path} | %{app-name}"]:
          return "/Applications/Ghostty.app | Ghostty"
        case ["list-windows", "--focused", "--format", "%{window-layout}"]:
          return "floating"
        default:
          return nil
        }
      },
      resolveAppID: { name, bundlePath in bundlePath ?? name }
    )

    XCTAssertTrue(requestedArguments.contains(["list-workspaces", "--all", "--json"]))
    XCTAssertTrue(requestedArguments.contains(["list-workspaces", "--all", "--format", "%{workspace}"]))
    XCTAssertEqual(snapshot.spaces.map(\.name), ["1"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Ghostty"])
    XCTAssertEqual(snapshot.focusedApp?.name, "Ghostty")
    XCTAssertEqual(snapshot.focusedLayoutMode, .floating)
  }

  func testLoadKeepsEmptyWorkspacesInSnapshot() {
    let snapshot = loadSnapshot(
      workspaceNames: "1\n2",
      workspaceState: "1 | true | true\n2 | false | false",
      windows: "1 | Safari | /Applications/Safari.app",
      focusedWindow: "/Applications/Safari.app | Safari",
      focusedLayout: "h_tiles"
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Safari"])
    XCTAssertEqual(snapshot.spaces[1].apps, [])
    XCTAssertEqual(snapshot.focusedApp?.name, "Safari")
    XCTAssertEqual(snapshot.focusedApp?.bundlePath, "/Applications/Safari.app")
    XCTAssertEqual(snapshot.focusedLayoutMode, .hTiles)
  }

  func testVisibleSpacesRespectsHideEmptyConfiguration() {
    let spaces = [
      SpaceItem(id: "1", name: "1", isFocused: false, isVisible: false, apps: []),
      SpaceItem(id: "2", name: "2", isFocused: true, isVisible: true, apps: []),
      SpaceItem(
        id: "3",
        name: "3",
        isFocused: false,
        isVisible: false,
        apps: [SpaceApp(id: "mail", bundleID: "", name: "Mail", bundlePath: nil)]
      ),
    ]

    XCTAssertEqual(
      SpacesWidgetView.visibleSpaces(spaces, hideEmpty: false).map(\.name),
      ["1", "2", "3"]
    )
    XCTAssertEqual(
      SpacesWidgetView.visibleSpaces(spaces, hideEmpty: true).map(\.name),
      ["2", "3"]
    )
  }

  func testLoadParsesWorkspaceStateForNamesContainingSpaces() {
    let snapshot = loadSnapshot(
      workspaceNames: "Work Inbox\nDeep Focus",
      workspaceState: "Work Inbox | false | true\nDeep Focus | true | true",
      focusedLayout: "floating"
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["Work Inbox", "Deep Focus"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [false, true])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, true])
  }

  func testLoadDefaultsMissingWorkspaceStateToInactive() {
    let snapshot = loadSnapshot(
      workspaceNames: "1\n2",
      workspaceState: "1 | true | true"
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [true, false])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, false])
  }

  func testLoadDeduplicatesAppsByResolvedIdentity() {
    let snapshot = loadSnapshot(
      workspaceNames: "1",
      workspaceState: "1 | true | true",
      windows:
        "1 | Safari | /Applications/Safari.app\n"
        + "1 | Safari | /Applications/Safari.app\n"
        + "1 | Safari Technology Preview | /Applications/Safari Technology Preview.app"
    )

    XCTAssertEqual(
      snapshot.spaces[0].apps.map(\.name),
      ["Safari", "Safari Technology Preview"]
    )
    XCTAssertEqual(
      snapshot.spaces[0].apps.map(\.id),
      ["/Applications/Safari.app", "/Applications/Safari Technology Preview.app"]
    )
  }

  private func loadSnapshot(
    jsonWorkspaces: String? = nil,
    jsonWindows: String? = nil,
    jsonFocusedWindow: String? = nil,
    workspaceNames: String = "",
    workspaceState: String = "",
    windows: String = "",
    focusedWindow: String = "",
    focusedLayout: String = "",
    resolveAppID: (String, String?) -> String = { name, bundlePath in bundlePath ?? name }
  ) -> AeroSpaceSnapshot {
    AeroSpaceSnapshotLoader.load(
      run: { arguments in
        switch arguments {
        case ["list-workspaces", "--all", "--json"]:
          return jsonWorkspaces
        case ["list-windows", "--all", "--json"]:
          return jsonWindows
        case ["list-windows", "--focused", "--json"]:
          return jsonFocusedWindow
        case ["list-workspaces", "--all", "--format", "%{workspace}"]:
          return workspaceNames
        case [
          "list-workspaces", "--all", "--format",
          "%{workspace} | %{workspace-is-focused} | %{workspace-is-visible}",
        ]:
          return workspaceState
        case ["list-windows", "--all", "--format", "%{workspace} | %{app-name} | %{app-bundle-path}"]:
          return windows
        case ["list-windows", "--focused", "--format", "%{app-bundle-path} | %{app-name}"]:
          return focusedWindow
        case ["list-windows", "--focused", "--format", "%{window-layout}"]:
          return focusedLayout
        default:
          return nil
        }
      },
      resolveAppID: resolveAppID
    )
  }
}

final class AeroSpaceCommandRunnerTests: XCTestCase {
  func testRunLogsStderrWhenCommandExitsNonZero() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-aerospace-runner-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try """
    #!/bin/sh
    echo 'bad format token' >&2
    exit 2
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.commands",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    logger.configureFileLogging(enabled: true, path: logURL.path)
    defer { logger.configureFileLogging(enabled: false, path: "") }

    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )

    _ = runner.run(arguments: ["list-workspaces", "--all", "--format", "%{workspace}"])
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertTrue(output.contains("aerospace command exited"))
    XCTAssertTrue(output.contains("status=2"))
    XCTAssertTrue(output.contains(#"stderr="bad format token""#))
  }
}
