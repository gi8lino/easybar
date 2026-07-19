import XCTest

@testable import EasyBarApp

final class WiFiContextMenuTests: XCTestCase {
  func testMenuReflectsEffectiveModeAndFields() throws {
    var config = Config.WiFiBuiltinConfig.default
    config.mode = .details
    config.fields.ssid = true

    let menu = WiFiContextMenu.make(config: config, hasSessionOverrides: false)
    let validated = try XCTUnwrap(WidgetContextMenuItem.validated(menu))
    let modeItems = try XCTUnwrap(validated.first?.submenu)
    let fieldItems = try XCTUnwrap(validated.dropFirst().first?.submenu)

    XCTAssertEqual(modeItems.first(where: { $0.id == "wifi.mode.details" })?.checked, true)
    XCTAssertEqual(modeItems.first(where: { $0.id == "wifi.mode.icon" })?.checked, false)
    XCTAssertEqual(fieldItems.first(where: { $0.id == "wifi.field.ssid" })?.checked, true)
    XCTAssertEqual(
      validated.first(where: { $0.id == "wifi.reset_to_config" })?.enabled,
      false
    )
  }

  func testMenuEnablesResetWhenSessionOverridesExist() throws {
    let menu = WiFiContextMenu.make(
      config: .default,
      hasSessionOverrides: true
    )
    let validated = try XCTUnwrap(WidgetContextMenuItem.validated(menu))

    XCTAssertEqual(
      validated.first(where: { $0.id == "wifi.reset_to_config" })?.enabled,
      true
    )
  }

  func testActionIdentifiersDecodeOnlySupportedValues() {
    XCTAssertEqual(WiFiContextMenuAction(id: "wifi.mode.inline"), .setMode(.inline))
    XCTAssertEqual(WiFiContextMenuAction(id: "wifi.field.ssid"), .toggleField("ssid"))
    XCTAssertEqual(WiFiContextMenuAction(id: "wifi.refresh"), .refresh)
    XCTAssertEqual(
      WiFiContextMenuAction(id: "wifi.open_network_settings"),
      .openNetworkSettings
    )
    XCTAssertEqual(WiFiContextMenuAction(id: "wifi.reset_to_config"), .resetToConfig)
    XCTAssertNil(WiFiContextMenuAction(id: "wifi.field.unknown"))
    XCTAssertNil(WiFiContextMenuAction(id: "wifi.unknown"))
  }
}
