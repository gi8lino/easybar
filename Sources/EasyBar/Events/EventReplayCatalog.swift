import Foundation

/// Replayable event definitions for new subscribers and runtime startup refreshes.
enum EventReplayCatalog {
  typealias Provider = @Sendable () async -> EasyBarEventPayload?

  static let orderedEventNames: [String] = [
    AppEvent.systemWoke.rawValue,
    AppEvent.powerSourceChange.rawValue,
    AppEvent.chargingStateChange.rawValue,
    AppEvent.wifiChange.rawValue,
    AppEvent.networkChange.rawValue,
    AppEvent.volumeChange.rawValue,
    AppEvent.muteChange.rawValue,
    AppEvent.calendarChange.rawValue,
    AppEvent.minuteTick.rawValue,
    AppEvent.secondTick.rawValue,
    AppEvent.focusChange.rawValue,
    AppEvent.workspaceChange.rawValue,
    AppEvent.spaceModeChange.rawValue,
  ]

  private static let providers: [String: Provider] = [
    AppEvent.systemWoke.rawValue: {
      .app(.systemWoke)
    },
    AppEvent.powerSourceChange.rawValue: {
      .app(.powerSourceChange)
    },
    AppEvent.chargingStateChange.rawValue: {
      .app(.chargingStateChange)
    },
    AppEvent.wifiChange.rawValue: {
      let interfaceName = await MainActor.run {
        NativeWiFiStore.shared.snapshot?.interfaceName
      }

      if let interfaceName, !interfaceName.isEmpty {
        return .app(.wifiChange, interfaceName: interfaceName)
      }

      return .app(.wifiChange)
    },
    AppEvent.networkChange.rawValue: {
      let isTunnel = await MainActor.run {
        NativeWiFiStore.shared.snapshot?.primaryInterfaceIsTunnel ?? false
      }

      return .app(.networkChange, primaryInterfaceIsTunnel: isTunnel)
    },
    AppEvent.volumeChange.rawValue: {
      .app(.volumeChange)
    },
    AppEvent.muteChange.rawValue: {
      .app(.muteChange)
    },
    AppEvent.calendarChange.rawValue: {
      .app(.calendarChange)
    },
    AppEvent.minuteTick.rawValue: {
      .app(.minuteTick)
    },
    AppEvent.secondTick.rawValue: {
      .app(.secondTick)
    },
    AppEvent.focusChange.rawValue: {
      .app(.focusChange)
    },
    AppEvent.workspaceChange.rawValue: {
      .app(.workspaceChange)
    },
    AppEvent.spaceModeChange.rawValue: {
      .app(.spaceModeChange)
    },
  ]

  /// Returns whether the given event name participates in replay caching.
  static func isReplayable(_ eventName: String) -> Bool {
    providers[eventName] != nil
  }

  /// Returns replayable payloads for the requested event names in stable order.
  static func payloads(for eventNames: Set<String>) async -> [EasyBarEventPayload] {
    var payloads: [EasyBarEventPayload] = []

    for eventName in orderedEventNames where eventNames.contains(eventName) {
      guard let provider = providers[eventName] else { continue }
      guard let payload = await provider() else { continue }
      payloads.append(payload)
    }

    return payloads
  }
}
