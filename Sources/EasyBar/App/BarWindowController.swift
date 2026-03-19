import AppKit
import SwiftUI

/// Hosts the top-level borderless bar window.
final class BarWindowController: NSWindowController {

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
            .ignoresCycle
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
        Logger.info("bar window presented frame=\(NSStringFromRect(window.frame)) level=\(window.level.rawValue)")
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
}

private final class BarPanel: NSPanel {

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
