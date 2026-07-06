import Foundation

extension CalendarBuiltinConfig {
  static func parseUpcoming(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseUpcomingEvents(
        reader: try reader.section("events"),
        fallback: fallback.events
      ),
      popup: try parseUpcomingPopup(
        reader: try reader.section("popup"),
        fallback: fallback.popup
      )
    )
  }

  private static func parseUpcomingEvents(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(1, try reader.int("days", fallback: fallback.days)),
      excludePastEvents: try reader.bool(
        "exclude_past_events",
        fallback: fallback.excludePastEvents
      )
    )
  }

  private static func parseUpcomingPopup(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try reader.string(
        "background_color", fallback: fallback.backgroundColorHex),
      borderColorHex: try reader.string("border_color", fallback: fallback.borderColorHex),
      borderWidth: try reader.double("border_width", fallback: fallback.borderWidth),
      cornerRadius: try reader.double("corner_radius", fallback: fallback.cornerRadius),
      paddingX: try reader.double("padding_x", fallback: fallback.paddingX),
      paddingY: try reader.double("padding_y", fallback: fallback.paddingY),
      spacing: try reader.double("spacing", fallback: fallback.spacing),
      marginX: try reader.double("margin_x", fallback: fallback.marginX),
      marginY: try reader.double("margin_y", fallback: fallback.marginY)
    )
  }
}
