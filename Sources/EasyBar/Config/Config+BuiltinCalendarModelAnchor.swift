import Foundation

extension Config.CalendarBuiltinConfig {

  /// Anchor text model for the calendar widget.
  struct Anchor {
    /// Date format used for the anchor item.
    var itemFormat: String
    /// Anchor text layout.
    var layout: CalendarAnchorLayout
    /// Date format for the top line.
    var topFormat: String
    /// Date format for the bottom line.
    var bottomFormat: String
    /// Spacing between anchor lines.
    var lineSpacing: Double
    /// Optional top-line text color.
    var topTextColorHex: String?
    /// Optional bottom-line text color.
    var bottomTextColorHex: String?
  }
}
