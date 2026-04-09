import Foundation
import TOMLKit

/// Returns the resolved EasyBar socket config from env, TOML, and defaults.
func resolvedEasyBarConfig(from toml: TOMLTable) -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(
    socketPath: resolvedSocketPath(
      environmentName: SharedEnvironmentKeys.easyBarSocketPath,
      tomlValue: nil,
      fallback: defaultEasyBarSocketPath
    )
  )
}

/// Returns the resolved calendar-agent config from env, TOML, and defaults.
func resolvedCalendarAgentConfig(from toml: TOMLTable) -> SharedCalendarAgentRuntimeConfig {
  let calendarTable = toml["agents"]?["calendar"]?.table

  let enabled =
    boolEnvironmentValue(named: SharedEnvironmentKeys.calendarAgentEnabled)
    ?? calendarTable?["enabled"]?.bool
    ?? true

  let socketPath = resolvedSocketPath(
    environmentName: SharedEnvironmentKeys.calendarAgentSocketPath,
    tomlValue: calendarTable?["socket_path"]?.string,
    fallback: defaultCalendarAgentSocketPath
  )

  return SharedCalendarAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath
  )
}

/// Returns the resolved network-agent config from env, TOML, and defaults.
func resolvedNetworkAgentConfig(from toml: TOMLTable) -> SharedNetworkAgentRuntimeConfig {
  let networkTable = toml["agents"]?["network"]?.table

  let enabled =
    boolEnvironmentValue(named: SharedEnvironmentKeys.networkAgentEnabled)
    ?? networkTable?["enabled"]?.bool
    ?? true

  let socketPath = resolvedSocketPath(
    environmentName: SharedEnvironmentKeys.networkAgentSocketPath,
    tomlValue: networkTable?["socket_path"]?.string,
    fallback: defaultNetworkAgentSocketPath
  )

  let refreshIntervalSeconds =
    timeIntervalEnvironmentValue(named: SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds)
    ?? networkTable?["refresh_interval_seconds"]?.double
    ?? 60

  let allowUnauthorizedFieldsWithoutLocation =
    boolEnvironmentValue(
      named: SharedEnvironmentKeys.networkAgentAllowUnauthorizedNonSensitiveFields
    )
    ?? networkTable?["allow_unauthorized_non_sensitive_fields"]?.bool
    ?? false

  return SharedNetworkAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath,
    refreshIntervalSeconds: refreshIntervalSeconds,
    allowUnauthorizedFieldsWithoutLocation: allowUnauthorizedFieldsWithoutLocation
  )
}

/// Returns one resolved socket path from env, TOML, and fallback defaults.
func resolvedSocketPath(
  environmentName: String,
  tomlValue: String?,
  fallback: () -> String
) -> String {
  expandedEnvironmentPath(named: environmentName)
    ?? expandedPath(tomlValue)
    ?? fallback()
}

/// Returns the default Unix socket path used by EasyBar.
func defaultEasyBarSocketPath() -> String {
  "/tmp/EasyBar/easybar.sock"
}

/// Returns the default Unix socket path used by the calendar agent.
func defaultCalendarAgentSocketPath() -> String {
  "/tmp/EasyBar/calendar-agent.sock"
}

/// Returns the default Unix socket path used by the network agent.
func defaultNetworkAgentSocketPath() -> String {
  "/tmp/EasyBar/network-agent.sock"
}
