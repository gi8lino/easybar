import EasyBarShared
import Foundation
import IOKit.ps

/// Observes macOS power source changes.
final class PowerEvents {
  /// Shared power event source.
  static var shared = PowerEvents(
    logger: ProcessLogger(label: "easybar.bootstrap.power_events")
  )

  /// Logger used for power diagnostics.
  private let logger: ProcessLogger

  /// IOKit run-loop source for power notifications.
  private var runLoopSource: CFRunLoopSource?
  /// Last emitted charging state.
  private var lastChargingState: Bool?

  /// Creates one power event source.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Starts power-source observation for power and charging events.
  func subscribePowerSource() {
    guard runLoopSource == nil else { return }

    let callback: IOPowerSourceCallbackType = { context in
      Task {
        await EventHub.shared.emit(.powerSourceChange)
      }

      guard let context else { return }
      let owner = Unmanaged<PowerEvents>.fromOpaque(context).takeUnretainedValue()
      owner.handlePowerSourceCallback()
    }

    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue()
    else {
      logger.debug("failed to create power source run loop source")
      return
    }

    runLoopSource = source
    lastChargingState = readChargingState()

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      source,
      .defaultMode
    )

    logger.debug("subscribed power_source_change")
    logger.debug("subscribed charging_state_change")
  }

  /// Stops observation for power and charging events.
  func unsubscribePowerSource() {
    stopAll()
  }

  /// Stops all power-source observation.
  func stopAll() {
    guard let runLoopSource else { return }

    CFRunLoopRemoveSource(
      CFRunLoopGetCurrent(),
      runLoopSource,
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
