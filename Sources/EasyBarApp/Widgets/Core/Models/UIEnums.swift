import EasyBarCalendarConfig
import EasyBarShared
import Foundation

typealias CalendarAnchorLayout = EasyBarCalendarConfig.CalendarAnchorLayout
typealias WidgetPosition = EasyBarShared.WidgetPosition

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
  case wifiIndicator = "wifi_indicator"

  /// Returns whether this kind renders as a horizontal child container.
  var isRowLikeContainer: Bool {
    return self == .row || self == .group
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
    return self == .spaces || self == .wifiIndicator
  }

  /// Returns whether this kind renders through a dedicated container view.
  var isDedicatedContainerKind: Bool {
    return self == .column || self == .popup
  }
}

/// Internal role markers for special child nodes.
enum WidgetNodeRole: String, Codable {
  case popupAnchor = "popup-anchor"
  case popupContent = "popup-content"
}
