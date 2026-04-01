import Foundation

/// Commands supported by the calendar agent socket.
public enum CalendarAgentCommand: String, Codable {
  case ping
  case fetch
  case subscribe
  case createEvent = "create_event"
  case updateEvent = "update_event"
  case deleteEvent = "delete_event"
}

/// Query payload that shapes one calendar snapshot request.
public struct CalendarAgentQuery: Codable, Equatable {
  /// Inclusive fetch start date.
  public var startDate: Date
  /// Exclusive fetch end date.
  public var endDate: Date
  /// Optional section start date used for the regular calendar popup.
  public var sectionStartDate: Date?
  /// Optional number of section days used for the regular calendar popup.
  public var sectionDayCount: Int?
  /// Whether birthdays should be included.
  public var showBirthdays: Bool
  /// Text shown when no events are available.
  public var emptyText: String
  /// Title used for the birthdays section.
  public var birthdaysTitle: String
  /// Date format used for birthday rows.
  public var birthdaysDateFormat: String
  /// Whether birthday ages should be shown.
  public var birthdaysShowAge: Bool
  /// Optional allowlist of calendar names. Empty means all calendars.
  public var includedCalendarNames: [String]
  /// Optional denylist of calendar names.
  public var excludedCalendarNames: [String]

  /// Creates one calendar agent query.
  public init(
    startDate: Date,
    endDate: Date,
    sectionStartDate: Date? = nil,
    sectionDayCount: Int? = nil,
    showBirthdays: Bool,
    emptyText: String,
    birthdaysTitle: String,
    birthdaysDateFormat: String,
    birthdaysShowAge: Bool,
    includedCalendarNames: [String] = [],
    excludedCalendarNames: [String] = []
  ) {
    self.startDate = startDate
    self.endDate = endDate
    self.sectionStartDate = sectionStartDate
    self.sectionDayCount = sectionDayCount
    self.showBirthdays = showBirthdays
    self.emptyText = emptyText
    self.birthdaysTitle = birthdaysTitle
    self.birthdaysDateFormat = birthdaysDateFormat
    self.birthdaysShowAge = birthdaysShowAge
    self.includedCalendarNames = includedCalendarNames
    self.excludedCalendarNames = excludedCalendarNames
  }
}

/// One create-event payload sent to the calendar agent.
public struct CalendarAgentCreateEvent: Codable, Equatable {
  /// Event title.
  public var title: String
  /// Event start date.
  public var startDate: Date
  /// Event end date.
  public var endDate: Date
  /// Whether the event is all day.
  public var isAllDay: Bool
  /// Optional calendar name to create the event in.
  public var calendarName: String?
  /// Optional event location.
  public var location: String?
  /// Optional alert lead time in seconds before the event.
  public var alertOffsetSeconds: TimeInterval?
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one calendar agent create-event payload.
  public init(
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String? = nil,
    location: String? = nil,
    alertOffsetSeconds: TimeInterval? = nil,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.location = location
    self.alertOffsetSeconds = alertOffsetSeconds
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One update-event payload sent to the calendar agent.
public struct CalendarAgentUpdateEvent: Codable, Equatable {
  /// Stable EventKit event identifier.
  public var eventIdentifier: String
  /// Updated event title.
  public var title: String
  /// Updated event start date.
  public var startDate: Date
  /// Updated event end date.
  public var endDate: Date
  /// Whether the event is all day.
  public var isAllDay: Bool
  /// Optional calendar name to move the event to.
  public var calendarName: String?
  /// Optional event location.
  public var location: String?
  /// Optional alert lead time in seconds before the event.
  public var alertOffsetSeconds: TimeInterval?
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one calendar agent update-event payload.
  public init(
    eventIdentifier: String,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String? = nil,
    location: String? = nil,
    alertOffsetSeconds: TimeInterval? = nil,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.eventIdentifier = eventIdentifier
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.location = location
    self.alertOffsetSeconds = alertOffsetSeconds
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One delete-event payload sent to the calendar agent.
public struct CalendarAgentDeleteEvent: Codable, Equatable {
  /// Stable EventKit event identifier.
  public var eventIdentifier: String

  /// Creates one calendar agent delete-event payload.
  public init(eventIdentifier: String) {
    self.eventIdentifier = eventIdentifier
  }
}

/// One request sent to the calendar agent.
public struct CalendarAgentRequest: Codable {
  /// Command to execute on the agent.
  public var command: CalendarAgentCommand
  /// Optional query used for fetch and subscribe requests.
  public var query: CalendarAgentQuery?
  /// Optional create-event payload used for event creation.
  public var createEvent: CalendarAgentCreateEvent?
  /// Optional update-event payload used for event updates.
  public var updateEvent: CalendarAgentUpdateEvent?
  /// Optional delete-event payload used for event deletion.
  public var deleteEvent: CalendarAgentDeleteEvent?

  /// Creates one calendar agent request.
  public init(
    command: CalendarAgentCommand,
    query: CalendarAgentQuery? = nil,
    createEvent: CalendarAgentCreateEvent? = nil,
    updateEvent: CalendarAgentUpdateEvent? = nil,
    deleteEvent: CalendarAgentDeleteEvent? = nil
  ) {
    self.command = command
    self.query = query
    self.createEvent = createEvent
    self.updateEvent = updateEvent
    self.deleteEvent = deleteEvent
  }
}

/// One writable calendar returned by the agent for the composer.
public struct CalendarAgentWritableCalendar: Codable, Identifiable, Equatable {
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
public enum CalendarAgentSectionKind: String, Codable, Equatable {
  case birthdays
  case today
  case tomorrow
  case future
}

/// One normalized calendar event returned by the agent.
public struct CalendarAgentEvent: Codable, Identifiable, Equatable {
  /// Stable event identifier.
  public var id: String
  /// Event title.
  public var title: String
  /// Event start date.
  public var startDate: Date
  /// Event end date.
  public var endDate: Date
  /// Whether the event is all day.
  public var isAllDay: Bool
  /// Optional source calendar name.
  public var calendarName: String?
  /// Optional source calendar color.
  public var calendarColorHex: String?
  /// Optional event location.
  public var location: String?
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one normalized calendar event.
  public init(
    id: String,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String? = nil,
    calendarColorHex: String? = nil,
    location: String? = nil,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.id = id
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
    self.location = location
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One rendered event or birthday row in a calendar section.
public struct CalendarAgentItem: Codable, Identifiable, Equatable {
  /// Stable item identifier.
  public var id: String
  /// Leading time or date label.
  public var time: String
  /// Main row title.
  public var title: String
  /// Optional source calendar name.
  public var calendarName: String?
  /// Optional source calendar color.
  public var calendarColorHex: String?
  /// Optional event location.
  public var location: String?
  /// Optional travel time in seconds.
  public var travelTimeSeconds: TimeInterval?

  /// Creates one calendar section item.
  public init(
    id: String,
    time: String,
    title: String,
    calendarName: String? = nil,
    calendarColorHex: String? = nil,
    location: String? = nil,
    travelTimeSeconds: TimeInterval? = nil
  ) {
    self.id = id
    self.time = time
    self.title = title
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
    self.location = location
    self.travelTimeSeconds = travelTimeSeconds
  }
}

/// One logical section in a calendar snapshot.
public struct CalendarAgentSection: Codable, Identifiable, Equatable {
  /// Stable section identifier.
  public var id: String
  /// User-visible section title.
  public var title: String
  /// Semantic section kind.
  public var kind: CalendarAgentSectionKind
  /// Rows rendered in this section.
  public var items: [CalendarAgentItem]

  /// Creates one calendar snapshot section.
  public init(id: String, title: String, kind: CalendarAgentSectionKind, items: [CalendarAgentItem])
  {
    self.id = id
    self.title = title
    self.kind = kind
    self.items = items
  }
}

/// Full calendar snapshot returned by the agent.
public struct CalendarAgentSnapshot: Codable, Equatable {
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
public enum CalendarAgentMessageKind: String, Codable {
  case pong
  case subscribed
  case snapshot
  case created
  case updated
  case deleted
  case error
}

/// One message sent over the calendar agent socket.
public struct CalendarAgentMessage: Codable {
  /// Message kind discriminator.
  public var kind: CalendarAgentMessageKind
  /// Optional snapshot payload.
  public var snapshot: CalendarAgentSnapshot?
  /// Optional error message.
  public var message: String?

  /// Creates one calendar agent message.
  public init(
    kind: CalendarAgentMessageKind,
    snapshot: CalendarAgentSnapshot? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.snapshot = snapshot
    self.message = message
  }
}
