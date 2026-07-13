import EasyBarShared
import Foundation

/// Publishes network-agent snapshots into app state and emits matching runtime events.
final class NetworkAgentSnapshotPublisher: @unchecked Sendable {
  /// Returns whether asynchronous publish work should still apply.
  private let isActive: () -> Bool

  /// Creates one network-agent snapshot publisher.
  init(isActive: @escaping () -> Bool = { true }) {
    self.isActive = isActive
  }

  /// Clears the shared Wi-Fi state and optionally emits the corresponding app events.
  func clear(notify: Bool) {
    Task { @MainActor in
      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.clear()

      guard changed else { return }
      guard notify else { return }

      Task {
        await EventHub.shared.emit(
          .networkChange,
          primaryInterfaceIsTunnel: false
        )

        if self.shouldEmitWiFiChangeAfterReset(previous: previous) {
          await EventHub.shared.emit(.wifiChange)
        }
      }
    }
  }

  /// Publishes one snapshot to the shared store on the main queue and emits app events.
  func publish(snapshot: NetworkAgentSnapshot) {
    Task { @MainActor in
      guard self.isActive() else { return }

      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.apply(snapshot: snapshot)

      guard changed else { return }

      Task {
        await EventHub.shared.emit(
          .networkChange,
          primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel
        )

        let ssidChanged = previous?.ssid != snapshot.ssid
        let interfaceChanged = previous?.interfaceName != snapshot.interfaceName

        guard ssidChanged || interfaceChanged else { return }

        if let interfaceName = snapshot.interfaceName, !interfaceName.isEmpty {
          await EventHub.shared.emit(.wifiChange, interfaceName: interfaceName)
        } else {
          await EventHub.shared.emit(.wifiChange)
        }
      }
    }
  }

  /// Returns whether clearing the published state should also emit a Wi-Fi change event.
  private func shouldEmitWiFiChangeAfterReset(previous: NetworkAgentSnapshot?) -> Bool {
    return previous?.ssid != nil || previous?.interfaceName != nil
  }
}
