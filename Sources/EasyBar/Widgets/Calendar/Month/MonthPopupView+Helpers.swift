import SwiftUI

// MARK: - Logging And Helpers

extension NativeMonthCalendarPopupView {
  /// Returns the calendar resolved for month popup rendering.
  var resolvedCalendar: Calendar {
    var resolved = calendar

    if let firstWeekday = config.firstWeekday {
      resolved.firstWeekday = firstWeekday
    }

    return resolved
  }

  /// Keeps the selection inside the current visible month on first show.
  func syncSelectionIntoVisibleMonth() {
    if !resolvedCalendar.isDate(selectedStartDate, equalTo: visibleMonth, toGranularity: .month) {
      selectedStartDate = visibleMonth
      selectedEndDate = visibleMonth
    }
  }

  /// Opens the separate event composer popup for a new appointment.
  func openComposer() {
    let defaultDate = resolvedCalendar.startOfDay(for: min(selectedStartDate, selectedEndDate))
    composerPanel.present(defaultDate: defaultDate) {
      refreshCalendarViews()
    }
  }

  /// Opens the separate event composer popup for one existing appointment.
  func openComposer(for event: NativeMonthCalendarEvent) {
    composerPanel.present(event: event) {
      refreshCalendarViews()
    }
  }

  /// Refreshes calendar-backed views after a create, update, or delete.
  func refreshCalendarViews() {
    MonthCalendarAgentClient.shared.refresh()
    UpcomingCalendarAgentClient.shared.refresh()
  }

  /// Resolves one normalized day from the recorded day-cell frames.
  func resolvedDay(at location: CGPoint) -> Date? {
    for (date, frame) in dayCellFrames {
      if frame.contains(location) {
        return resolvedCalendar.startOfDay(for: date)
      }
    }

    return nil
  }

  /// Logs the current selection.
  func logSelection(_ reason: String) {
    Logger.debug(
      "month calendar popup selection reason=\(reason) start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Logs the appointments resolved for the current selection.
  func logResolvedAppointments(_ reason: String) {
    Logger.debug(
      "month calendar popup appointments reason=\(reason) count=\(selectedEvents.count)"
    )
  }

  /// Returns the first day of one month.
  static func startOfMonth(_ date: Date, calendar: Calendar = Calendar.current) -> Date {
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components) ?? calendar.startOfDay(for: date)
  }

  /// Formats one debug date.
  func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
