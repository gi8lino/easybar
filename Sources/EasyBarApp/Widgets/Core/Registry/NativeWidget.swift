import Foundation

/// Lifecycle contract implemented by all native widgets.
@MainActor
protocol NativeWidget: AnyObject {
  var rootID: String { get }
  var appEventSubscriptions: Set<String> { get }
  /// Starts the widget.
  func start()
  /// Stops the widget and clears rendered state.
  func stop()
  /// Reloads configuration.
  func reload()
}

extension NativeWidget {
  var appEventSubscriptions: Set<String> {
    return []
  }

  /// Reloads configuration.
  func reload() {
    stop()
    start()
  }
}
