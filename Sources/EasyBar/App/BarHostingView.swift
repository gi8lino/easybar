import AppKit
import SwiftUI

/// Hosting view that disables AppKit safe-area insets so the bar can extend behind the notch.
final class BarHostingView<Content: View>: NSHostingView<Content> {
  /// Removes all safe-area padding from the hosted SwiftUI content.
  override var safeAreaInsets: NSEdgeInsets {
    .init(top: 0, left: 0, bottom: 0, right: 0)
  }

  /// Treats the full view bounds as safe for layout.
  override var safeAreaRect: NSRect {
    bounds
  }
}
