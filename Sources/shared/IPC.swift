import Foundation

/// Shared IPC protocol types used between EasyBar and its clients.
public enum IPC {}

extension IPC {
  /// Commands received through the EasyBar IPC socket.
  public enum Command: String {
    case workspaceChanged = "workspace_changed"
    case focusChanged = "focus_changed"
    case refresh = "refresh"
    case reloadConfig = "reload_config"
  }
}
