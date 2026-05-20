import EasyBarCalendarUI
import Foundation

extension Config.CalendarBuiltinConfig.Appointments {
  var calendarUIStyle: CalendarAppointmentsStyle {
    CalendarAppointmentsStyle(
      secondaryTextColorHex: secondaryTextColorHex,
      emptyTextColorHex: emptyTextColorHex,
      eventTextColorHex: eventTextColorHex,
      travelTextColorHex: travelTextColorHex,
      travelIconColorHex: travelIconColorHex,
      alertIconColorHex: alertIconColorHex,
      showCalendarName: showCalendarName,
      showLocation: showLocation,
      showTravelTime: showTravelTime,
      showEndTime: showEndTime,
      showAlertIcon: showAlertIcon,
      showAllDayLabel: showAllDayLabel,
      allDayLabel: allDayLabel,
      showHolidayAllDayLabel: showHolidayAllDayLabel,
      alertIcon: alertIcon,
      travelIcon: travelIcon,
      itemIndent: itemIndent
    )
  }
}

extension Config.CalendarBuiltinConfig.Composer {
  var calendarUIConfig: CalendarComposerConfig {
    CalendarComposerConfig(
      createTitle: createTitle,
      editTitle: editTitle,
      saveLabel: saveLabel,
      updateLabel: updateLabel,
      removeLabel: removeLabel,
      cancelLabel: cancelLabel,
      deleteConfirmationTitle: deleteConfirmationTitle,
      deleteConfirmationMessage: deleteConfirmationMessage,
      openCalendarLabel: openCalendarLabel,
      titleLabel: titleLabel,
      titlePlaceholder: titlePlaceholder,
      locationLabel: locationLabel,
      locationPlaceholder: locationPlaceholder,
      calendarLabel: calendarLabel,
      allDayLabel: allDayLabel,
      startLabel: startLabel,
      endLabel: endLabel,
      travelTimeLabel: travelTimeLabel,
      alertLabel: alertLabel,
      addAlertLabel: addAlertLabel,
      defaultCalendarName: defaultCalendarName,
      defaultAlert: defaultAlert,
      defaultTravelTime: defaultTravelTime,
      alertLabels: alertLabels,
      travelTimeLabels: travelTimeLabels,
      paddingX: paddingX,
      paddingY: paddingY,
      backgroundColorHex: backgroundColorHex,
      borderColorHex: borderColorHex,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      headerTextColorHex: headerTextColorHex,
      secondaryTextColorHex: Config.shared.builtinCalendar.appointments.secondaryTextColorHex
    )
  }
}

extension Config.CalendarBuiltinConfig.Birthdays {
  var calendarBirthdayStyle: CalendarBirthdayStyle {
    CalendarBirthdayStyle(
      birthdayIcon: birthdayIcon,
      birthdayIconColorHex: birthdayIconColorHex
    )
  }
}

extension Config.CalendarBuiltinConfig.Month.Popup {
  var calendarMonthPopupConfig: CalendarMonthPopupConfig {
    CalendarMonthPopupConfig(
      backgroundColorHex: backgroundColorHex,
      borderColorHex: borderColorHex,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      paddingX: paddingX,
      paddingY: paddingY,
      spacing: spacing,
      marginX: marginX,
      marginY: marginY,
      showWeekNumbers: showWeekNumbers,
      showEventIndicators: showEventIndicators,
      headerTextColorHex: headerTextColorHex,
      weekdayTextColorHex: weekdayTextColorHex,
      firstWeekday: firstWeekday,
      resolvedWeekdaySymbols: resolvedWeekdaySymbols,
      dayTextColorHex: dayTextColorHex,
      outsideMonthTextColorHex: outsideMonthTextColorHex,
      todayCellBackgroundColorHex: todayCellBackgroundColorHex,
      todayCellBorderColorHex: todayCellBorderColorHex,
      todayCellBorderWidth: todayCellBorderWidth,
      indicatorColorHex: indicatorColorHex,
      selectedTextColorHex: selectedTextColorHex,
      selectedBackgroundColorHex: selectedBackgroundColorHex,
      selectionDateFormat: selectionDateFormat,
      selectionDateSeparator: selectionDateSeparator,
      allowsRangeSelection: allowsRangeSelection,
      resetSelectionOnThirdTap: resetSelectionOnThirdTap,
      layout: layout.calendarMonthPopupLayout,
      appointmentsScrollable: appointmentsScrollable,
      appointmentsMinHeight: appointmentsMinHeight,
      appointmentsMaxHeight: appointmentsMaxHeight,
      agendaTitle: agendaTitle,
      maxVisibleAppointments: maxVisibleAppointments,
      anchorDateFormat: anchorDateFormat,
      anchorTextColorHex: anchorTextColorHex,
      anchorShowDateText: anchorShowDateText,
      todayButtonTitle: todayButtonTitle,
      todayButtonIcon: todayButtonIcon,
      todayButtonBorderColorHex: todayButtonBorderColorHex,
      todayButtonBorderWidth: todayButtonBorderWidth
    )
  }
}

extension Config.CalendarBuiltinConfig {
  var calendarUpcomingPopupConfig: CalendarUpcomingPopupConfig {
    CalendarUpcomingPopupConfig(
      days: upcoming.events.days,
      excludePastEvents: upcoming.events.excludePastEvents,
      backgroundColorHex: upcoming.popup.backgroundColorHex,
      borderColorHex: upcoming.popup.borderColorHex,
      borderWidth: upcoming.popup.borderWidth,
      cornerRadius: upcoming.popup.cornerRadius,
      paddingX: upcoming.popup.paddingX,
      paddingY: upcoming.popup.paddingY,
      spacing: upcoming.popup.spacing,
      marginX: upcoming.popup.marginX,
      marginY: upcoming.popup.marginY,
      firstWeekday: month.popup.firstWeekday,
      selectionDateFormat: month.popup.selectionDateFormat,
      defaultIndicatorColorHex: month.popup.indicatorColorHex
    )
  }
}

extension Config.MonthCalendarPopupLayout {
  var calendarMonthPopupLayout: CalendarMonthPopupLayout {
    switch self {
    case .calendarAppointmentsHorizontal:
      return .calendarAppointmentsHorizontal
    case .appointmentsCalendarHorizontal:
      return .appointmentsCalendarHorizontal
    case .calendarAppointmentsVertical:
      return .calendarAppointmentsVertical
    case .appointmentsCalendarVertical:
      return .appointmentsCalendarVertical
    }
  }
}
