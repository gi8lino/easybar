import Foundation

/// Returns the resolved EasyBar socket config from defaults.
func resolvedEasyBarConfig(from _: SharedRuntimeConfigReader) throws -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(socketPath: SharedPathDefaults.defaultEasyBarSocketPath)
}

/// Returns the resolved EasyBar socket defaults.
func resolvedEasyBarEnvironmentDefaults() -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(socketPath: SharedPathDefaults.defaultEasyBarSocketPath)
}

/// Returns the resolved calendar-agent config from TOML and defaults.
func resolvedCalendarAgentConfig(
  from reader: SharedRuntimeConfigReader
) throws -> SharedCalendarAgentRuntimeConfig {
  let calendar = try reader.section("agents.calendar")

  return SharedCalendarAgentRuntimeConfig(
    enabled: try calendar.bool("enabled", fallback: true),
    socketPath: try calendar.expandedPath(
      "socket_path",
      fallback: defaultCalendarAgentSocketPath()
    )
  )
}

/// Returns the resolved calendar-agent defaults.
func resolvedCalendarAgentEnvironmentDefaults() -> SharedCalendarAgentRuntimeConfig {
  SharedCalendarAgentRuntimeConfig(
    enabled: true,
    socketPath: defaultCalendarAgentSocketPath()
  )
}

/// Returns the resolved network-agent config from TOML and defaults.
func resolvedNetworkAgentConfig(
  from reader: SharedRuntimeConfigReader
) throws -> SharedNetworkAgentRuntimeConfig {
  let network = try reader.section("agents.network")

  return SharedNetworkAgentRuntimeConfig(
    enabled: try network.bool("enabled", fallback: true),
    socketPath: try network.expandedPath(
      "socket_path",
      fallback: defaultNetworkAgentSocketPath()
    ),
    refreshIntervalSeconds: try network.double(
      "refresh_interval_seconds",
      fallback: 60,
      minimum: 0
    ),
    allowUnauthorizedFieldsWithoutLocation: try network.bool(
      "allow_unauthorized_non_sensitive_fields",
      fallback: false
    )
  )
}

/// Returns the resolved network-agent defaults.
func resolvedNetworkAgentEnvironmentDefaults() -> SharedNetworkAgentRuntimeConfig {
  SharedNetworkAgentRuntimeConfig(
    enabled: true,
    socketPath: defaultNetworkAgentSocketPath(),
    refreshIntervalSeconds: 60,
    allowUnauthorizedFieldsWithoutLocation: false
  )
}

/// Returns the default Unix socket path used by the calendar agent.
func defaultCalendarAgentSocketPath() -> String { return "/tmp/EasyBar/calendar-agent.sock" }

/// Returns the default Unix socket path used by the network agent.
func defaultNetworkAgentSocketPath() -> String { return "/tmp/EasyBar/network-agent.sock" }
