import Foundation

@MainActor
protocol NativeWidget: AnyObject {
  var rootID: String { get }
  var appEventSubscriptions: Set<String> { get }
  /// Handles start.
  func start()
  /// Handles stop.
  func stop()
  /// Reloads configuration.
  func reload()
}

extension NativeWidget {
  var appEventSubscriptions: Set<String> {
    []
  }

  /// Reloads configuration.
  func reload() {
    stop()
    start()
  }
}
