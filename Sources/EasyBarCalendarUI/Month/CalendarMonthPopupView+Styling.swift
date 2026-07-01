import SwiftUI

extension CalendarMonthPopupView {
  /// Returns the foreground color for one day cell.
  func dayForeground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedTextColorHex)
    }

    if day.isCurrentMonth {
      return color(config.dayTextColorHex)
    }

    return color(config.outsideMonthTextColorHex)
  }

  /// Returns the background for one day cell.
  func dayBackground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedBackgroundColorHex)
    }

    if resolvedCalendar.isDateInToday(day.date) {
      return color(config.todayCellBackgroundColorHex)
    }

    return .clear
  }

  /// Returns the border color for one day cell.
  func dayBorderColor(_ day: DayCell) -> Color {
    if resolvedCalendar.isDateInToday(day.date) {
      return color(config.todayCellBorderColorHex)
    }

    return .clear
  }

  /// Returns the border width for one day cell.
  func dayBorderWidth(_ day: DayCell) -> CGFloat {
    if resolvedCalendar.isDateInToday(day.date) {
      return CGFloat(max(config.todayCellBorderWidth, 0))
    }

    return 0
  }

  /// Returns whether one day is inside the active selection.
  func isSelected(_ date: Date) -> Bool {
    let normalizedDate = resolvedCalendar.startOfDay(for: date)
    let start = resolvedCalendar.startOfDay(for: min(selectedStartDate, selectedEndDate))
    let end = resolvedCalendar.startOfDay(for: max(selectedStartDate, selectedEndDate))
    return normalizedDate >= start && normalizedDate <= end
  }

  /// Converts one hex string into SwiftUI color.
  func color(_ hex: String) -> Color {
    return Color(calendarHex: hex)
  }
}
