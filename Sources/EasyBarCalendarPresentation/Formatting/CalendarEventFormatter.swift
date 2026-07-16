import Foundation

/// Formatting helpers for calendar event rows.
public enum CalendarEventFormatter {
  /// Returns the rendered end time for timed events when it differs from the start.
  public static func endTimeText(
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    calendar: Calendar
  ) -> String? {
    guard !isAllDay, endDate > startDate else { return nil }

    let startTime = CalendarDateFormatter.string(
      from: startDate,
      calendar: calendar,
      dateFormat: "HH:mm"
    )
    let endTime = CalendarDateFormatter.string(
      from: endDate,
      calendar: calendar,
      dateFormat: "HH:mm"
    )
    guard startTime != endTime else { return nil }

    return endTime
  }

  /// Returns the rendered travel-time text when available.
  public static func travelTimeText(travelTimeSeconds: TimeInterval) -> String? {
    guard travelTimeSeconds > 0 else { return nil }

    let minutes = Int((travelTimeSeconds / 60).rounded())
    guard minutes > 0 else { return nil }

    if minutes == 1 {
      return "1 min"
    }

    return "\(minutes) min"
  }
}
