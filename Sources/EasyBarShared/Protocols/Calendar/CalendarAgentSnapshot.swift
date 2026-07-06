import Foundation

/// One writable calendar returned by the agent for the composer.
public struct CalendarAgentWritableCalendar: Codable, Identifiable, Equatable, Sendable {
  /// Stable calendar identifier.
  public var id: String
  /// User-visible calendar title.
  public var title: String

  /// Creates one writable calendar entry.
  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

/// Section kinds returned by the calendar agent snapshot.
public enum CalendarAgentSectionKind: String, Codable, Equatable, Sendable {
  case birthdays
  case today
  case tomorrow
  case future
}

/// One normalized calendar event returned by the agent.
public struct CalendarAgentEvent: Codable, Identifiable, Equatable, Sendable {
  /// Stable UI identifier for this event row or occurrence.
  public var id: String
  /// Stable EventKit event identifier used for mutation APIs when available.
  public var eventIdentifier: String?
  /// Event title.
  public var title: String
  /// Event start date.
  public var startDate: Date
  /// Event end date.
  public var endDate: Date
  /// Whether the event is all day.
  public var isAllDay: Bool
  /// Stable source calendar identifier.
  public var calendarID: String?
  /// Optional source calendar name.
  public var calendarName: String?
  /// Optional source calendar color.
  public var calendarColorHex: String?
  /// Optional event location.
  public var location: String?
  /// Optional URL attached to the event.
  public var url: String?
  /// Visible non-travel alert lead times in seconds before the event.
  public var alertOffsetsSeconds: [TimeInterval]
  /// Whether the event belongs to a holiday calendar.
  public var isHoliday: Bool
  /// Whether the event has at least one visible non-travel alert.
  public var hasAlert: Bool
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one normalized calendar event.
  public init(
    id: String,
    eventIdentifier: String? = nil,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarID: String? = nil,
    calendarName: String? = nil,
    calendarColorHex: String? = nil,
    location: String? = nil,
    url: String? = nil,
    alertOffsetsSeconds: [TimeInterval] = [],
    isHoliday: Bool = false,
    hasAlert: Bool = false,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.id = id
    self.eventIdentifier = eventIdentifier
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarID = calendarID
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
    self.location = location
    self.url = url
    self.alertOffsetsSeconds = alertOffsetsSeconds
    self.isHoliday = isHoliday
    self.hasAlert = hasAlert
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One rendered event or birthday row in a calendar section.
public struct CalendarAgentItem: Codable, Identifiable, Equatable, Sendable {
  /// Stable item identifier.
  public var id: String
  /// Leading time or date label.
  public var time: String
  /// Optional original event start date.
  public var startDate: Date?
  /// Optional original event end date.
  public var endDate: Date?
  /// Whether the source event is all day.
  public var isAllDay: Bool
  /// Optional rendered end-time label for timed events.
  public var endTime: String?
  /// Main row title.
  public var title: String
  /// Optional source calendar name.
  public var calendarName: String?
  /// Optional source calendar color.
  public var calendarColorHex: String?
  /// Optional event location.
  public var location: String?
  /// Optional URL attached to the event.
  public var url: String?
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one calendar section item.
  public init(
    id: String,
    time: String,
    startDate: Date? = nil,
    endDate: Date? = nil,
    isAllDay: Bool = false,
    endTime: String? = nil,
    title: String,
    calendarName: String? = nil,
    calendarColorHex: String? = nil,
    location: String? = nil,
    url: String? = nil,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.id = id
    self.time = time
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.endTime = endTime
    self.title = title
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
    self.location = location
    self.url = url
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One logical section in a calendar snapshot.
public struct CalendarAgentSection: Codable, Identifiable, Equatable, Sendable {
  /// Stable section identifier.
  public var id: String
  /// User-visible section title.
  public var title: String
  /// Semantic section kind.
  public var kind: CalendarAgentSectionKind
  /// Rows rendered in this section.
  public var items: [CalendarAgentItem]

  /// Creates one calendar snapshot section.
  public init(id: String, title: String, kind: CalendarAgentSectionKind, items: [CalendarAgentItem]) {
    self.id = id
    self.title = title
    self.kind = kind
    self.items = items
  }
}

/// Full calendar snapshot returned by the agent.
public struct CalendarAgentSnapshot: Codable, Equatable, Sendable {
  /// Whether calendar access is currently granted.
  public var accessGranted: Bool
  /// Current calendar permission state string.
  public var permissionState: String
  /// Snapshot generation time.
  public var generatedAt: Date
  /// Writable non-birthday calendars available for create and update operations.
  public var writableCalendars: [CalendarAgentWritableCalendar]
  /// Normalized events included in the snapshot window.
  public var events: [CalendarAgentEvent]
  /// Optional rendered sections for simpler consumers.
  public var sections: [CalendarAgentSection]

  /// Creates one calendar snapshot payload.
  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    writableCalendars: [CalendarAgentWritableCalendar],
    events: [CalendarAgentEvent],
    sections: [CalendarAgentSection]
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.writableCalendars = writableCalendars
    self.events = events
    self.sections = sections
  }
}

/// Message kinds sent by the calendar agent.
