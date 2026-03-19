import AppKit
import SwiftUI

/// Hosting view that disables AppKit safe-area insets so the bar can extend behind the notch.
final class BarHostingView<Content: View>: NSHostingView<Content> {

    override var safeAreaInsets: NSEdgeInsets {
        .init(top: 0, left: 0, bottom: 0, right: 0)
    }

    override var safeAreaRect: NSRect {
        bounds
    }

    override var safeAreaLayoutGuide: NSLayoutGuide {
        layoutGuide
    }

    override var additionalSafeAreaInsets: NSEdgeInsets {
        get { .init(top: 0, left: 0, bottom: 0, right: 0) }
        set { }
    }
}
