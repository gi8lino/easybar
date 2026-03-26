import Foundation

/// Commands received through the IPC socket.
enum IPCCommand: String {
  case workspaceChanged = "workspace_changed"
  case focusChanged = "focus_changed"
  case refresh = "refresh"
  case reloadConfig = "reload_config"
}
