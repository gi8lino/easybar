import Foundation

/// Main-actor bridge used by the actor-owned runtime to trigger UI work.
@MainActor
final class RuntimeUIBridge {
  static let shared = RuntimeUIBridge()

  private init() {}

  /// Reloads the bar layout when the main window controller exists.
  func reloadBarLayout() {
    AppController.shared.reloadBarLayout()
  }

  /// Updates the config error window from the current config failure state.
  func updateConfigErrorWindow() {
    AppController.shared.updateConfigErrorWindow()
  }

  /// Applies the full post-config-reload UI refresh.
  func handlePostConfigReloadUI() {
    AppController.shared.handlePostConfigReloadUI()
  }
}
