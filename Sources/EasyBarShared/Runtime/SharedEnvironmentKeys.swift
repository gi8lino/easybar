import Foundation

/// Central registry of environment variable names used by EasyBar processes.
///
/// This file is the single source of truth for raw environment keys.
/// Parsing and precedence stay in the runtime config layer.
public enum SharedEnvironmentKeys {
  public static let configPath = "EASYBAR_CONFIG_PATH"

  public static let lockDirectory = "EASYBAR_LOCK_DIR"

  public static let loggingEnabled = "EASYBAR_LOGGING_ENABLED"
  public static let loggingLevel = "EASYBAR_LOG_LEVEL"
  public static let loggingDirectory = "EASYBAR_LOGGING_DIRECTORY"

  public static let easyBarSocketPath = "EASYBAR_SOCKET_PATH"

  public static let calendarAgentEnabled = "EASYBAR_CALENDAR_AGENT_ENABLED"
  public static let calendarAgentSocketPath = "EASYBAR_CALENDAR_AGENT_SOCKET"

  public static let networkAgentEnabled = "EASYBAR_NETWORK_AGENT_ENABLED"
  public static let networkAgentSocketPath = "EASYBAR_NETWORK_AGENT_SOCKET"
  public static let networkAgentRefreshIntervalSeconds =
    "EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS"
  public static let networkAgentAllowUnauthorizedNonSensitiveFields =
    "EASYBAR_NETWORK_AGENT_ALLOW_UNAUTHORIZED_NON_SENSITIVE_FIELDS"

  /// CLI-only override used by `easybarctl`.
  public static let cliLogLevel = "EASYBARCTL_LOG_LEVEL"
}
