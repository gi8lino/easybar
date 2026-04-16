import Foundation
import IOKit.ps

final class PowerEvents {
  static let shared = PowerEvents()

  private var runLoopSource: Unmanaged<CFRunLoopSource>?
  private var lastChargingState: Bool?

  private init() {}

  /// Starts power-source observation for power and charging events.
  func subscribePowerSource() {
    guard runLoopSource == nil else { return }

    let callback: IOPowerSourceCallbackType = { _ in
      Task {
        await EventHub.shared.emit(.powerSourceChange)
      }

      PowerEvents.shared.handlePowerSourceCallback()
    }

    guard let source = IOPSNotificationCreateRunLoopSource(callback, nil) else {
      easybarLog.debug("failed to create power source run loop source")
      return
    }

    runLoopSource = source
    lastChargingState = readChargingState()

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      source.takeUnretainedValue(),
      .defaultMode
    )

    easybarLog.debug("subscribed power_source_change")
    easybarLog.debug("subscribed charging_state_change")
  }

  /// Stops all power-source observation.
  func stopAll() {
    guard let runLoopSource else { return }

    CFRunLoopRemoveSource(
      CFRunLoopGetCurrent(),
      runLoopSource.takeUnretainedValue(),
      .defaultMode
    )

    self.runLoopSource = nil
    self.lastChargingState = nil
  }

  /// Emits `charging_state_change` only when the effective charging state flips.
  private func handlePowerSourceCallback() {
    let newState = readChargingState()

    if lastChargingState != newState {
      lastChargingState = newState

      Task {
        await EventHub.shared.emit(.chargingStateChange, charging: newState)
      }
    }
  }

  /// Returns whether the current active power source is actively charging.
  private func readChargingState() -> Bool {
    guard
      let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else {
      return false
    }

    for source in list {
      guard
        let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
          as? [String: Any],
        (description[kIOPSIsPresentKey as String] as? Bool) == true
      else {
        continue
      }

      return (description[kIOPSIsChargingKey as String] as? Bool) ?? false
    }

    return false
  }
}
