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

  /// Applies a calendar configuration written by its native context menu.
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

  /// Applies an inbox configuration written by its native context menu.
  func applyInboxOverride(_ inbox: Config.InboxBuiltinConfig) {
    let builtins = snapshot.builtins
    snapshot = ConfigSnapshot(
      app: snapshot.app,
      logging: snapshot.logging,
      calendarAgent: snapshot.calendarAgent,
      networkAgent: snapshot.networkAgent,
      theme: snapshot.theme,
      bar: snapshot.bar,
      builtins: .init(
        inbox: inbox,
        cpu: builtins.cpu,
        battery: builtins.battery,
        groups: builtins.groups,
        spaces: builtins.spaces,
        frontApp: builtins.frontApp,
        aerospaceMode: builtins.aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Applies a battery configuration written by its native context menu.
  func applyBatteryOverride(_ battery: Config.BatteryBuiltinConfig) {
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
        battery: battery,
        groups: builtins.groups,
        spaces: builtins.spaces,
        frontApp: builtins.frontApp,
        aerospaceMode: builtins.aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Applies a CPU configuration written by its native context menu.
  func applyCPUOverride(_ cpu: Config.CPUBuiltinConfig) {
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
        cpu: cpu,
        battery: builtins.battery,
        groups: builtins.groups,
        spaces: builtins.spaces,
        frontApp: builtins.frontApp,
        aerospaceMode: builtins.aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Applies a volume configuration written by its native context menu.
  func applyVolumeOverride(_ volume: Config.VolumeBuiltinConfig) {
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
        volume: volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Applies a front-app configuration written by its native context menu.
  func applyFrontAppOverride(_ frontApp: Config.FrontAppBuiltinConfig) {
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
        frontApp: frontApp,
        aerospaceMode: builtins.aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Applies an AeroSpace-mode configuration written by its native context menu.
  func applyAeroSpaceModeOverride(_ aerospaceMode: Config.AeroSpaceModeBuiltinConfig) {
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
        aerospaceMode: aerospaceMode,
        volume: builtins.volume,
        wifi: builtins.wifi,
        calendar: builtins.calendar,
        time: builtins.time,
        date: builtins.date
      )
    )
  }

  /// Updates one top-level native widget's enabled state after context-menu persistence.
  func applyNativeWidgetEnabledOverride(_ key: String, enabled: Bool) {
    let builtins = snapshot.builtins
    var inbox = builtins.inbox
    var cpu = builtins.cpu
    var battery = builtins.battery
    var spaces = builtins.spaces
    var frontApp = builtins.frontApp
    var aerospaceMode = builtins.aerospaceMode
    var volume = builtins.volume
    var wifi = builtins.wifi
    var calendar = builtins.calendar
    var time = builtins.time
    var date = builtins.date

    switch key {
    case "inbox": inbox.placement.enabled = enabled
    case "cpu": cpu.enabled = enabled
    case "battery": battery.enabled = enabled
    case "spaces": spaces.enabled = enabled
    case "front_app": frontApp.enabled = enabled
    case "aerospace_mode": aerospaceMode.enabled = enabled
    case "volume": volume.enabled = enabled
    case "wifi": wifi.enabled = enabled
    case "calendar": calendar.enabled = enabled
    case "time": time.placement.enabled = enabled
    case "date": date.placement.enabled = enabled
    default: return
    }

    snapshot = ConfigSnapshot(
      app: snapshot.app,
      logging: snapshot.logging,
      calendarAgent: snapshot.calendarAgent,
      networkAgent: snapshot.networkAgent,
      theme: snapshot.theme,
      bar: snapshot.bar,
      builtins: .init(
        inbox: inbox,
        cpu: cpu,
        battery: battery,
        groups: builtins.groups,
        spaces: spaces,
        frontApp: frontApp,
        aerospaceMode: aerospaceMode,
        volume: volume,
        wifi: wifi,
        calendar: calendar,
        time: time,
        date: date
      )
    )
  }
}
