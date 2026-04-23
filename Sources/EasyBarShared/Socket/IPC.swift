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
  public enum Request: Codable {
    case command(Command)
    case metrics(watch: Bool)

    private enum CodingKeys: String, CodingKey {
      case command
      case watch
    }

    /// Builds one non-streaming IPC command request.
    public static func makeCommand(_ command: Command) -> Self {
      if command == .metrics {
        return .metrics(watch: false)
      }

      return .command(command)
    }

    /// Builds one metrics request.
    public static func makeMetrics(watch: Bool = false) -> Self {
      .metrics(watch: watch)
    }

    /// Returns the command represented by this request.
    public var command: Command {
      switch self {
      case .command(let command):
        return command
      case .metrics:
        return .metrics
      }
    }

    /// Returns whether this request keeps the metrics stream open.
    public var watch: Bool {
      switch self {
      case .command:
        return false
      case .metrics(let watch):
        return watch
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let command = try container.decode(Command.self, forKey: .command)

      if command == .metrics {
        self = .metrics(watch: try container.decodeIfPresent(Bool.self, forKey: .watch) ?? false)
      } else {
        self = .command(command)
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .command(let command):
        try container.encode(command, forKey: .command)

      case .metrics(let watch):
        try container.encode(Command.metrics, forKey: .command)
        if watch {
          try container.encode(watch, forKey: .watch)
        }
      }
    }
  }

  /// One IPC message returned by the EasyBar socket.
  public enum Message: Codable {
    public enum Kind: String, Codable {
      case accepted
      case rejected
      case metrics
    }

    case accepted
    case rejected(message: String?)
    case metrics(MetricsSnapshot)

    private enum CodingKeys: String, CodingKey {
      case kind
      case message
      case metrics
    }

    /// Returns the message kind for logging and compatibility helpers.
    public var kind: Kind {
      switch self {
      case .accepted:
        return .accepted
      case .rejected:
        return .rejected
      case .metrics:
        return .metrics
      }
    }

    /// Returns the rejection message when present.
    public var message: String? {
      switch self {
      case .rejected(let message):
        return message
      case .accepted, .metrics:
        return nil
      }
    }

    /// Returns the metrics payload when present.
    public var metrics: MetricsSnapshot? {
      switch self {
      case .metrics(let snapshot):
        return snapshot
      case .accepted, .rejected:
        return nil
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let kind = try container.decode(Kind.self, forKey: .kind)

      switch kind {
      case .accepted:
        self = .accepted

      case .rejected:
        self = .rejected(message: try container.decodeIfPresent(String.self, forKey: .message))

      case .metrics:
        self = .metrics(try container.decode(MetricsSnapshot.self, forKey: .metrics))
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .accepted:
        try container.encode(Kind.accepted, forKey: .kind)

      case .rejected(let message):
        try container.encode(Kind.rejected, forKey: .kind)
        try container.encodeIfPresent(message, forKey: .message)

      case .metrics(let snapshot):
        try container.encode(Kind.metrics, forKey: .kind)
        try container.encode(snapshot, forKey: .metrics)
      }
    }
  }
}
