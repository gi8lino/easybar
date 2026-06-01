import EasyBarShared
import Foundation
import TOMLKit

extension CalendarBuiltinConfigParser {
  // MARK: - Upcoming

  /// Parses upcoming mode config.
  func parseUpcoming(
    eventsTable: TOMLTable,
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseUpcomingEvents(from: eventsTable, fallback: fallback.events),
      popup: try parseUpcomingPopup(from: popupTable, fallback: fallback.popup)
    )
  }

  /// Parses upcoming event query settings.
  func parseUpcomingEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "\(rootPath).upcoming.events.days"
        ) ?? fallback.days
      ),
      excludePastEvents: try optionalBool(
        table["exclude_past_events"],
        path: "\(rootPath).upcoming.events.exclude_past_events"
      ) ?? fallback.excludePastEvents
    )
  }

  /// Parses upcoming popup style settings.
  func parseUpcomingPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(rootPath).upcoming.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "\(rootPath).upcoming.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "\(rootPath).upcoming.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "\(rootPath).upcoming.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "\(rootPath).upcoming.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "\(rootPath).upcoming.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "\(rootPath).upcoming.popup.spacing"
      ) ?? fallback.spacing,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "\(rootPath).upcoming.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "\(rootPath).upcoming.popup.margin_y"
      ) ?? fallback.marginY
    )
  }
}
