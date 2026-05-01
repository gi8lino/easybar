import Foundation

extension Config.CalendarBuiltinConfig {

  /// Calendar event composer config.
  struct Composer {
    /// Composer visual style settings.
    struct Style {
      var backgroundColorHex: String
      var borderColorHex: String
      var borderWidth: Double
      var cornerRadius: Double
      var paddingX: Double
      var paddingY: Double
      var headerTextColorHex: String
    }

    /// Composer labels, defaults, and copy.
    struct Content {
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

    /// Composer visual style.
    var style: Style
    /// Composer text and default values.
    var content: Content

    var backgroundColorHex: String {
      get { style.backgroundColorHex }
      set { style.backgroundColorHex = newValue }
    }

    var borderColorHex: String {
      get { style.borderColorHex }
      set { style.borderColorHex = newValue }
    }

    var borderWidth: Double {
      get { style.borderWidth }
      set { style.borderWidth = newValue }
    }

    var cornerRadius: Double {
      get { style.cornerRadius }
      set { style.cornerRadius = newValue }
    }

    var paddingX: Double {
      get { style.paddingX }
      set { style.paddingX = newValue }
    }

    var paddingY: Double {
      get { style.paddingY }
      set { style.paddingY = newValue }
    }

    var headerTextColorHex: String {
      get { style.headerTextColorHex }
      set { style.headerTextColorHex = newValue }
    }

    var createTitle: String {
      get { content.createTitle }
      set { content.createTitle = newValue }
    }

    var editTitle: String {
      get { content.editTitle }
      set { content.editTitle = newValue }
    }

    var titleLabel: String {
      get { content.titleLabel }
      set { content.titleLabel = newValue }
    }

    var locationLabel: String {
      get { content.locationLabel }
      set { content.locationLabel = newValue }
    }

    var calendarLabel: String {
      get { content.calendarLabel }
      set { content.calendarLabel = newValue }
    }

    var titlePlaceholder: String {
      get { content.titlePlaceholder }
      set { content.titlePlaceholder = newValue }
    }

    var locationPlaceholder: String {
      get { content.locationPlaceholder }
      set { content.locationPlaceholder = newValue }
    }

    var defaultCalendarName: String? {
      get { content.defaultCalendarName }
      set { content.defaultCalendarName = newValue }
    }

    var defaultAlert: String {
      get { content.defaultAlert }
      set { content.defaultAlert = newValue }
    }

    var defaultTravelTime: String {
      get { content.defaultTravelTime }
      set { content.defaultTravelTime = newValue }
    }

    var alertLabels: [String: String] {
      get { content.alertLabels }
      set { content.alertLabels = newValue }
    }

    var travelTimeLabels: [String: String] {
      get { content.travelTimeLabels }
      set { content.travelTimeLabels = newValue }
    }

    var startLabel: String {
      get { content.startLabel }
      set { content.startLabel = newValue }
    }

    var endLabel: String {
      get { content.endLabel }
      set { content.endLabel = newValue }
    }

    var allDayLabel: String {
      get { content.allDayLabel }
      set { content.allDayLabel = newValue }
    }

    var travelTimeLabel: String {
      get { content.travelTimeLabel }
      set { content.travelTimeLabel = newValue }
    }

    var alertLabel: String {
      get { content.alertLabel }
      set { content.alertLabel = newValue }
    }

    var addAlertLabel: String {
      get { content.addAlertLabel }
      set { content.addAlertLabel = newValue }
    }

    var openCalendarLabel: String {
      get { content.openCalendarLabel }
      set { content.openCalendarLabel = newValue }
    }

    var cancelLabel: String {
      get { content.cancelLabel }
      set { content.cancelLabel = newValue }
    }

    var saveLabel: String {
      get { content.saveLabel }
      set { content.saveLabel = newValue }
    }

    var updateLabel: String {
      get { content.updateLabel }
      set { content.updateLabel = newValue }
    }

    var removeLabel: String {
      get { content.removeLabel }
      set { content.removeLabel = newValue }
    }

    var deleteConfirmationTitle: String {
      get { content.deleteConfirmationTitle }
      set { content.deleteConfirmationTitle = newValue }
    }

    var deleteConfirmationMessage: String {
      get { content.deleteConfirmationMessage }
      set { content.deleteConfirmationMessage = newValue }
    }
  }
}
