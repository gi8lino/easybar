import AppKit
import Combine
import EasyBarShared

/// Dependencies used by the native calendar event composer panel.
struct CalendarEventComposerDependencies {
  /// Fresh composer-calendar snapshot source.
  let snapshotPublisher: AnyPublisher<CalendarAgentSnapshot?, Never>
  /// Refreshes the composer-only calendar metadata snapshot.
  let refreshSnapshots: () -> Void
  /// Creates one calendar event through the calendar agent.
  let createEvent: (CalendarAgentCreateEvent, @escaping (Bool, String?) -> Void) -> Void
  /// Updates one calendar event through the calendar agent.
  let updateEvent: (CalendarAgentUpdateEvent, @escaping (Bool, String?) -> Void) -> Void
  /// Deletes one calendar event through the calendar agent.
  let deleteEvent: (CalendarAgentDeleteEvent, @escaping (Bool, String?) -> Void) -> Void
  /// Opens the system Calendar app.
  let openCalendarApp: () -> Void

  /// Builds the production composer dependency set from shared stores and clients.
  @MainActor
  static func live() -> CalendarEventComposerDependencies {
    CalendarEventComposerDependencies(
      snapshotPublisher: NativeComposerCalendarStore.shared.$snapshot.eraseToAnyPublisher(),
      refreshSnapshots: {
        ComposerCalendarAgentClient.shared.refresh()
      },
      createEvent: { event, completion in
        MonthCalendarAgentClient.shared.createEvent(event, completion: completion)
      },
      updateEvent: { event, completion in
        MonthCalendarAgentClient.shared.updateEvent(event, completion: completion)
      },
      deleteEvent: { event, completion in
        MonthCalendarAgentClient.shared.deleteEvent(event, completion: completion)
      },
      openCalendarApp: {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
        else { return }
        NSWorkspace.shared.open(appURL)
      }
    )
  }
}
