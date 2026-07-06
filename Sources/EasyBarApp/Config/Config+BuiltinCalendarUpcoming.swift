import Foundation
import TOMLKit

extension Config {

  /// Parses the upcoming calendar mode.
  func parseCalendarUpcoming(
    eventsTable: TOMLTable,
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseCalendarUpcomingEvents(
        from: eventsTable,
        fallback: fallback.events
      ),
      popup: try parseCalendarUpcomingPopup(
        from: popupTable,
        fallback: fallback.popup
      )
    )
  }

  /// Parses the upcoming events block.
  func parseCalendarUpcomingEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "builtins.calendar.upcoming.events.days",
          fallback: fallback.days
        )
      ),
      excludePastEvents: try optionalBool(
        table["exclude_past_events"],
        path: "builtins.calendar.upcoming.events.exclude_past_events",
        fallback: fallback.excludePastEvents
      )
    )
  }

  /// Parses the upcoming popup block.
  func parseCalendarUpcomingPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.upcoming.popup.background_color",
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.upcoming.popup.border_color",
        fallback: fallback.borderColorHex
      ),
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.upcoming.popup.border_width",
        fallback: fallback.borderWidth
      ),
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.upcoming.popup.corner_radius",
        fallback: fallback.cornerRadius
      ),
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.upcoming.popup.padding_x",
        fallback: fallback.paddingX
      ),
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.upcoming.popup.padding_y",
        fallback: fallback.paddingY
      ),
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.upcoming.popup.spacing",
        fallback: fallback.spacing
      ),
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.upcoming.popup.margin_x",
        fallback: fallback.marginX
      ),
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.upcoming.popup.margin_y",
        fallback: fallback.marginY
      )
    )
  }
}
