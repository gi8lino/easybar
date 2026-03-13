import AppKit
import SwiftUI

/// Hosts the top-level borderless bar window.
final class BarWindowController: NSWindowController {

    /// Creates a borderless bar window pinned to the top of the screen.
    init(aeroSpaceService: AeroSpaceService) {

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = Self.makeFrame(for: screen)

        let contentView = BarRootView(aeroSpaceService: aeroSpaceService)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]

        window.contentView = NSHostingView(rootView: contentView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Calculates the frame of the bar based on config.
    private static func makeFrame(for screen: NSScreen) -> NSRect {

        let height = Config.shared.barHeight
        let visibleFrame = screen.visibleFrame

        return NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.maxY - height,
            width: visibleFrame.width,
            height: height
        )
    }
}
