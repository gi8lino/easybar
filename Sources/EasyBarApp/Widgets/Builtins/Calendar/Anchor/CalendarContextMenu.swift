import EasyBarCalendarConfig
import Foundation

/// Session actions exposed by the native calendar context menu.
enum CalendarContextMenuAction: Equatable {
  case setPopupMode(CalendarPopupMode)
  case setAnchorLayout(CalendarAnchorLayout)
  case toggleAnchorField(CalendarAnchorFieldKind)
  case toggleAppointmentOption(String)
  case toggleBirthdayOption(String)
  case refresh
  case openCalendarSettings
  case resetToConfig

  init?(id: String) {
    if let value = id.removingPrefix("calendar.popup."),
      let mode = CalendarPopupMode(rawValue: value)
    {
      self = .setPopupMode(mode)
      return
    }
    if let value = id.removingPrefix("calendar.layout."),
      let layout = CalendarAnchorLayout(rawValue: value)
    {
      self = .setAnchorLayout(layout)
      return
    }
    if let value = id.removingPrefix("calendar.anchor_field."),
      let field = CalendarAnchorFieldKind(rawValue: value)
    {
      self = .toggleAnchorField(field)
      return
    }
    if let option = id.removingPrefix("calendar.appointment."),
      appointmentOptions.contains(where: { $0.id == option })
    {
      self = .toggleAppointmentOption(option)
      return
    }
    if let option = id.removingPrefix("calendar.birthday."),
      birthdayOptions.contains(where: { $0.id == option })
    {
      self = .toggleBirthdayOption(option)
      return
    }

    switch id {
    case "calendar.refresh": self = .refresh
    case "calendar.open_settings": self = .openCalendarSettings
    case "calendar.reset_to_config": self = .resetToConfig
    default: return nil
    }
  }
}

/// Builds the calendar menu from its effective session configuration.
enum CalendarContextMenu {
  static func make(
    config: Config.CalendarBuiltinConfig,
    hasSessionOverrides: Bool
  ) -> [WidgetContextMenuItem] {
    let popupModes = CalendarPopupMode.allCases.map { mode in
      WidgetContextMenuItem(
        id: "calendar.popup.\(mode.rawValue)",
        title: popupModeTitle(mode),
        checked: config.popupMode == mode
      )
    }
    let layouts = CalendarAnchorLayout.allCases.map { layout in
      WidgetContextMenuItem(
        id: "calendar.layout.\(layout.rawValue)",
        title: layout.rawValue.capitalized,
        checked: config.anchor.layout == layout
      )
    }
    let anchorFields = CalendarAnchorFieldKind.allCases.map { field in
      let selected = config.anchor.fields.contains(field)
      return WidgetContextMenuItem(
        id: "calendar.anchor_field.\(field.rawValue)",
        title: field.rawValue.capitalized,
        enabled: !selected || config.anchor.fields.count > 1,
        checked: selected
      )
    }

    return [
      WidgetContextMenuItem(title: "Popup", submenu: popupModes),
      WidgetContextMenuItem(title: "Anchor Layout", submenu: layouts),
      WidgetContextMenuItem(title: "Anchor Fields", submenu: anchorFields),
      WidgetContextMenuItem(
        title: "Appointment Details",
        submenu: appointmentMenu(config.appointments)
      ),
      WidgetContextMenuItem(
        title: "Birthdays",
        submenu: birthdayMenu(config.birthdays)
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(id: "calendar.refresh", title: "Refresh"),
      WidgetContextMenuItem(id: "calendar.open_settings", title: "Open Calendar Settings"),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "calendar.reset_to_config",
        title: "Reset to Config",
        enabled: hasSessionOverrides
      ),
    ]
  }

  private static func popupModeTitle(_ mode: CalendarPopupMode) -> String {
    switch mode {
    case .none: "None"
    case .upcoming: "Upcoming"
    case .month: "Month"
    }
  }

  private static func appointmentMenu(
    _ appointments: CalendarBuiltinConfig.Appointments
  ) -> [WidgetContextMenuItem] {
    appointmentOptions.map { option in
      WidgetContextMenuItem(
        id: "calendar.appointment.\(option.id)",
        title: option.title,
        checked: option.value(appointments)
      )
    }
  }

  private static func birthdayMenu(
    _ birthdays: CalendarBuiltinConfig.Birthdays
  ) -> [WidgetContextMenuItem] {
    birthdayOptions.map { option in
      WidgetContextMenuItem(
        id: "calendar.birthday.\(option.id)",
        title: option.title,
        enabled: option.id != "show_age" || birthdays.showBirthdays,
        checked: option.value(birthdays)
      )
    }
  }
}

struct CalendarAppointmentMenuOption {
  let id: String
  let title: String
  let keyPath: WritableKeyPath<CalendarBuiltinConfig.Appointments, Bool>

  func value(_ appointments: CalendarBuiltinConfig.Appointments) -> Bool {
    appointments[keyPath: keyPath]
  }
}

struct CalendarBirthdayMenuOption {
  let id: String
  let title: String
  let keyPath: WritableKeyPath<CalendarBuiltinConfig.Birthdays, Bool>

  func value(_ birthdays: CalendarBuiltinConfig.Birthdays) -> Bool {
    birthdays[keyPath: keyPath]
  }
}

nonisolated(unsafe) let appointmentOptions: [CalendarAppointmentMenuOption] = [
  .init(id: "calendar_name", title: "Calendar Name", keyPath: \.showCalendarName),
  .init(id: "all_day_label", title: "All-day Label", keyPath: \.showAllDayLabel),
  .init(id: "location", title: "Location", keyPath: \.showLocation),
  .init(id: "travel_time", title: "Travel Time", keyPath: \.showTravelTime),
  .init(id: "end_time", title: "End Time", keyPath: \.showEndTime),
  .init(id: "alert_icon", title: "Alert Icon", keyPath: \.showAlertIcon),
]

nonisolated(unsafe) let birthdayOptions: [CalendarBirthdayMenuOption] = [
  .init(id: "show_birthdays", title: "Show Birthdays", keyPath: \.showBirthdays),
  .init(id: "show_age", title: "Show Age", keyPath: \.birthdaysShowAge),
]

extension String {
  fileprivate func removingPrefix(_ prefix: String) -> String? {
    guard hasPrefix(prefix) else { return nil }
    let suffix = String(dropFirst(prefix.count))
    return suffix.isEmpty ? nil : suffix
  }
}
