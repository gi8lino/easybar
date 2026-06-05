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
    case validateConfig = "validate_config"
    case metrics = "metrics"
  }

  /// One IPC request sent to the EasyBar socket.
  public enum Request: Codable {
    case command(Command)
    case validateConfig(configPath: String?)
    case metrics(watch: Bool)

    private enum CodingKeys: String, CodingKey {
      case command
      case configPath = "config_path"
      case watch
    }

    /// Builds one non-streaming IPC command request.
    public static func makeCommand(_ command: Command) -> Self {
      switch command {
      case .metrics:
        return .metrics(watch: false)
      case .validateConfig:
        return .validateConfig(configPath: nil)
      default:
        return .command(command)
      }
    }

    /// Builds one config validation request.
    public static func makeValidateConfig(configPath: String? = nil) -> Self {
      return .validateConfig(configPath: configPath)
    }

    /// Builds one metrics request.
    public static func makeMetrics(watch: Bool = false) -> Self {
      return .metrics(watch: watch)
    }

    /// Returns the command represented by this request.
    public var command: Command {
      switch self {
      case .command(let command):
        return command
      case .validateConfig:
        return .validateConfig
      case .metrics:
        return .metrics
      }
    }

    /// Returns the config path requested for validation, when present.
    public var configPath: String? {
      switch self {
      case .validateConfig(let configPath):
        return configPath
      case .command, .metrics:
        return nil
      }
    }

    /// Returns whether this request keeps the metrics stream open.
    public var watch: Bool {
      switch self {
      case .command, .validateConfig:
        return false
      case .metrics(let watch):
        return watch
      }
    }

    /// Decodes one IPC request.
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let command = try container.decode(Command.self, forKey: .command)

      switch command {
      case .metrics:
        self = .metrics(watch: try container.decodeIfPresent(Bool.self, forKey: .watch) ?? false)
      case .validateConfig:
        self = .validateConfig(
          configPath: try container.decodeIfPresent(String.self, forKey: .configPath)
        )
      default:
        self = .command(command)
      }
    }

    /// Encodes one IPC request.
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .command(let command):
        try container.encode(command, forKey: .command)

      case .validateConfig(let configPath):
        try container.encode(Command.validateConfig, forKey: .command)
        try container.encodeIfPresent(configPath, forKey: .configPath)

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
      case configValidated = "config_validated"
      case metrics
    }

    case accepted
    case rejected(message: String?)
    case configValidated(configPath: String, warnings: [String])
    case metrics(MetricsSnapshot)

    private enum CodingKeys: String, CodingKey {
      case kind
      case message
      case configPath = "config_path"
      case metrics
      case warnings
    }

    /// Returns the message kind for logging and compatibility helpers.
    public var kind: Kind {
      switch self {
      case .accepted:
        return .accepted
      case .rejected:
        return .rejected
      case .configValidated:
        return .configValidated
      case .metrics:
        return .metrics
      }
    }

    /// Returns the rejection message when present.
    public var message: String? {
      switch self {
      case .rejected(let message):
        return message
      case .accepted, .configValidated, .metrics:
        return nil
      }
    }

    /// Returns the validated config path when present.
    public var configPath: String? {
      switch self {
      case .configValidated(let configPath, _):
        return configPath
      case .accepted, .rejected, .metrics:
        return nil
      }
    }

    /// Returns validation warnings when present.
    public var warnings: [String] {
      switch self {
      case .configValidated(_, let warnings):
        return warnings
      case .accepted, .rejected, .metrics:
        return []
      }
    }

    /// Returns the metrics payload when present.
    public var metrics: MetricsSnapshot? {
      switch self {
      case .metrics(let snapshot):
        return snapshot
      case .accepted, .rejected, .configValidated:
        return nil
      }
    }

    /// Decodes one IPC message.
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let kind = try container.decode(Kind.self, forKey: .kind)

      switch kind {
      case .accepted:
        self = .accepted

      case .rejected:
        self = .rejected(message: try container.decodeIfPresent(String.self, forKey: .message))

      case .configValidated:
        self = .configValidated(
          configPath: try container.decode(String.self, forKey: .configPath),
          warnings: try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        )

      case .metrics:
        self = .metrics(try container.decode(MetricsSnapshot.self, forKey: .metrics))
      }
    }

    /// Encodes one IPC message.
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .accepted:
        try container.encode(Kind.accepted, forKey: .kind)

      case .rejected(let message):
        try container.encode(Kind.rejected, forKey: .kind)
        try container.encodeIfPresent(message, forKey: .message)

      case .configValidated(let configPath, let warnings):
        try container.encode(Kind.configValidated, forKey: .kind)
        try container.encode(configPath, forKey: .configPath)
        if !warnings.isEmpty {
          try container.encode(warnings, forKey: .warnings)
        }

      case .metrics(let snapshot):
        try container.encode(Kind.metrics, forKey: .kind)
        try container.encode(snapshot, forKey: .metrics)
      }
    }
  }
}
