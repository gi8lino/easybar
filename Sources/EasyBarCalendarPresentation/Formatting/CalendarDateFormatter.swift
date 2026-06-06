import Foundation

/// Shared calendar date formatting helpers used by calendar presentation surfaces.
public enum CalendarDateFormatter {
  /// Formats a date using one explicit date-format pattern.
  public static func string(
    from date: Date,
    calendar: Calendar,
    dateFormat: String
  ) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = dateFormat
    return formatter.string(from: date)
  }

  /// Formats a date from one localized template.
  public static func localizedString(
    from date: Date,
    calendar: Calendar,
    locale: Locale,
    template: String
  ) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }

  /// Formats a date for stable debug logging.
  public static func iso8601String(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
