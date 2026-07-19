import AppKit
import EasyBarShared

/// Persistent menu-bar controller that remains available while the EasyBar runtime is stopped.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  enum RuntimeState: Equatable {
    case running
    case stopped
    case transitioning
  }

  var onStart: (() -> Void)?
  var onStop: (() -> Void)?
  var onRestart: (() -> Void)?
  var onRefresh: (() -> Void)?
  var onReloadConfig: (() -> Void)?
  var onRestartLuaRuntime: (() -> Void)?
  var onRestartCalendarAgent: (() -> Void)?
  var onRestartNetworkAgent: (() -> Void)?
  var onSelectTheme: ((String?) -> Void)?
  var onQuit: (() -> Void)?
  var runtimeState: () -> RuntimeState = { .stopped }

  private let configStore: ConfigSnapshotStore
  private let stateProvider: BarContextMenuStateProvider
  private let logger: ProcessLogger
  private let statusItem: NSStatusItem
  private let menu = NSMenu()

  init(
    configStore: ConfigSnapshotStore,
    stateProvider: BarContextMenuStateProvider,
    logger: ProcessLogger
  ) {
    self.configStore = configStore
    self.stateProvider = stateProvider
    self.logger = logger
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()

    menu.delegate = self
    statusItem.menu = menu

    if let button = statusItem.button {
      button.image = Self.menuBarImage()
      button.toolTip = "EasyBar"
    }
  }

  /// Loads the monochrome EasyBar logo and marks it for native menu-bar tinting.
  private static func menuBarImage() -> NSImage? {
    let image =
      AppResourceLocator.url(
        forResource: "easybar-menubar", withExtension: "svg", subdirectory: "Assets"
      )
      .flatMap(NSImage.init(contentsOf:))
      ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "EasyBar")

    image?.isTemplate = true
    image?.size = NSSize(width: 20, height: 20)
    image?.accessibilityDescription = "EasyBar"
    return image
  }

  func menuWillOpen(_ menu: NSMenu) {
    rebuildMenu()
  }

  /// Shows or removes the controller item from the macOS menu bar.
  func setVisible(_ isVisible: Bool) {
    statusItem.isVisible = isVisible
  }

  private func rebuildMenu() {
    menu.removeAllItems()

    let version = NSMenuItem(title: "EasyBar \(BuildInfo.appVersion)", action: nil, keyEquivalent: "")
    version.isEnabled = false
    menu.addItem(version)
    menu.addItem(.separator())

    switch runtimeState() {
    case .running:
      menu.addItem(actionItem("Stop EasyBar", #selector(stopEasyBar(_:))))
      menu.addItem(actionItem("Restart EasyBar", #selector(restartEasyBar(_:))))
    case .stopped:
      menu.addItem(actionItem("Start EasyBar", #selector(startEasyBar(_:))))
    case .transitioning:
      let item = NSMenuItem(title: "Updating EasyBar…", action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    }

    let runtimeEnabled = runtimeState() == .running
    menu.addItem(runtimeActionItem("Refresh", #selector(refresh(_:)), enabled: runtimeEnabled))
    menu.addItem(runtimeActionItem("Reload Config", #selector(reloadConfig(_:)), enabled: runtimeEnabled))
    menu.addItem(
      runtimeActionItem(
        "Restart Lua Runtime", #selector(restartLuaRuntime(_:)), enabled: runtimeEnabled
      )
    )
    menu.addItem(.separator())
    menu.addItem(themeMenuItem(enabled: runtimeEnabled))
    menu.addItem(.separator())
    menu.addItem(
      agentItem(
        "Calendar Agent",
        connected: stateProvider.calendarAgentConnected,
        restartAction: #selector(restartCalendarAgent(_:))
      )
    )
    menu.addItem(
      agentItem(
        "Network Agent",
        connected: stateProvider.networkAgentConnected,
        restartAction: #selector(restartNetworkAgent(_:))
      )
    )
    menu.addItem(.separator())
    menu.addItem(actionItem("Open Config", #selector(openConfig(_:))))
    menu.addItem(actionItem("Open Widgets Folder", #selector(openWidgetsFolder(_:))))
    menu.addItem(actionItem("Open Log Folder", #selector(openLogFolder(_:))))
    menu.addItem(.separator())
    menu.addItem(actionItem("Quit Completely", #selector(quitCompletely(_:))))
  }

  private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  private func runtimeActionItem(_ title: String, _ action: Selector, enabled: Bool) -> NSMenuItem {
    let item = actionItem(title, action)
    item.isEnabled = enabled
    return item
  }

  private func agentItem(_ title: String, connected: Bool, restartAction: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: title)
    let status = NSMenuItem(
      title: "Status: \(connected ? "Connected" : "Disconnected")",
      action: nil,
      keyEquivalent: ""
    )
    status.isEnabled = false
    submenu.addItem(status)
    submenu.addItem(.separator())
    let restart = actionItem("Restart Agent", restartAction)
    restart.isEnabled = connected
    submenu.addItem(restart)
    item.submenu = submenu
    return item
  }

  private func themeMenuItem(enabled: Bool) -> NSMenuItem {
    let snapshot = configStore.snapshot
    let item = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
    item.isEnabled = enabled
    let submenu = NSMenu(title: "Theme")

    let configured = actionItem(
      "Use Configured Theme (\(snapshot.theme.configuredName))",
      #selector(selectConfiguredTheme(_:))
    )
    configured.state = snapshot.theme.sessionOverrideName == nil ? .on : .off
    submenu.addItem(configured)
    submenu.addItem(.separator())

    for name in ThemeCatalog.availableThemeNames(for: snapshot, logger: logger) {
      let theme = actionItem(name, #selector(selectTheme(_:)))
      theme.representedObject = name
      theme.state = snapshot.theme.name == name ? .on : .off
      submenu.addItem(theme)
    }

    item.submenu = submenu
    return item
  }

  @objc private func startEasyBar(_ sender: Any?) { onStart?() }
  @objc private func stopEasyBar(_ sender: Any?) { onStop?() }
  @objc private func restartEasyBar(_ sender: Any?) { onRestart?() }
  @objc private func refresh(_ sender: Any?) { onRefresh?() }
  @objc private func reloadConfig(_ sender: Any?) { onReloadConfig?() }
  @objc private func restartLuaRuntime(_ sender: Any?) { onRestartLuaRuntime?() }
  @objc private func restartCalendarAgent(_ sender: Any?) { onRestartCalendarAgent?() }
  @objc private func restartNetworkAgent(_ sender: Any?) { onRestartNetworkAgent?() }
  @objc private func selectConfiguredTheme(_ sender: Any?) { onSelectTheme?(nil) }
  @objc private func selectTheme(_ sender: NSMenuItem) {
    guard let name = sender.representedObject as? String else { return }
    onSelectTheme?(name)
  }
  @objc private func quitCompletely(_ sender: Any?) { onQuit?() }

  @objc private func openConfig(_ sender: Any?) {
    NSWorkspace.shared.open(URL(fileURLWithPath: configStore.snapshot.app.configPath))
  }

  @objc private func openWidgetsFolder(_ sender: Any?) {
    NSWorkspace.shared.open(
      URL(fileURLWithPath: configStore.snapshot.app.widgetsPath, isDirectory: true)
    )
  }

  @objc private func openLogFolder(_ sender: Any?) {
    NSWorkspace.shared.open(
      URL(fileURLWithPath: configStore.snapshot.logging.directory, isDirectory: true)
    )
  }
}
