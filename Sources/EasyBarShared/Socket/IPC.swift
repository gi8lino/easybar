import Foundation

/// Shared IPC protocol types used between EasyBar and its clients.
public enum IPC {}

extension IPC {
  /// Commands received through the EasyBar IPC socket.
  public enum Command: String, Codable {
    case workspaceChanged = "workspace_changed"
    case focusChanged = "focus_changed"
    case spaceModeChanged = "space_mode_changed"
    case manualRefresh = "manual_refresh"
    case restartLuaRuntime = "restart_lua_runtime"
    case reloadConfig = "reload_config"
    case metrics = "metrics"
  }

  /// One IPC request sent to the EasyBar socket.
  public struct Request: Codable {
    public let command: Command
    public let watch: Bool

    private enum CodingKeys: String, CodingKey {
      case command
      case watch
    }

    /// Builds one IPC request for the given command.
    public init(command: Command, watch: Bool = false) {
      self.command = command
      self.watch = watch
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      command = try container.decode(Command.self, forKey: .command)
      watch = try container.decodeIfPresent(Bool.self, forKey: .watch) ?? false
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(command, forKey: .command)
      try container.encode(watch, forKey: .watch)
    }
  }

  /// One IPC message returned by the EasyBar socket.
  public struct Message: Codable {
    public enum Kind: String, Codable {
      case accepted
      case rejected
      case metrics
    }

    public let kind: Kind
    public let message: String?
    public let metrics: MetricsSnapshot?

    /// Builds one IPC message.
    public init(kind: Kind, message: String? = nil, metrics: MetricsSnapshot? = nil) {
      self.kind = kind
      self.message = message
      self.metrics = metrics
    }
  }
}
