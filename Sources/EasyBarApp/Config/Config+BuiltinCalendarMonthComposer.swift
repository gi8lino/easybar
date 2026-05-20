import Foundation
import TOMLKit

extension Config {

  /// Parses the shared calendar event-composer block.
  func parseCalendarComposer(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer
  ) throws -> CalendarBuiltinConfig.Composer {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let alertLabelsTable = table["alert_labels"]?.table ?? TOMLTable()
    let travelTimeLabelsTable = table["travel_time_labels"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Composer(
      style: try parseCalendarComposerStyle(
        from: styleTable,
        fallback: fallback.style
      ),
      content: try parseCalendarComposerContent(
        from: table,
        alertLabelsTable: alertLabelsTable,
        travelTimeLabelsTable: travelTimeLabelsTable,
        fallback: fallback.content
      )
    )
  }

  /// Parses the shared calendar event-composer style block.
  func parseCalendarComposerStyle(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Style
  ) throws -> CalendarBuiltinConfig.Composer.Style {
    CalendarBuiltinConfig.Composer.Style(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.composer.style.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.composer.style.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.composer.style.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.composer.style.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.composer.style.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.composer.style.padding_y"
      ) ?? fallback.paddingY,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "builtins.calendar.composer.style.header_text_color"
      ) ?? fallback.headerTextColorHex
    )
  }

  /// Parses the shared calendar event-composer labels and defaults.
  func parseCalendarComposerContent(
    from table: TOMLTable,
    alertLabelsTable: TOMLTable,
    travelTimeLabelsTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Content
  ) throws -> CalendarBuiltinConfig.Composer.Content {
    CalendarBuiltinConfig.Composer.Content(
      createTitle: try optionalString(
        table["create_title"],
        path: "builtins.calendar.composer.create_title"
      ) ?? fallback.createTitle,
      editTitle: try optionalString(
        table["edit_title"],
        path: "builtins.calendar.composer.edit_title"
      ) ?? fallback.editTitle,
      titleLabel: try optionalString(
        table["title_label"],
        path: "builtins.calendar.composer.title_label"
      ) ?? fallback.titleLabel,
      locationLabel: try optionalString(
        table["location_label"],
        path: "builtins.calendar.composer.location_label"
      ) ?? fallback.locationLabel,
      calendarLabel: try optionalString(
        table["calendar_label"],
        path: "builtins.calendar.composer.calendar_label"
      ) ?? fallback.calendarLabel,
      titlePlaceholder: try optionalString(
        table["title_placeholder"],
        path: "builtins.calendar.composer.title_placeholder"
      ) ?? fallback.titlePlaceholder,
      locationPlaceholder: try optionalString(
        table["location_placeholder"],
        path: "builtins.calendar.composer.location_placeholder"
      ) ?? fallback.locationPlaceholder,
      defaultCalendarName: try optionalString(
        table["default_calendar_name"],
        path: "builtins.calendar.composer.default_calendar_name"
      ) ?? fallback.defaultCalendarName,
      defaultAlert: try optionalString(
        table["default_alert"],
        path: "builtins.calendar.composer.default_alert"
      ) ?? fallback.defaultAlert,
      defaultTravelTime: try optionalString(
        table["default_travel_time"],
        path: "builtins.calendar.composer.default_travel_time"
      ) ?? fallback.defaultTravelTime,
      alertLabels: try parseCalendarComposerOptionLabels(
        from: alertLabelsTable,
        path: "builtins.calendar.composer.alert_labels",
        fallback: fallback.alertLabels
      ),
      travelTimeLabels: try parseCalendarComposerOptionLabels(
        from: travelTimeLabelsTable,
        path: "builtins.calendar.composer.travel_time_labels",
        fallback: fallback.travelTimeLabels
      ),
      startLabel: try optionalString(
        table["start_label"],
        path: "builtins.calendar.composer.start_label"
      ) ?? fallback.startLabel,
      endLabel: try optionalString(
        table["end_label"],
        path: "builtins.calendar.composer.end_label"
      ) ?? fallback.endLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "builtins.calendar.composer.all_day_label"
      ) ?? fallback.allDayLabel,
      travelTimeLabel: try optionalString(
        table["travel_time_label"],
        path: "builtins.calendar.composer.travel_time_label"
      ) ?? fallback.travelTimeLabel,
      alertLabel: try optionalString(
        table["alert_label"],
        path: "builtins.calendar.composer.alert_label"
      ) ?? fallback.alertLabel,
      addAlertLabel: try optionalString(
        table["add_alert_label"],
        path: "builtins.calendar.composer.add_alert_label"
      ) ?? fallback.addAlertLabel,
      openCalendarLabel: try optionalString(
        table["open_calendar_label"],
        path: "builtins.calendar.composer.open_calendar_label"
      ) ?? fallback.openCalendarLabel,
      cancelLabel: try optionalString(
        table["cancel_label"],
        path: "builtins.calendar.composer.cancel_label"
      ) ?? fallback.cancelLabel,
      saveLabel: try optionalString(
        table["save_label"],
        path: "builtins.calendar.composer.save_label"
      ) ?? fallback.saveLabel,
      updateLabel: try optionalString(
        table["update_label"],
        path: "builtins.calendar.composer.update_label"
      ) ?? fallback.updateLabel,
      removeLabel: try optionalString(
        table["remove_label"],
        path: "builtins.calendar.composer.remove_label"
      ) ?? fallback.removeLabel,
      deleteConfirmationTitle: try optionalString(
        table["delete_confirmation_title"],
        path: "builtins.calendar.composer.delete_confirmation_title"
      ) ?? fallback.deleteConfirmationTitle,
      deleteConfirmationMessage: try optionalString(
        table["delete_confirmation_message"],
        path: "builtins.calendar.composer.delete_confirmation_message"
      ) ?? fallback.deleteConfirmationMessage
    )
  }

  /// Parses one composer option-label map from a TOML table.
  private func parseCalendarComposerOptionLabels(
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
