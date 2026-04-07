import Foundation

/// Handles app-level presentation changes needed for location authorization prompts.
@MainActor
public protocol NetworkAuthorizationPromptPresenter: AnyObject {
  /// Prepares the host app so the system prompt can surface.
  func preparePrompt()

  /// Restores the host app UI after authorization resolves.
  func restoreUI()
}
