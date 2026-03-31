import Foundation

/// Backward-compatible shim for the regular calendar popup client.
///
/// The actual implementation now lives in `UpcomingCalendarAgentClient`.
final class CalendarAgentClient {

  static let shared = CalendarAgentClient()

  private init() {}

  /// Returns whether the underlying upcoming-calendar agent client is connected.
  var isConnected: Bool {
    UpcomingCalendarAgentClient.shared.isConnected
  }

  /// Starts the underlying upcoming-calendar agent client.
  func start() {
    UpcomingCalendarAgentClient.shared.start()
  }

  /// Stops the underlying upcoming-calendar agent client.
  func stop() {
    UpcomingCalendarAgentClient.shared.stop()
  }

  /// Requests one fresh calendar snapshot.
  func refresh() {
    UpcomingCalendarAgentClient.shared.refresh()
  }
}
