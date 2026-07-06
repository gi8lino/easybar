import EasyBarConfigParsing
import EasyBarShared
import Foundation
import TOMLKit

extension CalendarPopupMode: TOMLStringDecodable {
  public static let allowedValues = allCases.map(\.rawValue)
}

extension MonthCalendarPopupLayout: TOMLStringDecodable {
  public static let allowedValues = allCases.map(\.rawValue)
}

extension CalendarAnchorLayout: TOMLStringDecodable {
  public static let allowedValues = ["item", "stack", "inline"]
}

extension CalendarBuiltinConfig {
  typealias Reader = TOMLConfigReader<CalendarConfigError>

  /// Parses the reusable calendar config from one TOML table.
  public static func parse(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig = .default,
    path: String = "calendar"
  ) throws -> CalendarBuiltinConfig {
    let reader = calendarReader(table: table, path: path)

    return CalendarBuiltinConfig(
      placement: try parsePlacement(reader: reader, fallback: fallback.placement),
      style: try parseWidgetStyle(reader: try reader.section("style"), fallback: fallback.style),
      popupMode: try reader.enum("popup_mode", fallback: fallback.popupMode),
      anchor: try parseAnchor(reader: try reader.section("anchor"), fallback: fallback.anchor),
      filters: try parseFilters(reader: try reader.section("filters"), fallback: fallback.filters),
      appointments: try parseAppointments(
        reader: try reader.section("appointments"),
        fallback: fallback.appointments
      ),
      birthdays: try parseBirthdays(
        reader: try reader.section("birthdays"),
        fallback: fallback.birthdays
      ),
      composer: try parseComposer(
        reader: try reader.section("composer"), fallback: fallback.composer),
      upcoming: try parseUpcoming(
        reader: try reader.section("upcoming"), fallback: fallback.upcoming),
      month: try parseMonth(reader: try reader.section("month"), fallback: fallback.month)
    )
  }

  private static func calendarReader(table: TOMLTable, path: String) -> Reader {
    Reader(
      table: table,
      path: path,
      makeInvalidTypeError: CalendarConfigError.invalidType,
      makeInvalidValueError: CalendarConfigError.invalidValue
    )
  }

  private static func parsePlacement(
    reader: Reader,
    fallback: CalendarWidgetPlacement
  ) throws -> CalendarWidgetPlacement {
    CalendarWidgetPlacement(
      enabled: try reader.bool("enabled", fallback: fallback.enabled),
      position: try parsePosition(
        try reader.string("position", fallback: fallback.position.rawValue),
        path: reader.path(for: "position")
      ),
      order: try reader.int("order", fallback: fallback.order),
      group: try reader.optionalString("group", fallback: fallback.group)
    )
  }

  private static func parseWidgetStyle(
    reader: Reader,
    fallback: CalendarWidgetStyle
  ) throws -> CalendarWidgetStyle {
    CalendarWidgetStyle(
      icon: try reader.string("icon", fallback: fallback.icon),
      textColorHex: try reader.optionalString("text_color", fallback: fallback.textColorHex),
      backgroundColorHex: try reader.optionalString(
        "background_color",
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try reader.optionalString("border_color", fallback: fallback.borderColorHex),
      borderWidth: try reader.double("border_width", fallback: fallback.borderWidth),
      cornerRadius: try reader.double("corner_radius", fallback: fallback.cornerRadius),
      marginX: try reader.double("margin_x", fallback: fallback.marginX),
      marginY: try reader.double("margin_y", fallback: fallback.marginY),
      paddingX: try reader.double("padding_x", fallback: fallback.paddingX),
      paddingY: try reader.double("padding_y", fallback: fallback.paddingY),
      spacing: try reader.double("spacing", fallback: fallback.spacing),
      opacity: try reader.double("opacity", fallback: fallback.opacity)
    )
  }

  private static func parseAnchor(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try reader.string("item_format", fallback: fallback.itemFormat),
      layout: try reader.enum("layout", fallback: fallback.layout),
      topFormat: try reader.string("top_format", fallback: fallback.topFormat),
      bottomFormat: try reader.string("bottom_format", fallback: fallback.bottomFormat),
      lineSpacing: try reader.double("line_spacing", fallback: fallback.lineSpacing),
      topTextColorHex: try reader.optionalString(
        "top_text_color", fallback: fallback.topTextColorHex),
      bottomTextColorHex: try reader.optionalString(
        "bottom_text_color",
        fallback: fallback.bottomTextColorHex
      )
    )
  }

  private static func parseFilters(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try reader.stringArray(
        "included_calendar_names",
        fallback: fallback.includedCalendarNames
      ),
      excludedCalendarNames: try reader.stringArray(
        "excluded_calendar_names",
        fallback: fallback.excludedCalendarNames
      ),
      includedCalendarIDs: try reader.stringArray(
        "included_calendar_ids",
        fallback: fallback.includedCalendarIDs
      ),
      excludedCalendarIDs: try reader.stringArray(
        "excluded_calendar_ids",
        fallback: fallback.excludedCalendarIDs
      ),
      includedCalendarSourceIDs: try reader.stringArray(
        "included_calendar_source_ids",
        fallback: fallback.includedCalendarSourceIDs
      ),
      excludedCalendarSourceIDs: try reader.stringArray(
        "excluded_calendar_source_ids",
        fallback: fallback.excludedCalendarSourceIDs
      )
    )
  }

  private static func parseAppointments(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try reader.double("item_indent", fallback: fallback.itemIndent),
      eventTextColorHex: try reader.string(
        "event_text_color", fallback: fallback.eventTextColorHex),
      emptyTextColorHex: try reader.string(
        "empty_text_color", fallback: fallback.emptyTextColorHex),
      secondaryTextColorHex: try reader.string(
        "secondary_text_color",
        fallback: fallback.secondaryTextColorHex
      ),
      travelTextColorHex: try reader.string(
        "travel_text_color", fallback: fallback.travelTextColorHex),
      emptyText: try reader.string("empty_text", fallback: fallback.emptyText),
      showCalendarName: try reader.bool("show_calendar_name", fallback: fallback.showCalendarName),
      showAllDayLabel: try reader.bool("show_all_day_label", fallback: fallback.showAllDayLabel),
      showHolidayAllDayLabel: try reader.bool(
        "show_holiday_all_day_label",
        fallback: fallback.showHolidayAllDayLabel
      ),
      allDayLabel: try reader.string("all_day_label", fallback: fallback.allDayLabel),
      showLocation: try reader.bool("show_location", fallback: fallback.showLocation),
      locationIcon: try reader.string("location_icon", fallback: fallback.locationIcon),
      locationIconColorHex: try reader.optionalString(
        "location_icon_color",
        fallback: fallback.locationIconColorHex
      ),
      showTravelTime: try reader.bool("show_travel_time", fallback: fallback.showTravelTime),
      showEndTime: try reader.bool("show_end_time", fallback: fallback.showEndTime),
      travelIcon: try reader.string("travel_icon", fallback: fallback.travelIcon),
      travelIconColorHex: try reader.optionalString(
        "travel_icon_color",
        fallback: fallback.travelIconColorHex
      ),
      showAlertIcon: try reader.bool("show_alert_icon", fallback: fallback.showAlertIcon),
      alertIcon: try reader.string("alert_icon", fallback: fallback.alertIcon),
      alertIconColorHex: try reader.optionalString(
        "alert_icon_color",
        fallback: fallback.alertIconColorHex
      )
    )
  }

  private static func parseBirthdays(
    reader: Reader,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try reader.bool("show_birthdays", fallback: fallback.showBirthdays),
      birthdaysShowAge: try reader.bool("birthdays_show_age", fallback: fallback.birthdaysShowAge),
      birthdayIcon: try reader.string("birthday_icon", fallback: fallback.birthdayIcon),
      birthdayIconColorHex: try reader.optionalString(
        "birthday_icon_color",
        fallback: fallback.birthdayIconColorHex
      )
    )
  }

  private static func parsePosition(_ rawValue: String, path: String) throws -> WidgetPosition {
    if let position = WidgetPosition(rawValue: rawValue) {
      return position
    }

    throw CalendarConfigError.invalidValue(
      path: path, message: "expected one of left, center, right")
  }
}
