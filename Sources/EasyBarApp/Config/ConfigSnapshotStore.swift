import Foundation

/// Main-actor observable holder for the active immutable config snapshot.
///
/// Runtime services receive explicit `ConfigSnapshot` values. SwiftUI views use this
/// store only to observe which immutable snapshot is currently active.
@MainActor
final class ConfigSnapshotStore: ObservableObject {
  /// Active config snapshot used by UI renderers.
  @Published private(set) var snapshot: ConfigSnapshot

  /// Creates a snapshot store with the provided initial snapshot.
  init(snapshot: ConfigSnapshot) {
    self.snapshot = snapshot
  }

  /// Replaces the active snapshot after a successful or rejected config load.
  func apply(_ snapshot: ConfigSnapshot) {
    self.snapshot = snapshot
  }

  /// Applies one session-only calendar override for native calendar popup views.
  func applyCalendarSessionOverride(_ calendar: Config.CalendarBuiltinConfig) {
    let builtins = snapshot.builtins
    snapshot = ConfigSnapshot(
      app: snapshot.app,
      logging: snapshot.logging,
      calendarAgent: snapshot.calendarAgent,
      networkAgent: snapshot.networkAgent,
      theme: snapshot.theme,
      bar: snapshot.bar,
      builtins: .init(
        inbox: builtins.inbox,
        cpu: builtins.cpu,
        battery: builtins.battery,
        groups: builtins.groups,
        spaces: builtins.spaces,
        frontApp: builtins.frontApp,
        aerospaceMode: builtins.aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }
}
