import EasyBarCalendarConfig

extension Config {
  /// Parses the built-in calendar widget.
  func parseCalendarBuiltin(from builtins: ConfigReader) throws {
    guard let calendar = try builtins.optionalSection("calendar") else { return }

    do {
      builtinCalendar = try CalendarBuiltinConfig.parse(
        from: calendar.rawTable,
        fallback: builtinCalendar,
        path: "builtins.calendar"
      ).resolvingThemeColorReferences { [self] value, path in
        try resolvedConfigColor(value, path: path)
      }
    } catch let error as CalendarConfigError {
      throw error.asConfigError
    }
  }
}

extension CalendarConfigError {
  fileprivate var asConfigError: ConfigError {
    switch self {
    case .invalidType(let path, let expected, let actual):
      return .invalidType(path: path, expected: expected, actual: actual)
    case .invalidValue(let path, let message):
      return .invalidValue(path: path, message: message)
    }
  }
}

extension CalendarBuiltinConfig {
  /// Returns a copy with all calendar color references validated and resolved to concrete hex values.
  fileprivate func resolvingThemeColorReferences(
    using resolve: (String, String) throws -> String
  ) throws -> CalendarBuiltinConfig {
    var config = self

    func resolved(_ value: String, _ path: String) throws -> String {
      try resolve(value, path)
    }

    func resolved(_ value: String?, _ path: String) throws -> String? {
      guard let value else { return nil }
      return try resolve(value, path)
    }

    config.style.textColorHex = try resolved(
      config.style.textColorHex,
      "builtins.calendar.style.text_color"
    )
    config.style.backgroundColorHex = try resolved(
      config.style.backgroundColorHex,
      "builtins.calendar.style.background_color"
    )
    config.style.borderColorHex = try resolved(
      config.style.borderColorHex,
      "builtins.calendar.style.border_color"
    )

    config.anchor.topTextColorHex = try resolved(
      config.anchor.topTextColorHex,
      "builtins.calendar.anchor.top_text_color"
    )
    config.anchor.bottomTextColorHex = try resolved(
      config.anchor.bottomTextColorHex,
      "builtins.calendar.anchor.bottom_text_color"
    )

    config.appointments.eventTextColorHex = try resolved(
      config.appointments.eventTextColorHex,
      "builtins.calendar.appointments.event_text_color"
    )
    config.appointments.emptyTextColorHex = try resolved(
      config.appointments.emptyTextColorHex,
      "builtins.calendar.appointments.empty_text_color"
    )
    config.appointments.secondaryTextColorHex = try resolved(
      config.appointments.secondaryTextColorHex,
      "builtins.calendar.appointments.secondary_text_color"
    )
    config.appointments.travelTextColorHex = try resolved(
      config.appointments.travelTextColorHex,
      "builtins.calendar.appointments.travel_text_color"
    )
    config.appointments.locationIconColorHex = try resolved(
      config.appointments.locationIconColorHex,
      "builtins.calendar.appointments.location_icon_color"
    )
    config.appointments.travelIconColorHex = try resolved(
      config.appointments.travelIconColorHex,
      "builtins.calendar.appointments.travel_icon_color"
    )
    config.appointments.alertIconColorHex = try resolved(
      config.appointments.alertIconColorHex,
      "builtins.calendar.appointments.alert_icon_color"
    )

    config.birthdays.birthdayIconColorHex = try resolved(
      config.birthdays.birthdayIconColorHex,
      "builtins.calendar.birthdays.birthday_icon_color"
    )

    config.composer.style.backgroundColorHex = try resolved(
      config.composer.style.backgroundColorHex,
      "builtins.calendar.composer.style.background_color"
    )
    config.composer.style.borderColorHex = try resolved(
      config.composer.style.borderColorHex,
      "builtins.calendar.composer.style.border_color"
    )
    config.composer.style.headerTextColorHex = try resolved(
      config.composer.style.headerTextColorHex,
      "builtins.calendar.composer.style.header_text_color"
    )

    config.upcoming.popup.backgroundColorHex = try resolved(
      config.upcoming.popup.backgroundColorHex,
      "builtins.calendar.upcoming.popup.background_color"
    )
    config.upcoming.popup.borderColorHex = try resolved(
      config.upcoming.popup.borderColorHex,
      "builtins.calendar.upcoming.popup.border_color"
    )

    config.month.popup.style.backgroundColorHex = try resolved(
      config.month.popup.style.backgroundColorHex,
      "builtins.calendar.month.popup.style.background_color"
    )
    config.month.popup.style.borderColorHex = try resolved(
      config.month.popup.style.borderColorHex,
      "builtins.calendar.month.popup.style.border_color"
    )

    config.month.popup.calendar.headerTextColorHex = try resolved(
      config.month.popup.calendar.headerTextColorHex,
      "builtins.calendar.month.popup.calendar.header_text_color"
    )
    config.month.popup.calendar.weekdayTextColorHex = try resolved(
      config.month.popup.calendar.weekdayTextColorHex,
      "builtins.calendar.month.popup.calendar.weekday_text_color"
    )
    config.month.popup.calendar.dayTextColorHex = try resolved(
      config.month.popup.calendar.dayTextColorHex,
      "builtins.calendar.month.popup.calendar.day_text_color"
    )
    config.month.popup.calendar.outsideMonthTextColorHex = try resolved(
      config.month.popup.calendar.outsideMonthTextColorHex,
      "builtins.calendar.month.popup.calendar.outside_month_text_color"
    )
    config.month.popup.calendar.todayCellBackgroundColorHex = try resolved(
      config.month.popup.calendar.todayCellBackgroundColorHex,
      "builtins.calendar.month.popup.calendar.today_cell_background_color"
    )
    config.month.popup.calendar.todayCellBorderColorHex = try resolved(
      config.month.popup.calendar.todayCellBorderColorHex,
      "builtins.calendar.month.popup.calendar.today_cell_border_color"
    )
    config.month.popup.calendar.indicatorColorHex = try resolved(
      config.month.popup.calendar.indicatorColorHex,
      "builtins.calendar.month.popup.calendar.indicator_color"
    )

    config.month.popup.selection.selectedTextColorHex = try resolved(
      config.month.popup.selection.selectedTextColorHex,
      "builtins.calendar.month.popup.selection.selected_text_color"
    )
    config.month.popup.selection.selectedBackgroundColorHex = try resolved(
      config.month.popup.selection.selectedBackgroundColorHex,
      "builtins.calendar.month.popup.selection.selected_background_color"
    )

    config.month.popup.anchor.textColorHex = try resolved(
      config.month.popup.anchor.textColorHex,
      "builtins.calendar.month.popup.anchor.text_color"
    )
    config.month.popup.todayButton.borderColorHex = try resolved(
      config.month.popup.todayButton.borderColorHex,
      "builtins.calendar.month.popup.today_button.border_color"
    )

    return config
  }
}
