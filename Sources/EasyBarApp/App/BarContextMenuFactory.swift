import AppKit
import EasyBarShared

/// Runtime actions exposed by the bar context menu.
@MainActor
struct BarContextMenuActions {
  /// Refreshes visible runtime state without reloading config.
  let refresh: () -> Void
  /// Reloads the runtime configuration.
  let reloadConfig: () -> Void
  /// Restarts only the Lua widget runtime.
  let restartLuaRuntime: () -> Void
  /// Persists a theme selection to the active configuration.
  let selectTheme: (String?) -> Void
  /// Persists the enabled state of one native widget.
  let setNativeWidgetEnabled: (String, Bool) -> Void
}

/// Builds the right-click context menu shown by the bar panel.
@MainActor
final class BarContextMenuFactory: NSObject {
  /// Logger used for menu diagnostics and log-level updates.
  private let logger: ProcessLogger
  /// Store that exposes the active immutable config snapshot.
  private let configStore: ConfigSnapshotStore
  /// Runtime actions forwarded to the app controller.
  private let actions: BarContextMenuActions
  /// State provider for dynamic menu labels.
  private let stateProvider: BarContextMenuStateProvider

  /// Creates a context menu factory for the current app services.
  init(
    logger: ProcessLogger,
    configStore: ConfigSnapshotStore,
    actions: BarContextMenuActions,
    stateProvider: BarContextMenuStateProvider
  ) {
    self.logger = logger
    self.configStore = configStore
    self.actions = actions
    self.stateProvider = stateProvider
    super.init()
  }

  /// Builds the right-click menu for the bar.
  func makeMenu(showDeveloperSection: Bool) -> NSMenu {
    let menu = NSMenu()

    appendItems([versionItem("EasyBar \(BuildInfo.appVersion)")], to: menu)
    appendSection(runtimeMenuItems, to: menu)
    appendSection([nativeWidgetsMenuItem()], to: menu)
    appendSection([themeMenuItem()], to: menu)
    appendSection(openMenuItems, to: menu)
    appendItems(agentMenuItems, to: menu)

    if shouldShowDeveloperSection(showDeveloperSection) {
      menu.addItem(.separator())
      appendItems(developerMenuItems, to: menu)
    }

    return menu
  }

  /// Returns whether the developer section should be visible.
  private func shouldShowDeveloperSection(_ shiftRequested: Bool) -> Bool {
    return configStore.snapshot.app.develop || shiftRequested
  }

  /// Creates the submenu used to enable or disable top-level native widgets.
  private func nativeWidgetsMenuItem() -> NSMenuItem {
    let builtins = configStore.snapshot.builtins
    let widgets: [(key: String, title: String, enabled: Bool)] = [
      ("spaces", "Spaces", builtins.spaces.enabled),
      ("inbox", "Inbox", builtins.inbox.enabled),
      ("battery", "Battery", builtins.battery.enabled),
      ("wifi", "Wi-Fi", builtins.wifi.enabled),
      ("calendar", "Calendar", builtins.calendar.enabled),
      ("volume", "Volume", builtins.volume.enabled),
      ("front_app", "Front App", builtins.frontApp.enabled),
      ("aerospace_mode", "AeroSpace Mode", builtins.aerospaceMode.enabled),
      ("cpu", "CPU", builtins.cpu.enabled),
      ("time", "Time", builtins.time.placement.enabled),
      ("date", "Date", builtins.date.placement.enabled),
    ]
    let item = NSMenuItem(title: "Native Widgets", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Native Widgets")
    for widget in widgets {
      let toggle = actionItem(title: widget.title, action: #selector(toggleNativeWidget(_:)))
      toggle.representedObject = widget.key
      toggle.state = widget.enabled ? .on : .off
      submenu.addItem(toggle)
    }
    item.submenu = submenu
    return item
  }

  /// Returns the runtime control menu items.
  private var runtimeMenuItems: [NSMenuItem] {
    [
      actionItem(
        title: "Refresh",
        action: #selector(refresh(_:)),
        toolTip:
          "Refreshes visible widgets and runtime data without reloading configuration or restarting Lua."
      ),
      actionItem(
        title: "Reload Config",
        action: #selector(reloadConfig(_:)),
        toolTip:
          "Reloads config.toml, rebuilds EasyBar state, and reconnects agent-backed subscriptions."
      ),
      actionItem(
        title: "Restart Lua Runtime",
        action: #selector(restartLuaRuntime(_:)),
        toolTip:
          "Stops and starts the Lua widget runtime, reloads all Lua widget files, and resets Lua widget state."
      ),
    ]
  }

  /// Returns the config and widgets folder menu items.
  private var openMenuItems: [NSMenuItem] {
    [
      actionItem(title: "Open Config", action: #selector(openConfig(_:))),
      actionItem(title: "Open Widgets Folder", action: #selector(openWidgetsFolder(_:))),
    ]
  }

  /// Creates the live theme-preview submenu.
  private func themeMenuItem() -> NSMenuItem {
    let snapshot = configStore.snapshot
    let item = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Theme")

    for name in ThemeCatalog.availableThemeNames(for: snapshot, logger: logger) {
      let theme = actionItem(title: name, action: #selector(selectTheme(_:)))
      theme.representedObject = name
      theme.state = snapshot.theme.name == name ? .on : .off
      submenu.addItem(theme)
    }

    item.submenu = submenu
    return item
  }

  /// Returns the developer-only menu items.
  private var developerMenuItems: [NSMenuItem] {
    [
      logLevelMenuItem(),
      actionItem(title: "Open Log Folder", action: #selector(openLogFolder(_:))),
    ]
  }

  /// Returns the per-agent status menu items.
  private var agentMenuItems: [NSMenuItem] {
    [
      calendarAgentMenuItem,
      networkAgentMenuItem,
    ]
  }

  /// Returns the calendar agent status submenu item.
  private var calendarAgentMenuItem: NSMenuItem {
    agentMenuItem(
      title: "Calendar Agent",
      status: connectionLabel(stateProvider.calendarAgentConnected),
      permission: stateProvider.calendarPermissionLabel,
      settingsAction: #selector(openCalendarSettings(_:)),
      settingsTitle: "Open Calendar Settings"
    )
  }

  /// Returns the network agent status submenu item.
  private var networkAgentMenuItem: NSMenuItem {
    agentMenuItem(
      title: "Network Agent",
      status: connectionLabel(stateProvider.networkAgentConnected),
      permission: stateProvider.wifiPermissionLabel,
      settingsAction: #selector(openLocationSettings(_:)),
      settingsTitle: "Open Location/Wi-Fi Settings"
    )
  }

  /// Appends one section of items and a trailing separator.
  private func appendSection(_ items: [NSMenuItem], to menu: NSMenu) {
    appendItems(items, to: menu)
    menu.addItem(.separator())
  }

  /// Appends one or more menu items in order.
  private func appendItems(_ items: [NSMenuItem], to menu: NSMenu) {
    for item in items {
      menu.addItem(item)
    }
  }

  /// Creates one enabled action item.
  private func actionItem(
    title: String,
    action: Selector,
    toolTip: String? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    item.toolTip = toolTip
    return item
  }

  /// Creates one agent submenu item with status, permission, and settings actions.
  private func agentMenuItem(
    title: String,
    status: String,
    permission: String,
    settingsAction: Selector,
    settingsTitle: String
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: title)
    submenu.addItem(readOnlyItem("Status: \(status)"))
    submenu.addItem(readOnlyItem("Permission: \(permission)"))
    submenu.addItem(.separator())
    submenu.addItem(actionItem(title: settingsTitle, action: settingsAction))
    item.submenu = submenu
    return item
  }

  /// Creates the developer log-level submenu.
  private func logLevelMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: "Log Level", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Log Level")

    for level in ProcessLogLevel.allCases {
      let levelItem = NSMenuItem(
        title: level.rawValue.capitalized,
        action: #selector(setLogLevel(_:)),
        keyEquivalent: ""
      )
      levelItem.target = self
      levelItem.representedObject = level.rawValue
      levelItem.state = logger.minimumLevel == level ? .on : .off
      submenu.addItem(levelItem)
    }

    item.submenu = submenu
    return item
  }

  /// Creates one readable non-destructive status row.
  private func readOnlyItem(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title,
      attributes: [.foregroundColor: NSColor.secondaryLabelColor]
    )
    return item
  }

  /// Creates one inactive version row for the top of the menu.
  private func versionItem(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title,
      attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
    )
    return item
  }

  /// Returns a human-readable connected/disconnected label.
  private func connectionLabel(_ connected: Bool) -> String {
    return connected ? "Connected" : "Disconnected"
  }

  /// Refreshes the current runtime through the app layer.
  @objc private func refresh(_ sender: Any?) {
    actions.refresh()
  }

  /// Reloads the app config through the app layer.
  @objc private func reloadConfig(_ sender: Any?) {
    actions.reloadConfig()
  }

  /// Restarts only the Lua runtime through the app layer.
  @objc private func restartLuaRuntime(_ sender: Any?) {
    actions.restartLuaRuntime()
  }

  @objc private func selectTheme(_ sender: NSMenuItem) {
    guard let name = sender.representedObject as? String else { return }
    actions.selectTheme(name)
  }

  /// Persists the inverse of the selected widget's current checked state.
  @objc private func toggleNativeWidget(_ sender: NSMenuItem) {
    guard let key = sender.representedObject as? String else { return }
    actions.setNativeWidgetEnabled(key, sender.state != .on)
  }

  /// Updates the runtime log level immediately.
  @objc private func setLogLevel(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let level = ProcessLogLevel(rawValue: rawValue)
    else {
      return
    }

    logger.setMinimumLevel(level)
    logger.info("runtime log level changed to \(level.rawValue)")
  }

  /// Opens the active config file in Finder/default app.
  @objc private func openConfig(_ sender: Any?) {
    let url = URL(fileURLWithPath: configStore.snapshot.app.configPath)
    NSWorkspace.shared.open(url)
  }

  /// Opens the configured widgets directory.
  @objc private func openWidgetsFolder(_ sender: Any?) {
    let url = URL(fileURLWithPath: configStore.snapshot.app.widgetsPath, isDirectory: true)
    NSWorkspace.shared.open(url)
  }

  /// Opens the configured log directory.
  @objc private func openLogFolder(_ sender: Any?) {
    let url = URL(fileURLWithPath: configStore.snapshot.logging.directory, isDirectory: true)
    NSWorkspace.shared.open(url)
  }

  /// Opens Calendar privacy settings so the user can grant access again.
  @objc private func openCalendarSettings(_ sender: Any?) {
    openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
  }

  /// Opens Location Services settings so the user can grant Wi-Fi access again.
  @objc private func openLocationSettings(_ sender: Any?) {
    openSettingsURL(
      "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
    )
  }

  /// Opens one System Settings deep link when available.
  private func openSettingsURL(_ value: String) {
    guard let url = URL(string: value) else { return }

    NSWorkspace.shared.open(url)
  }
}
