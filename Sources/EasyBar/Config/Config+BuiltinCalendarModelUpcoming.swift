import Foundation

extension Config.CalendarBuiltinConfig {

  struct Upcoming {
    struct Events {
      var days: Int
      var excludePastEvents: Bool
    }

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

    var events: Events
    var popup: Popup
  }
}
