import EasyBarShared
import Foundation

/// Host-provided quick actions shown for calendar appointment rows.
public struct CalendarEventActions {
  /// Copies a user-facing summary of one appointment.
  public let copyDetails: ((CalendarAgentEvent) -> Void)?
  /// Opens an attached event URL when the appointment has one.
  public let openURL: ((CalendarAgentEvent) -> Void)?
  /// Opens the system Calendar application.
  public let openCalendar: ((CalendarAgentEvent) -> Void)?

  /// Creates one action set for appointment quick actions.
  public init(
    copyDetails: ((CalendarAgentEvent) -> Void)? = nil,
    openURL: ((CalendarAgentEvent) -> Void)? = nil,
    openCalendar: ((CalendarAgentEvent) -> Void)? = nil
  ) {
    self.copyDetails = copyDetails
    self.openURL = openURL
    self.openCalendar = openCalendar
  }

  /// Returns whether at least one non-edit action can be shown for the event.
  public func hasVisibleAction(for event: CalendarAgentEvent) -> Bool {
    copyDetails != nil
      || openCalendar != nil
      || (openURL != nil && event.hasUsableURL)
  }
}

extension CalendarAgentEvent {
  /// Returns whether the event has a non-empty URL string.
  var hasUsableURL: Bool {
    guard let url else { return false }

    return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Returns the menu title for opening the event URL.
  var urlActionTitle: String {
    hasMeetingURL ? "Join Meeting" : "Open URL"
  }

  /// Returns whether the event URL looks like a video-meeting link.
  private var hasMeetingURL: Bool {
    guard let url = url?.lowercased() else { return false }

    return [
      "zoom.us",
      "meet.google.com",
      "teams.microsoft.com",
      "webex.com",
      "whereby.com",
      "jitsi",
      "gotomeeting.com",
      "bluejeans.com",
    ].contains { url.contains($0) }
  }
}
