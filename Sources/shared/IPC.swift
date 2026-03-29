import Foundation

/// Shared IPC protocol types used between EasyBar and its clients.
public enum IPC {}

extension IPC {
  /// Commands received through the EasyBar IPC socket.
  public enum Command: String, Codable {
    case workspaceChanged = "workspace_changed"
    case focusChanged = "focus_changed"
    case refresh = "refresh"
    case reloadConfig = "reload_config"
  }

  /// One IPC request sent to the EasyBar socket.
  public struct Request: Codable {
    public let command: Command

    /// Builds one IPC request for the given command.
    public init(command: Command) {
      self.command = command
    }
  }

  /// One IPC response returned by the EasyBar socket.
  public struct Response: Codable {
    public let accepted: Bool
    public let message: String?

    /// Builds one IPC response.
    public init(accepted: Bool, message: String? = nil) {
      self.accepted = accepted
      self.message = message
    }
  }
}
