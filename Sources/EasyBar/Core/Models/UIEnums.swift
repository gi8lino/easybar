import Foundation

/// Fixed placement used by bar widgets and nodes.
enum WidgetPosition: String, Codable, CaseIterable {
    case left
    case center
    case right
}

/// Fixed node kinds rendered by SwiftUI.
enum WidgetNodeKind: String, Codable {
    case item
    case row
    case column
    case group
    case popup
    case slider
    case progressSlider = "progress_slider"
    case progress
    case sparkline
    case spaces
}

/// Internal role markers for special child nodes.
enum WidgetNodeRole: String, Codable {
    case popupAnchor = "popup-anchor"
}

/// Supported layouts for the native calendar anchor.
enum CalendarAnchorLayout: String, Codable {
    case item
    case stack
    case inline
}
