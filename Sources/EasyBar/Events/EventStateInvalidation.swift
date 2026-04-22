import Foundation

/// Replayable invalidation signals backed by current app state providers.
enum EventStateInvalidation: CaseIterable {
  case systemWake
  case powerSourceChange
  case chargingStateChange
  case wifiChange
  case networkChange
  case volumeChange
  case muteChange
  case calendarChange
  case minuteTick
  case secondTick
  case focusChange
  case workspaceChange
  case spaceModeChange

  typealias Provider = @Sendable () async -> EasyBarEventPayload?

  var eventName: String {
    switch self {
    case .systemWake: return AppEvent.systemWoke.rawValue
    case .powerSourceChange: return AppEvent.powerSourceChange.rawValue
    case .chargingStateChange: return AppEvent.chargingStateChange.rawValue
    case .wifiChange: return AppEvent.wifiChange.rawValue
    case .networkChange: return AppEvent.networkChange.rawValue
    case .volumeChange: return AppEvent.volumeChange.rawValue
    case .muteChange: return AppEvent.muteChange.rawValue
    case .calendarChange: return AppEvent.calendarChange.rawValue
    case .minuteTick: return AppEvent.minuteTick.rawValue
    case .secondTick: return AppEvent.secondTick.rawValue
    case .focusChange: return AppEvent.focusChange.rawValue
    case .workspaceChange: return AppEvent.workspaceChange.rawValue
    case .spaceModeChange: return AppEvent.spaceModeChange.rawValue
    }
  }

  var provider: Provider {
    switch self {
    case .systemWake:
      return { .app(.systemWoke) }
    case .powerSourceChange:
      return { .app(.powerSourceChange) }
    case .chargingStateChange:
      return { .app(.chargingStateChange) }
    case .wifiChange:
      return {
        let interfaceName = await MainActor.run {
          NativeWiFiStore.shared.snapshot?.interfaceName
        }

        if let interfaceName, !interfaceName.isEmpty {
          return .app(.wifiChange, interfaceName: interfaceName)
        }

        return .app(.wifiChange)
      }
    case .networkChange:
      return {
        let isTunnel = await MainActor.run {
          NativeWiFiStore.shared.snapshot?.primaryInterfaceIsTunnel ?? false
        }

        return .app(.networkChange, primaryInterfaceIsTunnel: isTunnel)
      }
    case .volumeChange:
      return { .app(.volumeChange) }
    case .muteChange:
      return { .app(.muteChange) }
    case .calendarChange:
      return { .app(.calendarChange) }
    case .minuteTick:
      return { .app(.minuteTick) }
    case .secondTick:
      return { .app(.secondTick) }
    case .focusChange:
      return { .app(.focusChange) }
    case .workspaceChange:
      return { .app(.workspaceChange) }
    case .spaceModeChange:
      return { .app(.spaceModeChange) }
    }
  }
}
