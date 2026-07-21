import Foundation

extension CalendarBuiltinConfig {
  public struct Composer: Sendable {
    public struct Style: Sendable {
      public var backgroundColorHex: String
      public var borderColorHex: String
      public var borderWidth: Double
      public var cornerRadius: Double
      public var paddingX: Double
      public var paddingY: Double
      public var headerTextColorHex: String

      public init(
        backgroundColorHex: String,
        borderColorHex: String,
        borderWidth: Double,
        cornerRadius: Double,
        paddingX: Double,
        paddingY: Double,
        headerTextColorHex: String
      ) {
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.headerTextColorHex = headerTextColorHex
      }
    }

    public struct Content: Sendable {
      public var createTitle: String
      public var editTitle: String
      public var titleLabel: String
      public var locationLabel: String
      public var calendarLabel: String
      public var titlePlaceholder: String
      public var locationPlaceholder: String
      public var defaultCalendarName: String?
      public var defaultAlert: String
      public var defaultTravelTime: String
      public var alertLabels: [String: String]
      public var travelTimeLabels: [String: String]
      public var startLabel: String
      public var endLabel: String
      public var allDayLabel: String
      public var travelTimeLabel: String
      public var alertLabel: String
      public var addAlertLabel: String
      public var openCalendarLabel: String
      public var cancelLabel: String
      public var saveLabel: String
      public var updateLabel: String
      public var removeLabel: String
      public var deleteConfirmationTitle: String
      public var deleteConfirmationMessage: String

      public init(
        createTitle: String,
        editTitle: String,
        titleLabel: String,
        locationLabel: String,
        calendarLabel: String,
        titlePlaceholder: String,
        locationPlaceholder: String,
        defaultCalendarName: String?,
        defaultAlert: String,
        defaultTravelTime: String,
        alertLabels: [String: String],
        travelTimeLabels: [String: String],
        startLabel: String,
        endLabel: String,
        allDayLabel: String,
        travelTimeLabel: String,
        alertLabel: String,
        addAlertLabel: String,
        openCalendarLabel: String,
        cancelLabel: String,
        saveLabel: String,
        updateLabel: String,
        removeLabel: String,
        deleteConfirmationTitle: String,
        deleteConfirmationMessage: String
      ) {
        self.createTitle = createTitle
        self.editTitle = editTitle
        self.titleLabel = titleLabel
        self.locationLabel = locationLabel
        self.calendarLabel = calendarLabel
        self.titlePlaceholder = titlePlaceholder
        self.locationPlaceholder = locationPlaceholder
        self.defaultCalendarName = defaultCalendarName
        self.defaultAlert = defaultAlert
        self.defaultTravelTime = defaultTravelTime
        self.alertLabels = alertLabels
        self.travelTimeLabels = travelTimeLabels
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.allDayLabel = allDayLabel
        self.travelTimeLabel = travelTimeLabel
        self.alertLabel = alertLabel
        self.addAlertLabel = addAlertLabel
        self.openCalendarLabel = openCalendarLabel
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.updateLabel = updateLabel
        self.removeLabel = removeLabel
        self.deleteConfirmationTitle = deleteConfirmationTitle
        self.deleteConfirmationMessage = deleteConfirmationMessage
      }
    }

    public var style: Style
    public var content: Content

    public init(style: Style, content: Content) {
      self.style = style
      self.content = content
    }

    public var backgroundColorHex: String {
      get { style.backgroundColorHex }
      set { style.backgroundColorHex = newValue }
    }

    public var borderColorHex: String {
      get { style.borderColorHex }
      set { style.borderColorHex = newValue }
    }

    public var borderWidth: Double {
      get { style.borderWidth }
      set { style.borderWidth = newValue }
    }

    public var cornerRadius: Double {
      get { style.cornerRadius }
      set { style.cornerRadius = newValue }
    }

    public var paddingX: Double {
      get { style.paddingX }
      set { style.paddingX = newValue }
    }

    public var paddingY: Double {
      get { style.paddingY }
      set { style.paddingY = newValue }
    }

    public var headerTextColorHex: String {
      get { style.headerTextColorHex }
      set { style.headerTextColorHex = newValue }
    }

    public var createTitle: String {
      get { content.createTitle }
      set { content.createTitle = newValue }
    }

    public var editTitle: String {
      get { content.editTitle }
      set { content.editTitle = newValue }
    }

    public var titleLabel: String {
      get { content.titleLabel }
      set { content.titleLabel = newValue }
    }

    public var locationLabel: String {
      get { content.locationLabel }
      set { content.locationLabel = newValue }
    }

    public var calendarLabel: String {
      get { content.calendarLabel }
      set { content.calendarLabel = newValue }
    }

    public var titlePlaceholder: String {
      get { content.titlePlaceholder }
      set { content.titlePlaceholder = newValue }
    }

    public var locationPlaceholder: String {
      get { content.locationPlaceholder }
      set { content.locationPlaceholder = newValue }
    }

    public var defaultCalendarName: String? {
      get { content.defaultCalendarName }
      set { content.defaultCalendarName = newValue }
    }

    public var defaultAlert: String {
      get { content.defaultAlert }
      set { content.defaultAlert = newValue }
    }

    public var defaultTravelTime: String {
      get { content.defaultTravelTime }
      set { content.defaultTravelTime = newValue }
    }

    public var alertLabels: [String: String] {
      get { content.alertLabels }
      set { content.alertLabels = newValue }
    }

    public var travelTimeLabels: [String: String] {
      get { content.travelTimeLabels }
      set { content.travelTimeLabels = newValue }
    }

    public var startLabel: String {
      get { content.startLabel }
      set { content.startLabel = newValue }
    }

    public var endLabel: String {
      get { content.endLabel }
      set { content.endLabel = newValue }
    }

    public var allDayLabel: String {
      get { content.allDayLabel }
      set { content.allDayLabel = newValue }
    }

    public var travelTimeLabel: String {
      get { content.travelTimeLabel }
      set { content.travelTimeLabel = newValue }
    }

    public var alertLabel: String {
      get { content.alertLabel }
      set { content.alertLabel = newValue }
    }

    public var addAlertLabel: String {
      get { content.addAlertLabel }
      set { content.addAlertLabel = newValue }
    }

    public var openCalendarLabel: String {
      get { content.openCalendarLabel }
      set { content.openCalendarLabel = newValue }
    }

    public var cancelLabel: String {
      get { content.cancelLabel }
      set { content.cancelLabel = newValue }
    }

    public var saveLabel: String {
      get { content.saveLabel }
      set { content.saveLabel = newValue }
    }

    public var updateLabel: String {
      get { content.updateLabel }
      set { content.updateLabel = newValue }
    }

    public var removeLabel: String {
      get { content.removeLabel }
      set { content.removeLabel = newValue }
    }

    public var deleteConfirmationTitle: String {
      get { content.deleteConfirmationTitle }
      set { content.deleteConfirmationTitle = newValue }
    }

    public var deleteConfirmationMessage: String {
      get { content.deleteConfirmationMessage }
      set { content.deleteConfirmationMessage = newValue }
    }
  }
}
