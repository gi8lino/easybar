import Foundation

/// Formatting helpers for calendar event rows.
enum CalendarEventPresentation {
  /// Formats one event time using the provided calendar.
  static func formattedEventTime(_ date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }

  /// Returns the rendered end time for timed events when it differs from the start.
  static func endTimeText(
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendar: Calendar
  ) -> String? {
    guard !isAllDay, endDate > startDate else { return nil }

    let startTime = formattedEventTime(startDate, calendar: calendar)
    let endTime = formattedEventTime(endDate, calendar: calendar)
    guard startTime != endTime else { return nil }

    return endTime
  }

  /// Returns the rendered departure time when travel time is present.
  static func travelDepartureTimeText(
    startDate: Date,
    travelTimeSeconds: TimeInterval,
    calendar: Calendar
  ) -> String? {
    guard travelTimeSeconds > 0 else { return nil }

    let departureDate = startDate.addingTimeInterval(-travelTimeSeconds)
    return formattedEventTime(departureDate, calendar: calendar)
  }

  /// Returns the rendered travel-time text when available.
  static func travelTimeText(travelTimeSeconds: TimeInterval) -> String? {
    guard travelTimeSeconds > 0 else { return nil }

    let minutes = Int((travelTimeSeconds / 60).rounded())
    guard minutes > 0 else { return nil }

    if minutes == 1 {
      return "1 min"
    }

    return "\(minutes) min"
  }
}
