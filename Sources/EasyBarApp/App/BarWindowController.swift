import AppKit
import EasyBarShared
import SwiftUI

private final class BarHostingView<Content: View>: NSHostingView<Content> {
  override var safeAreaInsets: NSEdgeInsets {
    .init(top: 0, left: 0, bottom: 0, right: 0)
  }

  override var safeAreaRect: NSRect {
    bounds
  }
}

/// Hosts the top-level borderless bar window.
@MainActor
final class BarWindowController: NSWindowController {
  /// Callback for manual refresh menu actions.
  var onRefresh: (() -> Void)?
  /// Callback for config reload menu actions.
  var onReloadConfig: (() -> Void)?
  /// Callback for Lua runtime restart menu actions.
  var onRestartLuaRuntime: (() -> Void)?
  /// Callback for persistent theme selection.
  var onSelectTheme: ((String?) -> Void)?

  /// Logger used for window diagnostics.
  private let logger: ProcessLogger
  /// Store that exposes the active immutable config snapshot to SwiftUI.
  private let configStore: ConfigSnapshotStore
  private let widgetStore: WidgetStore
  private let aeroSpaceService: AeroSpaceService
  private let appViewServices: AppViewServices
  /// Hosting view containing the SwiftUI bar content.
  private let hostingView: BarHostingView<AnyView>
  /// Provider for dynamic context-menu state.
  private let menuStateProvider: BarContextMenuStateProvider

  /// Factory that builds the bar context menu.
  private lazy var contextMenuFactory = BarContextMenuFactory(
    logger: logger,
    configStore: configStore,
    actions: BarContextMenuActions(
      refresh: { [weak self] in self?.onRefresh?() },
      reloadConfig: { [weak self] in self?.onReloadConfig?() },
      restartLuaRuntime: { [weak self] in self?.onRestartLuaRuntime?() },
      selectTheme: { [weak self] name in self?.onSelectTheme?(name) }
    ),
    stateProvider: menuStateProvider
  )

  /// Creates a borderless bar window pinned to the top of the screen.
  init(
    logger: ProcessLogger,
    configStore: ConfigSnapshotStore,
    widgetStore: WidgetStore,
    aeroSpaceService: AeroSpaceService,
    appViewServices: AppViewServices,
    menuStateProvider: BarContextMenuStateProvider
  ) {
    self.logger = logger
    self.configStore = configStore
    self.widgetStore = widgetStore
    self.aeroSpaceService = aeroSpaceService
    self.appViewServices = appViewServices
    self.menuStateProvider = menuStateProvider

    let screen = NSScreen.main ?? NSScreen.screens[0]
    let frame = Self.makeFrame(for: screen, snapshot: configStore.snapshot)
    logger.debug(
      "bar window initial",
      .field("target_frame", NSStringFromRect(frame)),
    )

    let contentView = AnyView(
      BarContentView(logger: logger)
        .environmentObject(configStore)
        .environmentObject(widgetStore)
        .environmentObject(aeroSpaceService)
        .environment(\.appViewServices, appViewServices)
    )

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

    self.hostingView = hostingView

    super.init(window: window)

    window.contextMenuProvider = { [weak self] showDeveloperSection in
      self?.contextMenuFactory.makeMenu(showDeveloperSection: showDeveloperSection) ?? NSMenu()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  /// Reapplies the configured frame and root view after a config reload.
  func reloadLayout() {
    guard let window else {
      logger.warn("bar window reloadLayout skipped because window is unavailable")
      return
    }

    let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
    let frame = Self.makeFrame(for: screen, snapshot: configStore.snapshot)

    logger.debug(
      "bar window reload begin",
      .field("current_frame", NSStringFromRect(window.frame)),
      .field("target_frame", NSStringFromRect(frame))
    )

    hostingView.rootView = AnyView(
      BarContentView(logger: logger)
        .environmentObject(configStore)
        .environmentObject(widgetStore)
        .environmentObject(aeroSpaceService)
        .environment(\.appViewServices, appViewServices)
    )
    window.setFrame(frame, display: true)
    window.setContentSize(frame.size)
    window.minSize = frame.size
    window.maxSize = frame.size
    hostingView.frame = NSRect(origin: .zero, size: frame.size)

    logger.debug(
      "bar window reload end",
      .field("frame", NSStringFromRect(window.frame)),
    )
  }

  /// Shows the panel without asking AppKit to make it key.
  func present() {
    guard let window else {
      logger.warn("bar window present skipped because window is unavailable")
      return
    }

    window.setFrame(window.frame, display: true)
    window.orderFrontRegardless()
    logger.debug(
      "bar window presented",
      .field("frame", NSStringFromRect(window.frame)),
      .field("level", window.level.rawValue)
    )
  }

  /// Hides the bar while keeping its window and the app's menu-bar controller alive.
  func hide() {
    window?.orderOut(nil)
    logger.debug("bar window hidden")
  }

  /// Calculates the frame of the bar based on config.
  private static func makeFrame(for screen: NSScreen, snapshot: ConfigSnapshot) -> NSRect {
    let height = snapshot.bar.height
    let baseFrame = snapshot.bar.extendBehindNotch ? screen.frame : screen.visibleFrame

    return NSRect(
      x: baseFrame.minX,
      y: baseFrame.maxY - height,
      width: baseFrame.width,
      height: height
    )
  }
}
