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
    ).resolvingThemeColorReferences { [self] value in
      resolveThemeColorHex(value) ?? value
    }
  }
}

extension CalendarBuiltinConfig {
  /// Returns a copy with all calendar color references resolved to concrete hex values.
  fileprivate func resolvingThemeColorReferences(
    using resolve: (String) -> String
  ) -> CalendarBuiltinConfig {
    var config = self

    config.style.textColorHex = config.style.textColorHex.map(resolve)
    config.style.backgroundColorHex = config.style.backgroundColorHex.map(resolve)
    config.style.borderColorHex = config.style.borderColorHex.map(resolve)

    config.anchor.topTextColorHex = config.anchor.topTextColorHex.map(resolve)
    config.anchor.bottomTextColorHex = config.anchor.bottomTextColorHex.map(resolve)

    config.appointments.eventTextColorHex = resolve(config.appointments.eventTextColorHex)
    config.appointments.emptyTextColorHex = resolve(config.appointments.emptyTextColorHex)
    config.appointments.secondaryTextColorHex = resolve(config.appointments.secondaryTextColorHex)
    config.appointments.travelTextColorHex = resolve(config.appointments.travelTextColorHex)
    config.appointments.locationIconColorHex = config.appointments.locationIconColorHex.map(resolve)
    config.appointments.travelIconColorHex = config.appointments.travelIconColorHex.map(resolve)
    config.appointments.alertIconColorHex = config.appointments.alertIconColorHex.map(resolve)

    config.birthdays.birthdayIconColorHex = config.birthdays.birthdayIconColorHex.map(resolve)

    config.composer.style.backgroundColorHex = resolve(config.composer.style.backgroundColorHex)
    config.composer.style.borderColorHex = resolve(config.composer.style.borderColorHex)
    config.composer.style.headerTextColorHex = resolve(config.composer.style.headerTextColorHex)

    config.upcoming.popup.backgroundColorHex = resolve(config.upcoming.popup.backgroundColorHex)
    config.upcoming.popup.borderColorHex = resolve(config.upcoming.popup.borderColorHex)

    config.month.popup.style.backgroundColorHex = resolve(
      config.month.popup.style.backgroundColorHex)
    config.month.popup.style.borderColorHex = resolve(config.month.popup.style.borderColorHex)

    config.month.popup.calendar.headerTextColorHex = resolve(
      config.month.popup.calendar.headerTextColorHex
    )
    config.month.popup.calendar.weekdayTextColorHex = resolve(
      config.month.popup.calendar.weekdayTextColorHex
    )
    config.month.popup.calendar.dayTextColorHex = resolve(
      config.month.popup.calendar.dayTextColorHex
    )
    config.month.popup.calendar.outsideMonthTextColorHex = resolve(
      config.month.popup.calendar.outsideMonthTextColorHex
    )
    config.month.popup.calendar.todayCellBackgroundColorHex = resolve(
      config.month.popup.calendar.todayCellBackgroundColorHex
    )
    config.month.popup.calendar.todayCellBorderColorHex = resolve(
      config.month.popup.calendar.todayCellBorderColorHex
    )
    config.month.popup.calendar.indicatorColorHex = resolve(
      config.month.popup.calendar.indicatorColorHex
    )

    config.month.popup.selection.selectedTextColorHex = resolve(
      config.month.popup.selection.selectedTextColorHex
    )
    config.month.popup.selection.selectedBackgroundColorHex = resolve(
      config.month.popup.selection.selectedBackgroundColorHex
    )

    config.month.popup.anchor.textColorHex = config.month.popup.anchor.textColorHex.map(resolve)
    config.month.popup.todayButton.borderColorHex = resolve(
      config.month.popup.todayButton.borderColorHex
    )

    return config
  }
}
