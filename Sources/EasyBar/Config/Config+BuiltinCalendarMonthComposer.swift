import Foundation
import TOMLKit

extension Config {

  /// Parses the month popup anchor block.
  func parseCalendarMonthPopupAnchor(
    from anchorTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.AnchorStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.AnchorStyle {
    CalendarBuiltinConfig.Month.Popup.AnchorStyle(
      dateFormat: try optionalString(
        anchorTable["date_format"]
          ?? anchorTable["anchor_date_format"]
          ?? rootTable["anchor_date_format"],
        path: "builtins.calendar.month.popup.anchor.date_format"
      ) ?? fallback.dateFormat,
      textColorHex: try optionalString(
        anchorTable["text_color"]
          ?? anchorTable["anchor_text_color"]
          ?? rootTable["anchor_text_color"],
        path: "builtins.calendar.month.popup.anchor.text_color"
      ) ?? fallback.textColorHex,
      showDateText: try optionalBool(
        anchorTable["show_date_text"]
          ?? anchorTable["anchor_show_date_text"]
          ?? rootTable["anchor_show_date_text"],
        path: "builtins.calendar.month.popup.anchor.show_date_text"
      ) ?? fallback.showDateText
    )
  }

  /// Parses the month popup composer block.
  func parseCalendarMonthPopupComposer(
    from composerTable: TOMLTable,
    alertLabelsTable: TOMLTable,
    travelTimeLabelsTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.ComposerStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.ComposerStyle {
    CalendarBuiltinConfig.Month.Popup.ComposerStyle(
      createTitle: try optionalString(
        composerTable["create_title"] ?? rootTable["composer_create_title"],
        path: "builtins.calendar.month.popup.composer.create_title"
      ) ?? fallback.createTitle,
      editTitle: try optionalString(
        composerTable["edit_title"] ?? rootTable["composer_edit_title"],
        path: "builtins.calendar.month.popup.composer.edit_title"
      ) ?? fallback.editTitle,
      titleLabel: try optionalString(
        composerTable["title_label"] ?? rootTable["composer_title_label"],
        path: "builtins.calendar.month.popup.composer.title_label"
      ) ?? fallback.titleLabel,
      locationLabel: try optionalString(
        composerTable["location_label"] ?? rootTable["composer_location_label"],
        path: "builtins.calendar.month.popup.composer.location_label"
      ) ?? fallback.locationLabel,
      calendarLabel: try optionalString(
        composerTable["calendar_label"] ?? rootTable["composer_calendar_label"],
        path: "builtins.calendar.month.popup.composer.calendar_label"
      ) ?? fallback.calendarLabel,
      titlePlaceholder: try optionalString(
        composerTable["title_placeholder"] ?? rootTable["composer_title_placeholder"],
        path: "builtins.calendar.month.popup.composer.title_placeholder"
      ) ?? fallback.titlePlaceholder,
      locationPlaceholder: try optionalString(
        composerTable["location_placeholder"] ?? rootTable["composer_location_placeholder"],
        path: "builtins.calendar.month.popup.composer.location_placeholder"
      ) ?? fallback.locationPlaceholder,
      defaultCalendarName: try optionalString(
        composerTable["default_calendar_name"] ?? rootTable["composer_default_calendar_name"],
        path: "builtins.calendar.month.popup.composer.default_calendar_name"
      ) ?? fallback.defaultCalendarName,
      defaultAlert: try optionalString(
        composerTable["default_alert"] ?? rootTable["composer_default_alert"],
        path: "builtins.calendar.month.popup.composer.default_alert"
      ) ?? fallback.defaultAlert,
      defaultTravelTime: try optionalString(
        composerTable["default_travel_time"] ?? rootTable["composer_default_travel_time"],
        path: "builtins.calendar.month.popup.composer.default_travel_time"
      ) ?? fallback.defaultTravelTime,
      alertLabels: try parseMonthComposerOptionLabels(
        from: alertLabelsTable,
        path: "builtins.calendar.month.popup.composer.alert_labels",
        fallback: fallback.alertLabels
      ),
      travelTimeLabels: try parseMonthComposerOptionLabels(
        from: travelTimeLabelsTable,
        path: "builtins.calendar.month.popup.composer.travel_time_labels",
        fallback: fallback.travelTimeLabels
      ),
      startLabel: try optionalString(
        composerTable["start_label"] ?? rootTable["composer_start_label"],
        path: "builtins.calendar.month.popup.composer.start_label"
      ) ?? fallback.startLabel,
      endLabel: try optionalString(
        composerTable["end_label"] ?? rootTable["composer_end_label"],
        path: "builtins.calendar.month.popup.composer.end_label"
      ) ?? fallback.endLabel,
      allDayLabel: try optionalString(
        composerTable["all_day_label"] ?? rootTable["composer_all_day_label"],
        path: "builtins.calendar.month.popup.composer.all_day_label"
      ) ?? fallback.allDayLabel,
      travelTimeLabel: try optionalString(
        composerTable["travel_time_label"] ?? rootTable["composer_travel_time_label"],
        path: "builtins.calendar.month.popup.composer.travel_time_label"
      ) ?? fallback.travelTimeLabel,
      alertLabel: try optionalString(
        composerTable["alert_label"] ?? rootTable["composer_alert_label"],
        path: "builtins.calendar.month.popup.composer.alert_label"
      ) ?? fallback.alertLabel,
      addAlertLabel: try optionalString(
        composerTable["add_alert_label"] ?? rootTable["composer_add_alert_label"],
        path: "builtins.calendar.month.popup.composer.add_alert_label"
      ) ?? fallback.addAlertLabel,
      openCalendarLabel: try optionalString(
        composerTable["open_calendar_label"] ?? rootTable["composer_open_calendar_label"],
        path: "builtins.calendar.month.popup.composer.open_calendar_label"
      ) ?? fallback.openCalendarLabel,
      cancelLabel: try optionalString(
        composerTable["cancel_label"] ?? rootTable["composer_cancel_label"],
        path: "builtins.calendar.month.popup.composer.cancel_label"
      ) ?? fallback.cancelLabel,
      saveLabel: try optionalString(
        composerTable["save_label"] ?? rootTable["composer_save_label"],
        path: "builtins.calendar.month.popup.composer.save_label"
      ) ?? fallback.saveLabel,
      updateLabel: try optionalString(
        composerTable["update_label"] ?? rootTable["composer_update_label"],
        path: "builtins.calendar.month.popup.composer.update_label"
      ) ?? fallback.updateLabel,
      removeLabel: try optionalString(
        composerTable["remove_label"] ?? rootTable["composer_remove_label"],
        path: "builtins.calendar.month.popup.composer.remove_label"
      ) ?? fallback.removeLabel,
      deleteConfirmationTitle: try optionalString(
        composerTable["delete_confirmation_title"]
          ?? rootTable["composer_delete_confirmation_title"],
        path: "builtins.calendar.month.popup.composer.delete_confirmation_title"
      ) ?? fallback.deleteConfirmationTitle,
      deleteConfirmationMessage: try optionalString(
        composerTable["delete_confirmation_message"]
          ?? rootTable["composer_delete_confirmation_message"],
        path: "builtins.calendar.month.popup.composer.delete_confirmation_message"
      ) ?? fallback.deleteConfirmationMessage
    )
  }

  /// Parses the month popup today-button block.
  func parseCalendarMonthPopupTodayButton(
    from todayButtonTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.TodayButtonStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.TodayButtonStyle {
    CalendarBuiltinConfig.Month.Popup.TodayButtonStyle(
      title: try optionalString(
        todayButtonTable["title"] ?? rootTable["today_button_title"],
        path: "builtins.calendar.month.popup.today_button.title"
      ) ?? fallback.title,
      icon: try optionalString(
        todayButtonTable["icon"] ?? rootTable["today_button_icon"],
        path: "builtins.calendar.month.popup.today_button.icon"
      ) ?? fallback.icon,
      borderColorHex: try optionalString(
        todayButtonTable["border_color"] ?? rootTable["today_border_color"],
        path: "builtins.calendar.month.popup.today_button.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        todayButtonTable["border_width"] ?? rootTable["today_border_width"],
        path: "builtins.calendar.month.popup.today_button.border_width"
      ) ?? fallback.borderWidth
    )
  }

  /// Parses one composer option-label map from a TOML table.
  private func parseMonthComposerOptionLabels(
    from table: TOMLTable,
    path: String,
    fallback: [String: String]
  ) throws -> [String: String] {
    guard !table.isEmpty else { return fallback }

    var labels = fallback
    for (key, value) in table {
      labels[key] = try optionalString(value, path: "\(path).\(key)") ?? labels[key]
    }

    return labels
  }
}
