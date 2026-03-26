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

    /// Returns whether this kind renders as a horizontal child container.
    var isRowLikeContainer: Bool {
        self == .row || self == .group
    }

    /// Returns whether this kind renders inside the interactive content wrapper.
    var isInteractiveKind: Bool {
        self == .slider
            || self == .progressSlider
            || self == .progress
            || self == .sparkline
    }

    /// Returns whether this kind renders through a dedicated custom view.
    var isCustomRenderedKind: Bool {
        self == .spaces
    }

    /// Returns whether this kind renders through a dedicated container view.
    var isDedicatedContainerKind: Bool {
        self == .column || self == .popup
    }
}

/// Internal role markers for special child nodes.
enum WidgetNodeRole: String, Codable {
    case popupAnchor = "popup-anchor"
}

/// Hit-testing modes for widget mouse input.
enum WidgetMouseTarget: String, Codable {
    case content
    case frame
}

/// Supported layouts for the native calendar anchor.
enum CalendarAnchorLayout: String, Codable {
    case item
    case stack
    case inline
}
