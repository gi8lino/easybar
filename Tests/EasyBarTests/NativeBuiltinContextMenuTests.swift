import XCTest

@testable import EasyBarApp

final class NativeBuiltinContextMenuTests: XCTestCase {
  func testVolumeMenuReflectsMuteAndConfiguration() throws {
    var config = Config.VolumeBuiltinConfig.default
    config.showPercentage = false
    config.expandToSliderOnHover = true

    let menu = try XCTUnwrap(
      WidgetContextMenuItem.validated(
        VolumeContextMenu.make(config: config, isMuted: true)
      )
    )

    XCTAssertEqual(menu.first?.title, "Unmute")
    XCTAssertEqual(
      menu.first(where: { $0.id == "volume.toggle_show_percentage" })?.checked,
      false
    )
    XCTAssertEqual(
      menu.first(where: { $0.id == "volume.toggle_expand_on_hover" })?.checked,
      true
    )
  }

  func testVolumeActionsDecodeOnlySupportedValues() {
    XCTAssertEqual(VolumeContextMenuAction(id: "volume.toggle_mute"), .toggleMute)
    XCTAssertEqual(
      VolumeContextMenuAction(id: "volume.toggle_show_percentage"),
      .toggleShowPercentage
    )
    XCTAssertEqual(
      VolumeContextMenuAction(id: "volume.toggle_expand_on_hover"),
      .toggleExpandOnHover
    )
    XCTAssertEqual(
      VolumeContextMenuAction(id: "volume.open_sound_settings"),
      .openSoundSettings
    )
    XCTAssertNil(VolumeContextMenuAction(id: "volume.unknown"))
  }

  func testCPUMenuReflectsHistoryAndInterval() throws {
    var config = Config.CPUBuiltinConfig.default
    config.historySize = 30
    config.sampleIntervalSeconds = 5

    let menu = try XCTUnwrap(WidgetContextMenuItem.validated(CPUContextMenu.make(config: config)))
    let historyItems = try XCTUnwrap(menu.first(where: { $0.title == "History" })?.submenu)
    let intervalItems = try XCTUnwrap(
      menu.first(where: { $0.title == "Refresh Interval" })?.submenu
    )

    XCTAssertEqual(historyItems.first(where: { $0.id == "cpu.history.30" })?.checked, true)
    XCTAssertEqual(intervalItems.first(where: { $0.id == "cpu.interval.5" })?.checked, true)
  }

  func testCPUActionsRejectUnsupportedPresetValues() {
    XCTAssertEqual(CPUContextMenuAction(id: "cpu.history.60"), .setHistorySize(60))
    XCTAssertEqual(CPUContextMenuAction(id: "cpu.interval.2"), .setSampleInterval(2))
    XCTAssertEqual(CPUContextMenuAction(id: "cpu.reset_history"), .resetHistory)
    XCTAssertEqual(
      CPUContextMenuAction(id: "cpu.open_activity_monitor"),
      .openActivityMonitor
    )
    XCTAssertNil(CPUContextMenuAction(id: "cpu.history.20"))
    XCTAssertNil(CPUContextMenuAction(id: "cpu.interval.3"))
  }

  func testAeroSpaceModeMenuReflectsLayoutAndKeepsVisibleContent() throws {
    var config = Config.AeroSpaceModeBuiltinConfig.default
    config.showIcon = true
    config.showText = false

    let menu = try XCTUnwrap(
      WidgetContextMenuItem.validated(
        AeroSpaceModeContextMenu.make(config: config, currentLayout: .vAccordion)
      )
    )
    let layoutItems = try XCTUnwrap(menu.first?.submenu)

    XCTAssertEqual(
      layoutItems.first(where: { $0.id == "aerospace_mode.layout.v_accordion" })?.checked,
      true
    )
    XCTAssertEqual(
      menu.first(where: { $0.id == "aerospace_mode.toggle_show_icon" })?.enabled,
      false
    )
    XCTAssertEqual(
      menu.first(where: { $0.id == "aerospace_mode.toggle_show_text" })?.enabled,
      true
    )
  }

  func testAeroSpaceModeActionsRejectUnknownLayout() {
    XCTAssertEqual(
      AeroSpaceModeContextMenuAction(id: "aerospace_mode.layout.h_tiles"),
      .setLayout(.hTiles)
    )
    XCTAssertEqual(
      AeroSpaceModeContextMenuAction(id: "aerospace_mode.open_config"),
      .openConfig
    )
    XCTAssertNil(AeroSpaceModeContextMenuAction(id: "aerospace_mode.layout.unknown"))
    XCTAssertNil(AeroSpaceModeContextMenuAction(id: "aerospace_mode.layout.grid"))
  }

  func testFrontAppMenuDisablesRemovingLastVisibleField() throws {
    var config = Config.FrontAppBuiltinConfig.default
    config.showIcon = false
    config.showName = true

    let menu = try XCTUnwrap(
      WidgetContextMenuItem.validated(
        FrontAppContextMenu.make(
          config: config,
          hasFocusedApp: false,
          canRevealFocusedApp: false
        )
      )
    )

    XCTAssertEqual(menu.first(where: { $0.id == "front_app.hide" })?.enabled, false)
    XCTAssertEqual(
      menu.first(where: { $0.id == "front_app.toggle_show_icon" })?.enabled,
      true
    )
    XCTAssertEqual(
      menu.first(where: { $0.id == "front_app.toggle_show_name" })?.enabled,
      false
    )
    XCTAssertEqual(
      menu.first(where: { $0.id == "front_app.reveal_in_finder" })?.enabled,
      false
    )
  }

  @MainActor
  func testSnapshotStoreAppliesNewWidgetOverridesIndependently() {
    let original = Config.makeUnloadedConfig().snapshot()
    let store = ConfigSnapshotStore(snapshot: original)

    var cpu = original.builtins.cpu
    cpu.historySize = 60
    store.applyCPUOverride(cpu)
    XCTAssertEqual(store.snapshot.builtins.cpu.historySize, 60)
    XCTAssertEqual(
      store.snapshot.builtins.volume.showPercentage, original.builtins.volume.showPercentage)

    var volume = original.builtins.volume
    volume.showPercentage = false
    store.applyVolumeOverride(volume)
    XCTAssertEqual(store.snapshot.builtins.volume.showPercentage, false)
    XCTAssertEqual(store.snapshot.builtins.cpu.historySize, 60)

    var frontApp = original.builtins.frontApp
    frontApp.showName = false
    store.applyFrontAppOverride(frontApp)
    XCTAssertEqual(store.snapshot.builtins.frontApp.showName, false)
    XCTAssertEqual(
      store.snapshot.builtins.aerospaceMode.showText, original.builtins.aerospaceMode.showText)

    var mode = original.builtins.aerospaceMode
    mode.showText = true
    store.applyAeroSpaceModeOverride(mode)
    XCTAssertEqual(store.snapshot.builtins.aerospaceMode.showText, true)
    XCTAssertEqual(store.snapshot.builtins.frontApp.showName, false)
  }
}
