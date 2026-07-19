import XCTest

@testable import EasyBarApp

final class InboxContextMenuTests: XCTestCase {
  func testMenuReflectsConfiguration() throws {
    var config = Config.InboxBuiltinConfig.default
    config.groupBy = .severity
    config.sortBy = .title
    config.showUnreadCount = false

    let menu = try XCTUnwrap(WidgetContextMenuItem.validated(InboxContextMenu.make(config: config)))
    XCTAssertEqual(menu[0].submenu?.first(where: { $0.id == "inbox.group.severity" })?.checked, true)
    XCTAssertEqual(menu[1].submenu?.first(where: { $0.id == "inbox.sort.title" })?.checked, true)
    XCTAssertEqual(menu.first(where: { $0.id == "inbox.show_unread_count" })?.checked, false)
  }

  func testActionIdentifiersDecodeOnlySupportedValues() {
    XCTAssertEqual(InboxContextMenuAction(id: "inbox.group.date"), .setGroup(.date))
    XCTAssertEqual(InboxContextMenuAction(id: "inbox.sort.source"), .setSort(.source))
    XCTAssertEqual(InboxContextMenuAction(id: "inbox.sort_descending"), .toggleDescending)
    XCTAssertEqual(InboxContextMenuAction(id: "inbox.show_unread_count"), .toggleUnreadCount)
    XCTAssertNil(InboxContextMenuAction(id: "inbox.group.unknown"))
    XCTAssertNil(InboxContextMenuAction(id: "inbox.unknown"))
  }
}
