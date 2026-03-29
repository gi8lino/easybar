import Foundation

/// Commands supported by the calendar agent socket.
public enum CalendarAgentCommand: String, Codable {
  case ping
  case fetch
  case subscribe
}

/// Query payload that shapes one calendar snapshot request.
public struct CalendarAgentQuery: Codable, Equatable {
  /// Number of days to include in the snapshot.
  public var days: Int
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

  /// Creates one calendar agent query.
  public init(
    days: Int,
    showBirthdays: Bool,
    emptyText: String,
    birthdaysTitle: String,
    birthdaysDateFormat: String,
    birthdaysShowAge: Bool
  ) {
    self.days = days
    self.showBirthdays = showBirthdays
    self.emptyText = emptyText
    self.birthdaysTitle = birthdaysTitle
    self.birthdaysDateFormat = birthdaysDateFormat
    self.birthdaysShowAge = birthdaysShowAge
  }
}

/// One request sent to the calendar agent.
public struct CalendarAgentRequest: Codable {
  /// Command to execute on the agent.
  public var command: CalendarAgentCommand
  /// Optional query used for fetch and subscribe requests.
  public var query: CalendarAgentQuery?

  /// Creates one calendar agent request.
  public init(command: CalendarAgentCommand, query: CalendarAgentQuery? = nil) {
    self.command = command
    self.query = query
  }
}

/// Section kinds returned by the calendar agent snapshot.
public enum CalendarAgentSectionKind: String, Codable, Equatable {
  case birthdays
  case today
  case tomorrow
  case future
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

  /// Creates one calendar section item.
  public init(
    id: String,
    time: String,
    title: String,
    calendarName: String? = nil,
    calendarColorHex: String? = nil
  ) {
    self.id = id
    self.time = time
    self.title = title
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
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
  /// Sections included in the snapshot.
  public var sections: [CalendarAgentSection]

  /// Creates one calendar snapshot payload.
  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    sections: [CalendarAgentSection]
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.sections = sections
  }
}

/// Message kinds sent by the calendar agent.
public enum CalendarAgentMessageKind: String, Codable {
  case pong
  case subscribed
  case snapshot
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
