import Foundation

/// Returns one non-empty string environment value.
public func stringEnvironmentValue(named name: String) -> String? {
  guard
    let value = ProcessInfo.processInfo.environment[name]?
      .trimmingCharacters(in: .whitespacesAndNewlines),
    !value.isEmpty
  else {
    return nil
  }

  return value
}

/// Returns one boolean environment value when it is valid.
public func boolEnvironmentValue(named name: String) -> Bool? {
  guard let value = stringEnvironmentValue(named: name) else { return nil }

  switch value.lowercased() {
  case "1", "true", "yes", "on":
    return true
  case "0", "false", "no", "off":
    return false
  default:
    return nil
  }
}

/// Returns one numeric environment value when it is valid.
public func timeIntervalEnvironmentValue(named name: String) -> TimeInterval? {
  guard let value = stringEnvironmentValue(named: name) else { return nil }
  return TimeInterval(value)
}

/// Expands `~` when present and returns one non-empty path string.
public func expandedPath(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return NSString(string: value).expandingTildeInPath
}

/// Returns one expanded path environment value when present.
public func expandedEnvironmentPath(named name: String) -> String? {
  expandedPath(stringEnvironmentValue(named: name))
}
