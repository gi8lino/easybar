import Foundation
import TOMLKit

/// Returns the resolved EasyBar socket config from defaults.
func resolvedEasyBarConfig(from toml: TOMLTable) -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(socketPath: defaultEasyBarSocketPath())
}

/// Returns the resolved EasyBar socket defaults.
func resolvedEasyBarEnvironmentDefaults() -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(socketPath: defaultEasyBarSocketPath())
}

/// Returns the resolved calendar-agent config from TOML and defaults.
func resolvedCalendarAgentConfig(from toml: TOMLTable) -> SharedCalendarAgentRuntimeConfig {
  let calendarTable = toml["agents"]?["calendar"]?.table

  let enabled = calendarTable?["enabled"]?.bool ?? true
  let socketPath = resolvedSocketPath(
    tomlValue: calendarTable?["socket_path"]?.string,
    fallback: defaultCalendarAgentSocketPath
  )

  return SharedCalendarAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath
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
func resolvedNetworkAgentConfig(from toml: TOMLTable) -> SharedNetworkAgentRuntimeConfig {
  let networkTable = toml["agents"]?["network"]?.table

  let enabled = networkTable?["enabled"]?.bool ?? true
  let socketPath = resolvedSocketPath(
    tomlValue: networkTable?["socket_path"]?.string,
    fallback: defaultNetworkAgentSocketPath
  )

  let refreshIntervalSeconds =
    tomlNumber(networkTable?["refresh_interval_seconds"])
    ?? 60

  let allowUnauthorizedFieldsWithoutLocation =
    networkTable?["allow_unauthorized_non_sensitive_fields"]?.bool
    ?? false

  return SharedNetworkAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath,
    refreshIntervalSeconds: refreshIntervalSeconds,
    allowUnauthorizedFieldsWithoutLocation: allowUnauthorizedFieldsWithoutLocation
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

/// Returns one resolved socket path from TOML and fallback defaults.
func resolvedSocketPath(
  tomlValue: String?,
  fallback: () -> String
) -> String {
  expandedPath(tomlValue) ?? fallback()
}

/// Returns the default Unix socket path used by EasyBar.
func defaultEasyBarSocketPath() -> String { return "/tmp/EasyBar/easybar.sock" }

/// Returns the default Unix socket path used by the calendar agent.
func defaultCalendarAgentSocketPath() -> String { return "/tmp/EasyBar/calendar-agent.sock" }

/// Returns the default Unix socket path used by the network agent.
func defaultNetworkAgentSocketPath() -> String { return "/tmp/EasyBar/network-agent.sock" }

/// Returns one TOML number as a Double.
private func tomlNumber(_ value: (any TOMLValueConvertible)?) -> Double? {
  if let double = value?.double {
    return double
  }

  if let int = value?.int {
    return Double(int)
  }

  return nil
}
