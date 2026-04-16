import Foundation

/// Main-actor bridge for UI-owned runtime side effects.
///
/// The runtime coordinator is intentionally not allowed to own AppKit window
/// controllers directly. This bridge keeps those actions on the main actor.
@MainActor
final class RuntimeUIBridge {
  static let shared = RuntimeUIBridge()

  weak var appDelegate: AppDelegate?

  /// Reloads the bar layout when the main window controller exists.
  func reloadBarLayout() {
    appDelegate?.reloadBarLayoutFromRuntime()
  }

  /// Updates the config error window from the current config failure state.
  func updateConfigErrorWindow() {
    appDelegate?.updateConfigErrorWindowFromRuntime()
  }
}
