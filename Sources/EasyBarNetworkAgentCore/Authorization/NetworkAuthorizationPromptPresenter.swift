import Foundation

/// Presents and restores any app-level UI needed for authorization prompts.
public protocol NetworkAuthorizationPromptPresenter: AnyObject {
  /// Prepares the host app so the system authorization prompt can appear.
  func preparePrompt()

  /// Restores the host app UI after authorization state resolves.
  func restoreUI()
}
