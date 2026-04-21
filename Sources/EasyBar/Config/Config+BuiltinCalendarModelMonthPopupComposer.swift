import Foundation

extension Config.CalendarBuiltinConfig.Month.Popup {

  struct AnchorStyle {
    var dateFormat: String
    var textColorHex: String?
    var showDateText: Bool
  }

  struct ComposerStyle {
    var createTitle: String
    var editTitle: String
    var titleLabel: String
    var locationLabel: String
    var calendarLabel: String
    var titlePlaceholder: String
    var locationPlaceholder: String
    var defaultCalendarName: String?
    var defaultAlert: String
    var defaultTravelTime: String
    var alertLabels: [String: String]
    var travelTimeLabels: [String: String]
    var startLabel: String
    var endLabel: String
    var allDayLabel: String
    var travelTimeLabel: String
    var alertLabel: String
    var addAlertLabel: String
    var openCalendarLabel: String
    var cancelLabel: String
    var saveLabel: String
    var updateLabel: String
    var removeLabel: String
    var deleteConfirmationTitle: String
    var deleteConfirmationMessage: String
  }

  struct TodayButtonStyle {
    var title: String
    var icon: String
    var borderColorHex: String
    var borderWidth: Double
  }
}
