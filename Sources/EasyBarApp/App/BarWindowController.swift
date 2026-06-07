import AppKit
import EasyBarShared
import SwiftUI

/// Hosts the top-level borderless bar window.
@MainActor
final class BarWindowController: NSWindowController {
  /// Callback for manual refresh menu actions.
  var onRefresh: (() -> Void)?
  /// Callback for config reload menu actions.
  var onReloadConfig: (() -> Void)?
  /// Callback for Lua runtime restart menu actions.
  var onRestartLuaRuntime: (() -> Void)?

  /// Logger used for window diagnostics.
  private let logger: ProcessLogger
  /// Store that exposes the active immutable config snapshot to SwiftUI.
  private let configStore: ConfigSnapshotStore
  /// Hosting view containing the SwiftUI bar content.
  private let hostingView: BarHostingView<AnyView>
  /// Provider for dynamic context-menu state.
  private let menuStateProvider: BarContextMenuStateProviding

  /// Factory that builds the bar context menu.
  private lazy var contextMenuFactory = BarContextMenuFactory(
    logger: logger,
    configStore: configStore,
    actions: BarContextMenuActions(
      refresh: { [weak self] in self?.onRefresh?() },
      reloadConfig: { [weak self] in self?.onReloadConfig?() },
      restartLuaRuntime: { [weak self] in self?.onRestartLuaRuntime?() }
    ),
    stateProvider: menuStateProvider
  )

  /// Creates a borderless bar window pinned to the top of the screen.
  init(
    logger: ProcessLogger,
    configStore: ConfigSnapshotStore,
    menuStateProvider: BarContextMenuStateProviding
  ) {
    self.logger = logger
    self.configStore = configStore
    self.menuStateProvider = menuStateProvider

    let screen = NSScreen.main ?? NSScreen.screens[0]
    let frame = Self.makeFrame(for: screen, snapshot: configStore.snapshot)
    logger.info(
      "bar window initial",
      .field("target_frame", NSStringFromRect(frame)),
    )

    let contentView = AnyView(
      BarContentView(logger: logger)
        .environmentObject(configStore)
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

    logger.info(
      "bar window reload begin",
      .field("current_frame", NSStringFromRect(window.frame)),
      .field("target_frame", NSStringFromRect(frame))
    )

    hostingView.rootView = AnyView(
      BarContentView(logger: logger)
        .environmentObject(configStore)
    )
    window.setFrame(frame, display: true)
    window.setContentSize(frame.size)
    window.minSize = frame.size
    window.maxSize = frame.size
    hostingView.frame = NSRect(origin: .zero, size: frame.size)

    logger.info(
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
    logger.info(
      "bar window presented",
      .field("frame", NSStringFromRect(window.frame)),
      .field("level", window.level.rawValue)
    )
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
