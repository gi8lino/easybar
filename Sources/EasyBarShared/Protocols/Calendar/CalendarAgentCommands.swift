import Foundation

public enum CalendarAgentErrorCode: String, Codable, Equatable, Sendable {
  case accessDenied = "access_denied"
  case invalidDateRange = "invalid_date_range"
  case eventNotFound = "event_not_found"
  case noWritableCalendar = "no_writable_calendar"
  case missingQuery = "missing_query"
  case missingCreateEvent = "missing_create_event"
  case missingUpdateEvent = "missing_update_event"
  case missingDeleteEvent = "missing_delete_event"
  case unknown = "unknown"
}

/// Calendar-agent protocol capabilities advertised by the server.
public struct CalendarAgentCapabilities: Codable, Equatable, Sendable {
  /// Whether live subscriptions are supported.
  public var supportsSubscriptions: Bool
  /// Whether create/update/delete event mutations are supported.
  public var supportsEventMutation: Bool
  /// Whether writable calendars are returned in snapshots.
  public var supportsWritableCalendars: Bool
  /// Whether typed wire-level error codes are supported.
  public var supportsStructuredErrors: Bool

  /// Creates one calendar-agent capabilities payload.
  public init(
    supportsSubscriptions: Bool,
    supportsEventMutation: Bool,
    supportsWritableCalendars: Bool,
    supportsStructuredErrors: Bool
  ) {
    self.supportsSubscriptions = supportsSubscriptions
    self.supportsEventMutation = supportsEventMutation
    self.supportsWritableCalendars = supportsWritableCalendars
    self.supportsStructuredErrors = supportsStructuredErrors
  }

  /// Default capabilities for the current calendar agent.
  public static let `default` = CalendarAgentCapabilities(
    supportsSubscriptions: true,
    supportsEventMutation: true,
    supportsWritableCalendars: true,
    supportsStructuredErrors: true
  )
}

/// Commands supported by the calendar agent socket.
public enum CalendarAgentCommand: String, Codable, Sendable {
  case ping
  case version
  case fetch
  case subscribe
  case createEvent = "create_event"
  case updateEvent = "update_event"
  case deleteEvent = "delete_event"
}

/// Query payload that shapes one calendar snapshot request.
