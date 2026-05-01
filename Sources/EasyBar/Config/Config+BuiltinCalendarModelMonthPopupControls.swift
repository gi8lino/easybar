import Foundation

extension Config.CalendarBuiltinConfig.Month.Popup {

  /// Month popup anchor display settings.
  struct AnchorStyle {
    var dateFormat: String
    var textColorHex: String?
    var showDateText: Bool
  }

  /// Month popup today-button settings.
  struct TodayButtonStyle {
    var title: String
    var icon: String
    var borderColorHex: String
    var borderWidth: Double
  }
}
