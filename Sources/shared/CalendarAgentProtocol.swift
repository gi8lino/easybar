import Foundation

public enum CalendarAgentCommand: String, Codable {
    case ping
    case fetch
    case subscribe
}

public struct CalendarAgentQuery: Codable, Equatable {
    public var days: Int
    public var showBirthdays: Bool
    public var emptyText: String
    public var birthdaysTitle: String
    public var birthdaysDateFormat: String
    public var birthdaysShowAge: Bool

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

public struct CalendarAgentRequest: Codable {
    public var command: CalendarAgentCommand
    public var query: CalendarAgentQuery?

    public init(command: CalendarAgentCommand, query: CalendarAgentQuery? = nil) {
        self.command = command
        self.query = query
    }
}

public enum CalendarAgentSectionKind: String, Codable, Equatable {
    case birthdays
    case today
    case tomorrow
    case future
}

public struct CalendarAgentItem: Codable, Identifiable, Equatable {
    public var id: String
    public var time: String
    public var title: String
    public var calendarName: String?
    public var calendarColorHex: String?

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

public struct CalendarAgentSection: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var kind: CalendarAgentSectionKind
    public var items: [CalendarAgentItem]

    public init(id: String, title: String, kind: CalendarAgentSectionKind, items: [CalendarAgentItem]) {
        self.id = id
        self.title = title
        self.kind = kind
        self.items = items
    }
}

public struct CalendarAgentSnapshot: Codable, Equatable {
    public var accessGranted: Bool
    public var permissionState: String
    public var generatedAt: Date
    public var sections: [CalendarAgentSection]

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

public enum CalendarAgentMessageKind: String, Codable {
    case pong
    case subscribed
    case snapshot
    case error
}

public struct CalendarAgentMessage: Codable {
    public var kind: CalendarAgentMessageKind
    public var snapshot: CalendarAgentSnapshot?
    public var message: String?

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
