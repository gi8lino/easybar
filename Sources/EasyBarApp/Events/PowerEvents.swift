import EasyBarShared
import Foundation
import IOKit.ps

/// Observes macOS power source changes.
final class PowerEvents {
  /// Configured shared power event source.
  private static var sharedInstance: PowerEvents?

  /// Returns the configured shared power event source.
  static var shared: PowerEvents {
    guard let sharedInstance else {
      fatalError("PowerEvents.bootstrap(logger:) must be called before PowerEvents.shared")
    }

    return sharedInstance
  }

  /// Configures the shared power event source.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = PowerEvents(logger: logger)
  }

  /// Logger used for power diagnostics.
  private let logger: ProcessLogger

  /// IOKit run-loop source for power notifications.
  private var runLoopSource: Unmanaged<CFRunLoopSource>?
  /// Last emitted charging state.
  private var lastChargingState: Bool?

  /// Creates one power event source.
  private init(logger: ProcessLogger) {
    self.logger = logger
  }

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
      logger.debug("failed to create power source run loop source")
      return
    }

    runLoopSource = source
    lastChargingState = readChargingState()

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      source.takeUnretainedValue(),
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
