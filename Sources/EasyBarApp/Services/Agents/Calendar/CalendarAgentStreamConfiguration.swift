import Foundation

extension ConfigSnapshot.CalendarAgent {
  /// Returns whether an existing calendar-agent stream must restart for the new config.
  func requiresStreamRestart(for newConfig: ConfigSnapshot.CalendarAgent) -> Bool {
    return enabled != newConfig.enabled || socketPath != newConfig.socketPath
  }
}
