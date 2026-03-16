import Foundation

enum NativeCalendarPopupSectionKind: Equatable {
    case birthdays
    case today
    case tomorrow
    case future
}

struct NativeCalendarPopupSection: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: NativeCalendarPopupSectionKind
    let items: [NativeCalendarPopupItem]
}

struct NativeCalendarPopupItem: Identifiable, Equatable {
    let id: String
    let time: String
    let title: String
}
