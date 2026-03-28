import Foundation

/// Commands received through the EasyBar IPC socket.
public enum IPCCommand: String {
  case workspaceChanged = "workspace_changed"
  case focusChanged = "focus_changed"
  case refresh = "refresh"
  case reloadConfig = "reload_config"
}
