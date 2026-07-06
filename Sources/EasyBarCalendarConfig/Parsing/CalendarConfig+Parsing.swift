import EasyBarShared
import Foundation
import TOMLKit

extension CalendarBuiltinConfig {
  /// Parses one calendar config table using the provided fallback for missing values.
  public static func parse(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig = .default,
    path: String = "builtins.calendar"
  ) throws -> CalendarBuiltinConfig {
    let parser = CalendarBuiltinConfigParser(rootPath: path)

    let styleTable = table["style"]?.table ?? TOMLTable()
    let anchorTable = table["anchor"]?.table ?? TOMLTable()
    let filtersTable = table["filters"]?.table ?? TOMLTable()
    let appointmentsTable = table["appointments"]?.table ?? TOMLTable()
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let composerTable = table["composer"]?.table ?? TOMLTable()

    let upcomingTable = table["upcoming"]?.table ?? TOMLTable()
    let upcomingEventsTable = upcomingTable["events"]?.table ?? TOMLTable()
    let upcomingPopupTable = upcomingTable["popup"]?.table ?? TOMLTable()

    let monthTable = table["month"]?.table ?? TOMLTable()
    let monthPopupTable = monthTable["popup"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig(
      placement: try parser.parsePlacement(
        from: table,
        path: path,
        fallback: fallback.placement
      ),
      style: try parser.parseWidgetStyle(
        from: styleTable,
        path: "\(path).style",
        fallback: fallback.style
      ),
      popupMode: try parser.parseCalendarPopupMode(
        try parser.optionalField(.string("popup_mode"), from: table, path: path, fallback: fallback.popupMode.rawValue),
        path: "\(path).popup_mode"
      ),
      anchor: try parser.parseAnchor(
        from: anchorTable,
        fallback: fallback.anchor
      ),
      filters: try parser.parseFilters(
        from: filtersTable,
        fallback: fallback.filters
      ),
      appointments: try parser.parseAppointments(
        from: appointmentsTable,
        fallback: fallback.appointments
      ),
      birthdays: try parser.parseBirthdays(
        from: birthdaysTable,
        fallback: fallback.birthdays
      ),
      composer: try parser.parseComposer(
        from: composerTable,
        fallback: fallback.composer
      ),
      upcoming: try parser.parseUpcoming(
        eventsTable: upcomingEventsTable,
        popupTable: upcomingPopupTable,
        fallback: fallback.upcoming
      ),
      month: try parser.parseMonth(
        popupTable: monthPopupTable,
        fallback: fallback.month
      )
    )
  }
}

/// Parser implementation for `CalendarBuiltinConfig`.
struct CalendarBuiltinConfigParser {
  let rootPath: String

  // MARK: - Top-level shared blocks

  /// Parses shared widget placement fields.
  func parsePlacement(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetPlacement
  ) throws -> CalendarWidgetPlacement {
    CalendarWidgetPlacement(
      enabled: try optionalField(.bool("enabled"), from: table, path: path, fallback: fallback.enabled),
      position: try parseWidgetPosition(
        try optionalField(.string("position"), from: table, path: path, fallback: fallback.position.rawValue),
        path: "\(path).position"
      ),
      order: try optionalField(.int("order"), from: table, path: path, fallback: fallback.order),
      group: try optionalField(.string("group"), from: table, path: path, fallback: fallback.group)
    )
  }

  /// Parses shared widget style fields.
  func parseWidgetStyle(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetStyle
  ) throws -> CalendarWidgetStyle {
    CalendarWidgetStyle(
      icon: try optionalField(.string("icon"), from: table, path: path, fallback: fallback.icon),
      textColorHex: try optionalField(.string("text_color"), from: table, path: path, fallback: fallback.textColorHex),
      backgroundColorHex: try optionalField(
        .string("background_color"),
        from: table,
        path: path,
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try optionalField(
        .string("border_color"), from: table, path: path, fallback: fallback.borderColorHex),
      borderWidth: try optionalField(.number("border_width"), from: table, path: path, fallback: fallback.borderWidth),
      cornerRadius: try optionalField(
        .number("corner_radius"), from: table, path: path, fallback: fallback.cornerRadius),
      marginX: try optionalField(.number("margin_x"), from: table, path: path, fallback: fallback.marginX),
      marginY: try optionalField(.number("margin_y"), from: table, path: path, fallback: fallback.marginY),
      paddingX: try optionalField(.number("padding_x"), from: table, path: path, fallback: fallback.paddingX),
      paddingY: try optionalField(.number("padding_y"), from: table, path: path, fallback: fallback.paddingY),
      spacing: try optionalField(.number("spacing"), from: table, path: path, fallback: fallback.spacing),
      opacity: try optionalField(.number("opacity"), from: table, path: path, fallback: fallback.opacity)
    )
  }

  /// Parses the calendar anchor block.
  func parseAnchor(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try optionalField(
        .string("item_format"), from: table, path: "\(rootPath).anchor", fallback: fallback.itemFormat),
      layout: try parseCalendarLayout(
        try optionalField(
          .string("layout"), from: table, path: "\(rootPath).anchor", fallback: fallback.layout.rawValue),
        path: "\(rootPath).anchor.layout"
      ),
      topFormat: try optionalField(
        .string("top_format"), from: table, path: "\(rootPath).anchor", fallback: fallback.topFormat),
      bottomFormat: try optionalField(
        .string("bottom_format"), from: table, path: "\(rootPath).anchor", fallback: fallback.bottomFormat),
      lineSpacing: try optionalField(
        .number("line_spacing"), from: table, path: "\(rootPath).anchor", fallback: fallback.lineSpacing),
      topTextColorHex: try optionalField(
        .string("top_text_color"),
        from: table,
        path: "\(rootPath).anchor",
        fallback: fallback.topTextColorHex
      ),
      bottomTextColorHex: try optionalField(
        .string("bottom_text_color"),
        from: table,
        path: "\(rootPath).anchor",
        fallback: fallback.bottomTextColorHex
      )
    )
  }

  /// Parses calendar include/exclude filters.
  func parseFilters(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "\(rootPath).filters.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "\(rootPath).filters.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames,
      includedCalendarIDs: try optionalStringArray(
        table["included_calendar_ids"],
        path: "\(rootPath).filters.included_calendar_ids"
      ) ?? fallback.includedCalendarIDs,
      excludedCalendarIDs: try optionalStringArray(
        table["excluded_calendar_ids"],
        path: "\(rootPath).filters.excluded_calendar_ids"
      ) ?? fallback.excludedCalendarIDs,
      includedCalendarSourceIDs: try optionalStringArray(
        table["included_calendar_source_ids"],
        path: "\(rootPath).filters.included_calendar_source_ids"
      ) ?? fallback.includedCalendarSourceIDs,
      excludedCalendarSourceIDs: try optionalStringArray(
        table["excluded_calendar_source_ids"],
        path: "\(rootPath).filters.excluded_calendar_source_ids"
      ) ?? fallback.excludedCalendarSourceIDs
    )
  }

  /// Parses appointment row display settings.
  func parseAppointments(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "\(rootPath).appointments.item_indent"
      ) ?? fallback.itemIndent,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "\(rootPath).appointments.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "\(rootPath).appointments.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "\(rootPath).appointments.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      travelTextColorHex: try optionalString(
        table["travel_text_color"],
        path: "\(rootPath).appointments.travel_text_color"
      ) ?? fallback.travelTextColorHex,
      emptyText: try optionalString(
        table["empty_text"],
        path: "\(rootPath).appointments.empty_text"
      ) ?? fallback.emptyText,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "\(rootPath).appointments.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "\(rootPath).appointments.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      showHolidayAllDayLabel: try optionalBool(
        table["show_holiday_all_day_label"],
        path: "\(rootPath).appointments.show_holiday_all_day_label"
      ) ?? fallback.showHolidayAllDayLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "\(rootPath).appointments.all_day_label"
      ) ?? fallback.allDayLabel,
      showLocation: try optionalBool(
        table["show_location"],
        path: "\(rootPath).appointments.show_location"
      ) ?? fallback.showLocation,
      locationIcon: try optionalString(
        table["location_icon"],
        path: "\(rootPath).appointments.location_icon"
      ) ?? fallback.locationIcon,
      locationIconColorHex: try optionalString(
        table["location_icon_color"],
        path: "\(rootPath).appointments.location_icon_color"
      ) ?? fallback.locationIconColorHex,
      showTravelTime: try optionalBool(
        table["show_travel_time"],
        path: "\(rootPath).appointments.show_travel_time"
      ) ?? fallback.showTravelTime,
      showEndTime: try optionalBool(
        table["show_end_time"],
        path: "\(rootPath).appointments.show_end_time"
      ) ?? fallback.showEndTime,
      travelIcon: try optionalString(
        table["travel_icon"],
        path: "\(rootPath).appointments.travel_icon"
      ) ?? fallback.travelIcon,
      travelIconColorHex: try optionalString(
        table["travel_icon_color"],
        path: "\(rootPath).appointments.travel_icon_color"
      ) ?? fallback.travelIconColorHex,
      showAlertIcon: try optionalBool(
        table["show_alert_icon"],
        path: "\(rootPath).appointments.show_alert_icon"
      ) ?? fallback.showAlertIcon,
      alertIcon: try optionalString(
        table["alert_icon"],
        path: "\(rootPath).appointments.alert_icon"
      ) ?? fallback.alertIcon,
      alertIconColorHex: try optionalString(
        table["alert_icon_color"],
        path: "\(rootPath).appointments.alert_icon_color"
      ) ?? fallback.alertIconColorHex
    )
  }

  /// Parses birthday display settings.
  func parseBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "\(rootPath).birthdays.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "\(rootPath).birthdays.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "\(rootPath).birthdays.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "\(rootPath).birthdays.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }

  // MARK: - Composer

  /// Parses the shared event composer config.
  func parseComposer(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer
  ) throws -> CalendarBuiltinConfig.Composer {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let alertLabelsTable = table["alert_labels"]?.table ?? TOMLTable()
    let travelTimeLabelsTable = table["travel_time_labels"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Composer(
      style: try parseComposerStyle(from: styleTable, fallback: fallback.style),
      content: try parseComposerContent(
        from: table,
        alertLabelsTable: alertLabelsTable,
        travelTimeLabelsTable: travelTimeLabelsTable,
        fallback: fallback.content
      )
    )
  }

  /// Parses event composer style fields.
  func parseComposerStyle(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Style
  ) throws -> CalendarBuiltinConfig.Composer.Style {
    CalendarBuiltinConfig.Composer.Style(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(rootPath).composer.style.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "\(rootPath).composer.style.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "\(rootPath).composer.style.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "\(rootPath).composer.style.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "\(rootPath).composer.style.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "\(rootPath).composer.style.padding_y"
      ) ?? fallback.paddingY,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "\(rootPath).composer.style.header_text_color"
      ) ?? fallback.headerTextColorHex
    )
  }

  /// Parses event composer labels and defaults.
  func parseComposerContent(
    from table: TOMLTable,
    alertLabelsTable: TOMLTable,
    travelTimeLabelsTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Content
  ) throws -> CalendarBuiltinConfig.Composer.Content {
    CalendarBuiltinConfig.Composer.Content(
      createTitle: try optionalString(
        table["create_title"],
        path: "\(rootPath).composer.create_title"
      ) ?? fallback.createTitle,
      editTitle: try optionalString(
        table["edit_title"],
        path: "\(rootPath).composer.edit_title"
      ) ?? fallback.editTitle,
      titleLabel: try optionalString(
        table["title_label"],
        path: "\(rootPath).composer.title_label"
      ) ?? fallback.titleLabel,
      locationLabel: try optionalString(
        table["location_label"],
        path: "\(rootPath).composer.location_label"
      ) ?? fallback.locationLabel,
      calendarLabel: try optionalString(
        table["calendar_label"],
        path: "\(rootPath).composer.calendar_label"
      ) ?? fallback.calendarLabel,
      titlePlaceholder: try optionalString(
        table["title_placeholder"],
        path: "\(rootPath).composer.title_placeholder"
      ) ?? fallback.titlePlaceholder,
      locationPlaceholder: try optionalString(
        table["location_placeholder"],
        path: "\(rootPath).composer.location_placeholder"
      ) ?? fallback.locationPlaceholder,
      defaultCalendarName: try optionalString(
        table["default_calendar_name"],
        path: "\(rootPath).composer.default_calendar_name"
      ) ?? fallback.defaultCalendarName,
      defaultAlert: try optionalString(
        table["default_alert"],
        path: "\(rootPath).composer.default_alert"
      ) ?? fallback.defaultAlert,
      defaultTravelTime: try optionalString(
        table["default_travel_time"],
        path: "\(rootPath).composer.default_travel_time"
      ) ?? fallback.defaultTravelTime,
      alertLabels: try optionalStringMap(alertLabelsTable) ?? fallback.alertLabels,
      travelTimeLabels: try optionalStringMap(travelTimeLabelsTable) ?? fallback.travelTimeLabels,
      startLabel: try optionalString(
        table["start_label"],
        path: "\(rootPath).composer.start_label"
      ) ?? fallback.startLabel,
      endLabel: try optionalString(
        table["end_label"],
        path: "\(rootPath).composer.end_label"
      ) ?? fallback.endLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "\(rootPath).composer.all_day_label"
      ) ?? fallback.allDayLabel,
      travelTimeLabel: try optionalString(
        table["travel_time_label"],
        path: "\(rootPath).composer.travel_time_label"
      ) ?? fallback.travelTimeLabel,
      alertLabel: try optionalString(
        table["alert_label"],
        path: "\(rootPath).composer.alert_label"
      ) ?? fallback.alertLabel,
      addAlertLabel: try optionalString(
        table["add_alert_label"],
        path: "\(rootPath).composer.add_alert_label"
      ) ?? fallback.addAlertLabel,
      openCalendarLabel: try optionalString(
        table["open_calendar_label"],
        path: "\(rootPath).composer.open_calendar_label"
      ) ?? fallback.openCalendarLabel,
      cancelLabel: try optionalString(
        table["cancel_label"],
        path: "\(rootPath).composer.cancel_label"
      ) ?? fallback.cancelLabel,
      saveLabel: try optionalString(
        table["save_label"],
        path: "\(rootPath).composer.save_label"
      ) ?? fallback.saveLabel,
      updateLabel: try optionalString(
        table["update_label"],
        path: "\(rootPath).composer.update_label"
      ) ?? fallback.updateLabel,
      removeLabel: try optionalString(
        table["remove_label"],
        path: "\(rootPath).composer.remove_label"
      ) ?? fallback.removeLabel,
      deleteConfirmationTitle: try optionalString(
        table["delete_confirmation_title"],
        path: "\(rootPath).composer.delete_confirmation_title"
      ) ?? fallback.deleteConfirmationTitle,
      deleteConfirmationMessage: try optionalString(
        table["delete_confirmation_message"],
        path: "\(rootPath).composer.delete_confirmation_message"
      ) ?? fallback.deleteConfirmationMessage
    )
  }

}
