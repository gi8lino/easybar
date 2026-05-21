import XCTest

@testable import EasyBarApp

final class AeroSpaceSnapshotLoaderTests: XCTestCase {
  func testLoadKeepsEmptyWorkspacesInSnapshot() {
    let snapshot = AeroSpaceSnapshotLoader.load(
      run: { arguments in
        switch arguments {
        case ["list-workspaces", "--all", "--format", "%{workspace}"]:
          return "1\n2"
        case [
          "list-workspaces", "--all", "--format",
          "%{workspace} | %{workspace-is-focused} | %{workspace-is-visible}",
        ]:
          return "1 | true | true\n2 | false | false"
        case ["list-windows", "--all", "--format", "%{workspace} | %{app-name} | %{app-bundle-path}"]:
          return "1 | Safari | /Applications/Safari.app"
        case ["list-windows", "--focused", "--format", "%{app-bundle-path} | %{app-name}"]:
          return "/Applications/Safari.app | Safari"
        case ["list-windows", "--focused", "--format", "%{window-layout}"]:
          return "h_tiles"
        default:
          return nil
        }
      },
      resolveAppID: { name, bundlePath in bundlePath ?? name }
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Safari"])
    XCTAssertEqual(snapshot.spaces[1].apps, [])
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
    let snapshot = AeroSpaceSnapshotLoader.load(
      run: { arguments in
        switch arguments {
        case ["list-workspaces", "--all", "--format", "%{workspace}"]:
          return "Work Inbox\nDeep Focus"
        case [
          "list-workspaces", "--all", "--format",
          "%{workspace} | %{workspace-is-focused} | %{workspace-is-visible}",
        ]:
          return "Work Inbox | false | true\nDeep Focus | true | true"
        case ["list-windows", "--all", "--format", "%{workspace} | %{app-name} | %{app-bundle-path}"]:
          return ""
        case ["list-windows", "--focused", "--format", "%{app-bundle-path} | %{app-name}"]:
          return ""
        case ["list-windows", "--focused", "--format", "%{window-layout}"]:
          return "floating"
        default:
          return nil
        }
      },
      resolveAppID: { name, bundlePath in bundlePath ?? name }
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["Work Inbox", "Deep Focus"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [false, true])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, true])
  }
}
