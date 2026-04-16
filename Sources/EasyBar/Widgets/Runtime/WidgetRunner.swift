import Foundation

/// Compatibility façade around the actor-based widget engine.
///
/// Existing call sites can continue using `WidgetRunner.shared` while the real
/// ownership has moved to `WidgetEngine`.
final class WidgetRunner {
  static let shared = WidgetRunner()

  private init() {}

  /// Starts the widget runtime.
  func start() {
    Task {
      await WidgetEngine.shared.start()
    }
  }

  /// Reloads the widget runtime.
  func reload() {
    Task {
      await WidgetEngine.shared.reload()
    }
  }

  /// Stops the widget runtime.
  func shutdown() {
    Task {
      await WidgetEngine.shared.shutdown()
    }
  }
}
