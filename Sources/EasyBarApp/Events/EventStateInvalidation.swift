import EasyBarShared
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

  /// Runtime event name represented by this invalidation.
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

  /// Builds the latest payload for this invalidation.
  func currentPayload(
    wifiSnapshotProvider: @MainActor @Sendable () -> NetworkAgentSnapshot?
  ) async -> EasyBarEventPayload? {
    switch self {
    case .systemWake:
      return .app(.systemWoke)

    case .powerSourceChange:
      return .app(.powerSourceChange)

    case .chargingStateChange:
      return .app(.chargingStateChange)

    case .wifiChange:
      let interfaceName = await MainActor.run {
        wifiSnapshotProvider()?.interfaceName
      }

      if let interfaceName, !interfaceName.isEmpty {
        return .app(.wifiChange, interfaceName: interfaceName)
      }

      return .app(.wifiChange)

    case .networkChange:
      let isTunnel = await MainActor.run {
        wifiSnapshotProvider()?.primaryInterfaceIsTunnel ?? false
      }

      return .app(.networkChange, primaryInterfaceIsTunnel: isTunnel)

    case .volumeChange:
      return .app(.volumeChange)

    case .muteChange:
      return .app(.muteChange)

    case .calendarChange:
      return .app(.calendarChange)

    case .minuteTick:
      return .app(.minuteTick)

    case .secondTick:
      return .app(.secondTick)

    case .focusChange:
      return .app(.focusChange)

    case .workspaceChange:
      return .app(.workspaceChange)

    case .spaceModeChange:
      return .app(.spaceModeChange)
    }
  }
}

/// Replayable event definitions in stable invalidation order.
enum EventReplayCatalog {
  static let orderedInvalidations = EventStateInvalidation.allCases
  static let orderedEventNames = orderedInvalidations.map(\.eventName)

  static func isReplayable(_ eventName: String) -> Bool {
    orderedEventNames.contains(eventName)
  }

  static func payloads(
    for eventNames: Set<String>,
    wifiSnapshotProvider: @MainActor @Sendable () -> NetworkAgentSnapshot? = { nil }
  ) async -> [EasyBarEventPayload] {
    var payloads: [EasyBarEventPayload] = []
    for invalidation in orderedInvalidations where eventNames.contains(invalidation.eventName) {
      guard
        let payload = await invalidation.currentPayload(
          wifiSnapshotProvider: wifiSnapshotProvider
        )
      else { continue }
      payloads.append(payload)
    }
    return payloads
  }
}
