import Foundation

/// Layout variants for the reusable month-calendar popup.
public enum CalendarMonthPopupLayout: String, CaseIterable, Sendable {
  case calendarAppointmentsHorizontal = "calendar_appointments_horizontal"
  case appointmentsCalendarHorizontal = "appointments_calendar_horizontal"
  case calendarAppointmentsVertical = "calendar_appointments_vertical"
  case appointmentsCalendarVertical = "appointments_calendar_vertical"
}

/// Reusable configuration for the month-calendar popup.
public struct CalendarMonthPopupConfig: Sendable {
  public let backgroundColorHex: String
  public let borderColorHex: String
  public let borderWidth: Double
  public let cornerRadius: Double
  public let paddingX: Double
  public let paddingY: Double
  public let spacing: Double
  public let marginX: Double
  public let marginY: Double
  public let showWeekNumbers: Bool
  public let showEventIndicators: Bool
  public let headerTextColorHex: String
  public let weekdayTextColorHex: String
  public let firstWeekday: Int?
  public let resolvedWeekdaySymbols: [String]
  public let dayTextColorHex: String
  public let outsideMonthTextColorHex: String
  public let todayCellBackgroundColorHex: String
  public let todayCellBorderColorHex: String
  public let todayCellBorderWidth: Double
  public let indicatorColorHex: String
  public let selectedTextColorHex: String
  public let selectedBackgroundColorHex: String
  public let selectionDateFormat: String
  public let selectionDateSeparator: String
  public let allowsRangeSelection: Bool
  public let resetSelectionOnThirdTap: Bool
  public let layout: CalendarMonthPopupLayout
  public let appointmentsScrollable: Bool
  public let appointmentsMinHeight: Double
  public let appointmentsMaxHeight: Double
  public let agendaTitle: String
  public let maxVisibleAppointments: Int
  public let anchorDateFormat: String
  public let anchorTextColorHex: String?
  public let anchorShowDateText: Bool
  public let todayButtonTitle: String
  public let todayButtonIcon: String
  public let todayButtonBorderColorHex: String
  public let todayButtonBorderWidth: Double

  public init(
    backgroundColorHex: String,
    borderColorHex: String,
    borderWidth: Double,
    cornerRadius: Double,
    paddingX: Double,
    paddingY: Double,
    spacing: Double,
    marginX: Double,
    marginY: Double,
    showWeekNumbers: Bool,
    showEventIndicators: Bool,
    headerTextColorHex: String,
    weekdayTextColorHex: String,
    firstWeekday: Int?,
    resolvedWeekdaySymbols: [String],
    dayTextColorHex: String,
    outsideMonthTextColorHex: String,
    todayCellBackgroundColorHex: String,
    todayCellBorderColorHex: String,
    todayCellBorderWidth: Double,
    indicatorColorHex: String,
    selectedTextColorHex: String,
    selectedBackgroundColorHex: String,
    selectionDateFormat: String,
    selectionDateSeparator: String,
    allowsRangeSelection: Bool,
    resetSelectionOnThirdTap: Bool,
    layout: CalendarMonthPopupLayout,
    appointmentsScrollable: Bool,
    appointmentsMinHeight: Double,
    appointmentsMaxHeight: Double,
    agendaTitle: String,
    maxVisibleAppointments: Int,
    anchorDateFormat: String,
    anchorTextColorHex: String?,
    anchorShowDateText: Bool,
    todayButtonTitle: String,
    todayButtonIcon: String,
    todayButtonBorderColorHex: String,
    todayButtonBorderWidth: Double
  ) {
    self.backgroundColorHex = backgroundColorHex
    self.borderColorHex = borderColorHex
    self.borderWidth = borderWidth
    self.cornerRadius = cornerRadius
    self.paddingX = paddingX
    self.paddingY = paddingY
    self.spacing = spacing
    self.marginX = marginX
    self.marginY = marginY
    self.showWeekNumbers = showWeekNumbers
    self.showEventIndicators = showEventIndicators
    self.headerTextColorHex = headerTextColorHex
    self.weekdayTextColorHex = weekdayTextColorHex
    self.firstWeekday = firstWeekday
    self.resolvedWeekdaySymbols = resolvedWeekdaySymbols
    self.dayTextColorHex = dayTextColorHex
    self.outsideMonthTextColorHex = outsideMonthTextColorHex
    self.todayCellBackgroundColorHex = todayCellBackgroundColorHex
    self.todayCellBorderColorHex = todayCellBorderColorHex
    self.todayCellBorderWidth = todayCellBorderWidth
    self.indicatorColorHex = indicatorColorHex
    self.selectedTextColorHex = selectedTextColorHex
    self.selectedBackgroundColorHex = selectedBackgroundColorHex
    self.selectionDateFormat = selectionDateFormat
    self.selectionDateSeparator = selectionDateSeparator
    self.allowsRangeSelection = allowsRangeSelection
    self.resetSelectionOnThirdTap = resetSelectionOnThirdTap
    self.layout = layout
    self.appointmentsScrollable = appointmentsScrollable
    self.appointmentsMinHeight = appointmentsMinHeight
    self.appointmentsMaxHeight = appointmentsMaxHeight
    self.agendaTitle = agendaTitle
    self.maxVisibleAppointments = maxVisibleAppointments
    self.anchorDateFormat = anchorDateFormat
    self.anchorTextColorHex = anchorTextColorHex
    self.anchorShowDateText = anchorShowDateText
    self.todayButtonTitle = todayButtonTitle
    self.todayButtonIcon = todayButtonIcon
    self.todayButtonBorderColorHex = todayButtonBorderColorHex
    self.todayButtonBorderWidth = todayButtonBorderWidth
  }
}

/// Reusable birthday display values for calendar popups.
public struct CalendarBirthdayStyle: Sendable {
  public let birthdayIcon: String
  public let birthdayIconColorHex: String?

  public init(birthdayIcon: String, birthdayIconColorHex: String?) {
    self.birthdayIcon = birthdayIcon
    self.birthdayIconColorHex = birthdayIconColorHex
  }
}
