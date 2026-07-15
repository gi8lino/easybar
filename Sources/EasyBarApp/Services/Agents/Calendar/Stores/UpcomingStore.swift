import EasyBarCalendarUI
import EasyBarShared
import Foundation

/// Shared upcoming-calendar snapshot store used by the native upcoming popup.
@MainActor
final class NativeUpcomingCalendarStore: CalendarUpcomingPopupStore {
  static var shared = NativeUpcomingCalendarStore(
    logger: ProcessLogger(label: "easybar.bootstrap.upcoming_store")
  )

  @Published private(set) var snapshot: EasyBarShared.CalendarAgentSnapshot?
  @Published private(set) var events: [EasyBarShared.CalendarAgentEvent] = []

  let logger: ProcessLogger

  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: EasyBarShared.CalendarAgentSnapshot) {
    logger.debug(
      "upcoming calendar popup applied snapshot",
      .field("access_granted", "\(snapshot.accessGranted)"),
      .field("permission_state", "\(snapshot.permissionState)"),
      .field("events", "\(snapshot.events.count)"),
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    logger.debug("upcoming calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Publishes one calendar snapshot update.
  private func publish(snapshot: EasyBarShared.CalendarAgentSnapshot?) {
    self.snapshot = snapshot
    self.events = snapshot?.events ?? []

    logger.debug(
      "upcoming calendar store published",
      .field("snapshot_present", "\(snapshot != nil)"),
      .field("events", "\(self.events.count)"),
    )
  }
}
