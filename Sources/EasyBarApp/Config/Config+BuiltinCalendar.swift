import EasyBarCalendarConfig
import TOMLKit

extension Config {
  /// Parses the built-in calendar widget.
  func parseCalendarBuiltin(from builtins: TOMLTable) throws {
    guard let calendar = builtins["calendar"]?.table else { return }

    builtinCalendar = try CalendarBuiltinConfig.parse(
      from: calendar,
      fallback: builtinCalendar,
      path: "builtins.calendar"
    )
  }
}
