import Foundation

/// Reusable configuration for the upcoming-calendar popup.
public struct CalendarUpcomingPopupConfig: Sendable {
  public let days: Int
  public let excludePastEvents: Bool
  public let backgroundColorHex: String
  public let borderColorHex: String
  public let borderWidth: Double
  public let cornerRadius: Double
  public let paddingX: Double
  public let paddingY: Double
  public let spacing: Double
  public let marginX: Double
  public let marginY: Double
  public let firstWeekday: Int?
  public let selectionDateFormat: String
  public let defaultIndicatorColorHex: String

  public init(
    days: Int,
    excludePastEvents: Bool,
    backgroundColorHex: String,
    borderColorHex: String,
    borderWidth: Double,
    cornerRadius: Double,
    paddingX: Double,
    paddingY: Double,
    spacing: Double,
    marginX: Double,
    marginY: Double,
    firstWeekday: Int?,
    selectionDateFormat: String,
    defaultIndicatorColorHex: String
  ) {
    self.days = days
    self.excludePastEvents = excludePastEvents
    self.backgroundColorHex = backgroundColorHex
    self.borderColorHex = borderColorHex
    self.borderWidth = borderWidth
    self.cornerRadius = cornerRadius
    self.paddingX = paddingX
    self.paddingY = paddingY
    self.spacing = spacing
    self.marginX = marginX
    self.marginY = marginY
    self.firstWeekday = firstWeekday
    self.selectionDateFormat = selectionDateFormat
    self.defaultIndicatorColorHex = defaultIndicatorColorHex
  }
}
