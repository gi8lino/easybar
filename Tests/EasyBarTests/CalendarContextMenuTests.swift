import EasyBarCalendarConfig
import XCTest

@testable import EasyBarApp

final class CalendarContextMenuTests: XCTestCase {
  func testMenuReflectsEffectiveCalendarOptions() throws {
    var config = CalendarBuiltinConfig.default
    config.popupMode = .upcoming
    config.anchor.layout = .column
    config.anchor.fields = [.time]
    config.appointments.showLocation = false

    let menu = CalendarContextMenu.make(config: config)
    let validated = try XCTUnwrap(WidgetContextMenuItem.validated(menu))
    let popupItems = try XCTUnwrap(validated.first?.submenu)
    let layoutItems = try XCTUnwrap(validated.dropFirst().first?.submenu)
    let anchorItems = try XCTUnwrap(validated.dropFirst(2).first?.submenu)
    let appointmentItems = try XCTUnwrap(validated.dropFirst(3).first?.submenu)

    XCTAssertEqual(
      popupItems.first(where: { $0.id == "calendar.popup.upcoming" })?.checked,
      true
    )
    XCTAssertEqual(
      layoutItems.first(where: { $0.id == "calendar.layout.column" })?.checked,
      true
    )
    XCTAssertEqual(
      anchorItems.first(where: { $0.id == "calendar.anchor_field.time" })?.enabled,
      false
    )
    XCTAssertEqual(
      appointmentItems.first(where: { $0.id == "calendar.appointment.location" })?.checked,
      false
    )
  }

  func testActionIdentifiersRejectUnknownOptions() {
    XCTAssertEqual(
      CalendarContextMenuAction(id: "calendar.popup.month"),
      .setPopupMode(.month)
    )
    XCTAssertEqual(
      CalendarContextMenuAction(id: "calendar.layout.row"),
      .setAnchorLayout(.row)
    )
    XCTAssertEqual(
      CalendarContextMenuAction(id: "calendar.anchor_field.date"),
      .toggleAnchorField(.date)
    )
    XCTAssertEqual(
      CalendarContextMenuAction(id: "calendar.appointment.location"),
      .toggleAppointmentOption("location")
    )
    XCTAssertEqual(CalendarContextMenuAction(id: "calendar.refresh"), .refresh)
    XCTAssertNil(CalendarContextMenuAction(id: "calendar.save_to_config"))
    XCTAssertNil(CalendarContextMenuAction(id: "calendar.appointment.unknown"))
    XCTAssertNil(CalendarContextMenuAction(id: "calendar.unknown"))
  }

  @MainActor
  func testSnapshotStoreAppliesOnlyCalendarSessionOverride() {
    let original = Config.makeUnloadedConfig().snapshot()
    let store = ConfigSnapshotStore(snapshot: original)
    var calendar = original.builtins.calendar
    calendar.popupMode = .none

    store.applyCalendarSessionOverride(calendar)

    XCTAssertEqual(store.snapshot.builtins.calendar.popupMode, .none)
    XCTAssertEqual(store.snapshot.builtins.wifi.mode, original.builtins.wifi.mode)
    XCTAssertEqual(store.snapshot.theme.name, original.theme.name)
  }
}
