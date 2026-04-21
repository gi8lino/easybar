import Foundation

extension Config.CalendarBuiltinConfig {

  struct Upcoming {
    struct Events {
      var days: Int
      var emptyText: String
    }

    struct Birthdays {
      var show: Bool
      var title: String
      var dateFormat: String
      var showAge: Bool
    }

    struct PopupSectionStyle {
      var titleColorHex: String
      var itemColorHex: String
      var emptyColorHex: String
    }

    struct Popup {
      var backgroundColorHex: String
      var borderColorHex: String
      var borderWidth: Double
      var cornerRadius: Double
      var paddingX: Double
      var paddingY: Double
      var spacing: Double
      var itemIndent: Double
      var marginX: Double
      var marginY: Double
      var showCalendarName: Bool
      var useCalendarColors: Bool
      var birthdays: PopupSectionStyle
      var today: PopupSectionStyle
      var tomorrow: PopupSectionStyle
      var future: PopupSectionStyle
    }

    var events: Events
    var birthdays: Birthdays
    var popup: Popup
  }
}
