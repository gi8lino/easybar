import Foundation

/// Returns one resolved log level from env, TOML, and defaults.
func resolvedProcessLogLevel(
  environmentName: String,
  tomlValue: String?,
  fallback: ProcessLogLevel = .info
) -> ProcessLogLevel {
  if let raw = stringEnvironmentValue(named: environmentName),
    let level = ProcessLogLevel(string: raw)
  {
    return level
  }

  if let tomlValue,
    let level = ProcessLogLevel(string: tomlValue)
  {
    return level
  }

  return fallback
}
