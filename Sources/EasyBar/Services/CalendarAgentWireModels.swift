import Foundation

public struct CalendarAgentQueryEnvelope: Codable, Equatable {
  public let startDate: Date
  public let endDate: Date
  public let sectionStartDate: Date?
  public let sectionDayCount: Int?
  public let showBirthdays: Bool
  public let birthdaysShowAge: Bool
  public let birthdaysTitle: String
  public let birthdaysDateFormat: String
  public let includedCalendarNames: [String]
  public let excludedCalendarNames: [String]
  public let emptyText: String

  public init(
    startDate: Date,
    endDate: Date,
    sectionStartDate: Date?,
    sectionDayCount: Int?,
    showBirthdays: Bool,
    birthdaysShowAge: Bool,
    birthdaysTitle: String,
    birthdaysDateFormat: String,
    includedCalendarNames: [String],
    excludedCalendarNames: [String],
    emptyText: String
  ) {
    self.startDate = startDate
    self.endDate = endDate
    self.sectionStartDate = sectionStartDate
    self.sectionDayCount = sectionDayCount
    self.showBirthdays = showBirthdays
    self.birthdaysShowAge = birthdaysShowAge
    self.birthdaysTitle = birthdaysTitle
    self.birthdaysDateFormat = birthdaysDateFormat
    self.includedCalendarNames = includedCalendarNames
    self.excludedCalendarNames = excludedCalendarNames
    self.emptyText = emptyText
  }
}

public struct CalendarAgentCreateEventEnvelope: Codable, Equatable {
  public let title: String
  public let startDate: Date
  public let endDate: Date
  public let isAllDay: Bool
  public let calendarName: String?
  public let location: String?
  public let alertOffsetsSeconds: [TimeInterval]
  public let travelTimeSeconds: TimeInterval?

  public init(
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String?,
    location: String?,
    alertOffsetsSeconds: [TimeInterval] = [],
    travelTimeSeconds: TimeInterval?
  ) {
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.location = location
    self.alertOffsetsSeconds = alertOffsetsSeconds
    self.travelTimeSeconds = travelTimeSeconds
  }
}

public struct CalendarAgentUpdateEventEnvelope: Codable, Equatable {
  public let eventIdentifier: String
  public let title: String
  public let startDate: Date
  public let endDate: Date
  public let isAllDay: Bool
  public let calendarName: String?
  public let location: String?
  public let alertOffsetsSeconds: [TimeInterval]
  public let travelTimeSeconds: TimeInterval?

  public init(
    eventIdentifier: String,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String?,
    location: String?,
    alertOffsetsSeconds: [TimeInterval] = [],
    travelTimeSeconds: TimeInterval?
  ) {
    self.eventIdentifier = eventIdentifier
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.location = location
    self.alertOffsetsSeconds = alertOffsetsSeconds
    self.travelTimeSeconds = travelTimeSeconds
  }
}

public struct CalendarAgentDeleteEventEnvelope: Codable, Equatable {
  public let eventIdentifier: String

  public init(eventIdentifier: String) {
    self.eventIdentifier = eventIdentifier
  }
}

public struct CalendarAgentEvent: Codable, Equatable, Identifiable {
  public let id: String
  public let title: String
  public let startDate: Date
  public let endDate: Date
  public let isAllDay: Bool
  public let calendarName: String?
  public let calendarColorHex: String?
  public let location: String?
  public let alertOffsetsSeconds: [TimeInterval]
  public let isHoliday: Bool
  public let hasAlert: Bool
  public let travelTimeSeconds: TimeInterval?

  public init(
    id: String,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendarName: String?,
    calendarColorHex: String?,
    location: String?,
    alertOffsetsSeconds: [TimeInterval] = [],
    isHoliday: Bool = false,
    hasAlert: Bool = false,
    travelTimeSeconds: TimeInterval?
  ) {
    self.id = id
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
    self.location = location
    self.alertOffsetsSeconds = alertOffsetsSeconds
    self.isHoliday = isHoliday
    self.hasAlert = hasAlert
    self.travelTimeSeconds = travelTimeSeconds
  }
}

public enum CalendarAgentSectionKind: String, Codable, Equatable {
  case birthdays
  case today
  case tomorrow
  case future
}

public struct CalendarAgentItem: Codable, Equatable, Identifiable {
  public let id: String
  public let time: String
  public let title: String
  public let calendarName: String?
  public let calendarColorHex: String?
  public let location: String?
  public let travelTimeSeconds: TimeInterval?

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

public struct CalendarAgentSection: Codable, Equatable, Identifiable {
  public let id: String
  public let title: String
  public let kind: CalendarAgentSectionKind
  public let items: [CalendarAgentItem]

  public init(
    id: String,
    title: String,
    kind: CalendarAgentSectionKind,
    items: [CalendarAgentItem]
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.items = items
  }
}

public struct CalendarAgentSnapshot: Codable, Equatable {
  public let accessGranted: Bool
  public let permissionState: String
  public let generatedAt: Date
  public let events: [CalendarAgentEvent]
  public let sections: [CalendarAgentSection]

  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    events: [CalendarAgentEvent],
    sections: [CalendarAgentSection]
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.events = events
    self.sections = sections
  }
}

public struct CalendarAgentRequestEnvelope: Codable, Equatable {
  public let command: String
  public let query: CalendarAgentQueryEnvelope?
  public let createEvent: CalendarAgentCreateEventEnvelope?
  public let updateEvent: CalendarAgentUpdateEventEnvelope?
  public let deleteEvent: CalendarAgentDeleteEventEnvelope?

  public init(
    command: String,
    query: CalendarAgentQueryEnvelope? = nil,
    createEvent: CalendarAgentCreateEventEnvelope? = nil,
    updateEvent: CalendarAgentUpdateEventEnvelope? = nil,
    deleteEvent: CalendarAgentDeleteEventEnvelope? = nil
  ) {
    self.command = command
    self.query = query
    self.createEvent = createEvent
    self.updateEvent = updateEvent
    self.deleteEvent = deleteEvent
  }
}

public struct CalendarAgentResponseEnvelope: Codable, Equatable {
  public let kind: String
  public let message: String?
  public let snapshot: CalendarAgentSnapshot?

  public init(
    kind: String,
    message: String? = nil,
    snapshot: CalendarAgentSnapshot? = nil
  ) {
    self.kind = kind
    self.message = message
    self.snapshot = snapshot
  }
}
