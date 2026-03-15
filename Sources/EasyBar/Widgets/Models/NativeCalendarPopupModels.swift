import Foundation

struct NativeCalendarPopupSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [NativeCalendarPopupItem]
}

struct NativeCalendarPopupItem: Identifiable, Equatable {
    let id: String
    let time: String
    let title: String
}
