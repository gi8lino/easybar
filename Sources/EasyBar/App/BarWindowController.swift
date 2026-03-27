import AppKit
import SwiftUI

/// Hosts the top-level borderless bar window.
final class BarWindowController: NSWindowController {
  var onReloadConfig: (() -> Void)?
  var onRestartLuaRuntime: (() -> Void)?

  /// Creates a borderless bar window pinned to the top of the screen.
  init() {
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let frame = Self.makeFrame(for: screen)
    Logger.info("bar window initial target_frame=\(NSStringFromRect(frame))")

    let contentView = BarRootView()

    let window = BarPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    window.level = .statusBar
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.hidesOnDeactivate = false
    window.isFloatingPanel = true
    window.becomesKeyOnlyIfNeeded = false
    window.isMovable = false
    window.isMovableByWindowBackground = false
    window.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .fullScreenAuxiliary,
      .ignoresCycle,
    ]
    window.setContentSize(frame.size)
    window.minSize = frame.size
    window.maxSize = frame.size

    let hostingView = BarHostingView(rootView: contentView)
    hostingView.frame = NSRect(origin: .zero, size: frame.size)
    hostingView.autoresizingMask = [.width, .height]
    window.contentView = hostingView
    window.setFrame(frame, display: false)

    super.init(window: window)

    window.contextMenuProvider = { [weak self] in
      self?.makeContextMenu() ?? NSMenu()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  /// Reapplies the configured frame after a config reload.
  func reloadLayout() {
    guard let window else { return }

    let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
    let frame = Self.makeFrame(for: screen)

    window.setFrame(frame, display: true)
    window.setContentSize(frame.size)
    window.minSize = frame.size
    window.maxSize = frame.size
    window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
    Logger.info("bar window reloaded frame=\(NSStringFromRect(window.frame))")
  }

  /// Shows the panel without asking AppKit to make it key.
  func present() {
    guard let window else { return }

    window.setFrame(window.frame, display: true)
    window.orderFrontRegardless()
    Logger.info(
      "bar window presented frame=\(NSStringFromRect(window.frame)) level=\(window.level.rawValue)")
  }

  /// Calculates the frame of the bar based on config.
  private static func makeFrame(for screen: NSScreen) -> NSRect {
    let height = Config.shared.barHeight
    let baseFrame = Config.shared.barExtendBehindNotch ? screen.frame : screen.visibleFrame

    return NSRect(
      x: baseFrame.minX,
      y: baseFrame.maxY - height,
      width: baseFrame.width,
      height: height
    )
  }

  /// Builds the right-click menu for the bar.
  private func makeContextMenu() -> NSMenu {
    let menu = NSMenu()

    menu.addItem(versionItem("EasyBar \(BuildInfo.appVersion)"))
    menu.addItem(.separator())
    menu.addItem(actionItem(title: "Reload Config", action: #selector(reloadConfig(_:))))
    menu.addItem(actionItem(title: "Restart Lua Runtime", action: #selector(restartLuaRuntime(_:))))
    menu.addItem(.separator())
    menu.addItem(actionItem(title: "Open Config", action: #selector(openConfig(_:))))
    menu.addItem(actionItem(title: "Open Widgets Folder", action: #selector(openWidgetsFolder(_:))))
    menu.addItem(.separator())
    menu.addItem(
      agentMenuItem(
        title: "Calendar Agent",
        status: connectionLabel(CalendarAgentClient.shared.isConnected),
        permission: calendarPermissionLabel,
        settingsAction: #selector(openCalendarSettings(_:)),
        settingsTitle: "Open Calendar Settings"
      ))
    menu.addItem(
      agentMenuItem(
        title: "Network Agent",
        status: connectionLabel(NetworkAgentClient.shared.isConnected),
        permission: wifiPermissionLabel,
        settingsAction: #selector(openLocationSettings(_:)),
        settingsTitle: "Open Location/Wi-Fi Settings"
      ))

    return menu
  }

  /// Creates one enabled action item.
  private func actionItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
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
    connected ? "Connected" : "Disconnected"
  }

  /// Returns the current calendar permission label.
  private var calendarPermissionLabel: String {
    NativeCalendarStore.shared.snapshot?.permissionState ?? "unknown"
  }

  /// Returns the current Wi-Fi/location permission label.
  private var wifiPermissionLabel: String {
    NativeWiFiStore.shared.snapshot?.permissionState ?? "unknown"
  }

  /// Reloads the app config through the app layer.
  @objc private func reloadConfig(_ sender: Any?) {
    onReloadConfig?()
  }

  /// Restarts only the Lua runtime through the app layer.
  @objc private func restartLuaRuntime(_ sender: Any?) {
    onRestartLuaRuntime?()
  }

  /// Opens the active config file in Finder/default app.
  @objc private func openConfig(_ sender: Any?) {
    let url = URL(fileURLWithPath: Config.shared.configPath)
    NSWorkspace.shared.open(url)
  }

  /// Opens the configured widgets directory.
  @objc private func openWidgetsFolder(_ sender: Any?) {
    let url = URL(fileURLWithPath: Config.shared.widgetsPath, isDirectory: true)
    NSWorkspace.shared.open(url)
  }

  /// Opens Calendar privacy settings so the user can grant access again.
  @objc private func openCalendarSettings(_ sender: Any?) {
    openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
  }

  /// Opens Location Services settings so the user can grant Wi-Fi access again.
  @objc private func openLocationSettings(_ sender: Any?) {
    openSettingsURL(
      "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
  }

  /// Opens one System Settings deep link when available.
  private func openSettingsURL(_ value: String) {
    guard let url = URL(string: value) else { return }
    NSWorkspace.shared.open(url)
  }
}

private final class BarPanel: NSPanel {
  var contextMenuProvider: (() -> NSMenu)?

  override var canBecomeKey: Bool {
    false
  }

  override var canBecomeMain: Bool {
    false
  }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  /// Shows the dynamic bar context menu on right click.
  override func rightMouseUp(with event: NSEvent) {
    guard let menu = contextMenuProvider?() else {
      super.rightMouseUp(with: event)
      return
    }

    guard let targetView = contentView else {
      super.rightMouseUp(with: event)
      return
    }

    NSMenu.popUpContextMenu(menu, with: event, for: targetView)
  }
}
