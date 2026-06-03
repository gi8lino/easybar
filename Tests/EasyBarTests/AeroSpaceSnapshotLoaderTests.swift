import XCTest

@testable import EasyBarApp

final class AeroSpaceSnapshotLoaderTests: XCTestCase {
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
    workspaceNames: String,
    workspaceState: String,
    windows: String = "",
    focusedWindow: String = "",
    focusedLayout: String = "",
    resolveAppID: (String, String?) -> String = { name, bundlePath in bundlePath ?? name }
  ) -> AeroSpaceSnapshot {
    AeroSpaceSnapshotLoader.load(
      run: { arguments in
        switch arguments {
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
