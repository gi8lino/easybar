import Foundation

/// Reusable configuration for the calendar composer UI and view model.
public struct CalendarComposerConfig: Sendable {
  public let createTitle: String
  public let editTitle: String
  public let saveLabel: String
  public let updateLabel: String
  public let removeLabel: String
  public let cancelLabel: String
  public let deleteConfirmationTitle: String
  public let deleteConfirmationMessage: String
  public let openCalendarLabel: String
  public let titleLabel: String
  public let titlePlaceholder: String
  public let locationLabel: String
  public let locationPlaceholder: String
  public let calendarLabel: String
  public let allDayLabel: String
  public let startLabel: String
  public let endLabel: String
  public let travelTimeLabel: String
  public let alertLabel: String
  public let addAlertLabel: String
  public let defaultCalendarName: String?
  public let defaultAlert: String
  public let defaultTravelTime: String
  public let alertLabels: [String: String]
  public let travelTimeLabels: [String: String]
  public let paddingX: Double
  public let paddingY: Double
  public let backgroundColorHex: String
  public let borderColorHex: String
  public let borderWidth: Double
  public let cornerRadius: Double
  public let headerTextColorHex: String
  public let secondaryTextColorHex: String

  public init(
    createTitle: String,
    editTitle: String,
    saveLabel: String,
    updateLabel: String,
    removeLabel: String,
    cancelLabel: String,
    deleteConfirmationTitle: String,
    deleteConfirmationMessage: String,
    openCalendarLabel: String,
    titleLabel: String,
    titlePlaceholder: String,
    locationLabel: String,
    locationPlaceholder: String,
    calendarLabel: String,
    allDayLabel: String,
    startLabel: String,
    endLabel: String,
    travelTimeLabel: String,
    alertLabel: String,
    addAlertLabel: String,
    defaultCalendarName: String?,
    defaultAlert: String,
    defaultTravelTime: String,
    alertLabels: [String: String],
    travelTimeLabels: [String: String],
    paddingX: Double,
    paddingY: Double,
    backgroundColorHex: String,
    borderColorHex: String,
    borderWidth: Double,
    cornerRadius: Double,
    headerTextColorHex: String,
    secondaryTextColorHex: String
  ) {
    self.createTitle = createTitle
    self.editTitle = editTitle
    self.saveLabel = saveLabel
    self.updateLabel = updateLabel
    self.removeLabel = removeLabel
    self.cancelLabel = cancelLabel
    self.deleteConfirmationTitle = deleteConfirmationTitle
    self.deleteConfirmationMessage = deleteConfirmationMessage
    self.openCalendarLabel = openCalendarLabel
    self.titleLabel = titleLabel
    self.titlePlaceholder = titlePlaceholder
    self.locationLabel = locationLabel
    self.locationPlaceholder = locationPlaceholder
    self.calendarLabel = calendarLabel
    self.allDayLabel = allDayLabel
    self.startLabel = startLabel
    self.endLabel = endLabel
    self.travelTimeLabel = travelTimeLabel
    self.alertLabel = alertLabel
    self.addAlertLabel = addAlertLabel
    self.defaultCalendarName = defaultCalendarName
    self.defaultAlert = defaultAlert
    self.defaultTravelTime = defaultTravelTime
    self.alertLabels = alertLabels
    self.travelTimeLabels = travelTimeLabels
    self.paddingX = paddingX
    self.paddingY = paddingY
    self.backgroundColorHex = backgroundColorHex
    self.borderColorHex = borderColorHex
    self.borderWidth = borderWidth
    self.cornerRadius = cornerRadius
    self.headerTextColorHex = headerTextColorHex
    self.secondaryTextColorHex = secondaryTextColorHex
  }
}
