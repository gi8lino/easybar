import Foundation

extension Config.CalendarBuiltinConfig {

  /// Upcoming calendar popup config.
  struct Upcoming {
    /// Upcoming event query settings.
    struct Events {
      var days: Int
      var excludePastEvents: Bool
    }

    /// Upcoming popup visual style.
    struct Popup {
      var backgroundColorHex: String
      var borderColorHex: String
      var borderWidth: Double
      var cornerRadius: Double
      var paddingX: Double
      var paddingY: Double
      var spacing: Double
      var marginX: Double
      var marginY: Double
    }

    /// Event query settings.
    var events: Events
    /// Popup visual style.
    var popup: Popup
  }
}
