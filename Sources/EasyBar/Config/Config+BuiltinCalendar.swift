import Foundation
import TOMLKit

extension Config {

  /// Popup mode used by the unified calendar widget.
  enum CalendarPopupMode: String, CaseIterable {
    case none
    case upcoming
    case month
  }

  /// Popup layout variants for the month calendar popup.
  enum MonthCalendarPopupLayout: String, CaseIterable {
    case calendarAppointmentsHorizontal = "calendar_appointments_horizontal"
    case appointmentsCalendarHorizontal = "appointments_calendar_horizontal"
    case calendarAppointmentsVertical = "calendar_appointments_vertical"
    case appointmentsCalendarVertical = "appointments_calendar_vertical"
  }

  /// Built-in calendar widget config.
  struct CalendarBuiltinConfig {
    struct Filters {
      var includedCalendarNames: [String]
      var excludedCalendarNames: [String]
    }

    struct Appointments {
      var itemIndent: Double
      var eventTextColorHex: String
      var emptyTextColorHex: String
      var secondaryTextColorHex: String
      var travelTextColorHex: String
      var emptyText: String
      var showCalendarName: Bool
      var showAllDayLabel: Bool
      var showHolidayAllDayLabel: Bool
      var allDayLabel: String
      var showLocation: Bool
      var showTravelTime: Bool
      var showEndTime: Bool
      var travelIcon: String
      var travelIconColorHex: String?
      var showAlertIcon: Bool
      var alertIcon: String
      var alertIconColorHex: String?
    }

    struct Birthdays {
      var showBirthdays: Bool
      var birthdaysShowAge: Bool
      var birthdayIcon: String
      var birthdayIconColorHex: String?
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var popupMode: CalendarPopupMode
    var anchor: Anchor
    var filters: Filters
    var appointments: Appointments
    var birthdays: Birthdays
    var upcoming: Upcoming
    var month: Month

    var enabled: Bool {
      get { placement.enabled }
      set { placement.enabled = newValue }
    }

    var position: WidgetPosition {
      get { placement.position }
      set { placement.position = newValue }
    }

    var order: Int {
      get { placement.order }
      set { placement.order = newValue }
    }

    static let `default` = CalendarBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 60
      ),
      style: .init(
        icon: "",
        textColorHex: "#ffffff",
        backgroundColorHex: "#1a1a1a",
        borderColorHex: "#333333",
        borderWidth: 1,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 4,
        spacing: 6,
        opacity: 1
      ),
      popupMode: .month,
      anchor: .init(
        itemFormat: "EEE, MMM d",
        layout: .stack,
        topFormat: "HH:mm",
        bottomFormat: "d. MMM",
        lineSpacing: 0,
        topTextColorHex: "#ffffff",
        bottomTextColorHex: "#d0d0d0"
      ),
      filters: .init(
        includedCalendarNames: [],
        excludedCalendarNames: []
      ),
      appointments: .init(
        itemIndent: 8,
        eventTextColorHex: "#d0d0d0",
        emptyTextColorHex: "#c0c0c0",
        secondaryTextColorHex: "#91d7e3",
        travelTextColorHex: "#8a8a8a",
        emptyText: "No appointments",
        showCalendarName: false,
        showAllDayLabel: true,
        showHolidayAllDayLabel: false,
        allDayLabel: "All day",
        showLocation: true,
        showTravelTime: true,
        showEndTime: true,
        travelIcon: "",
        travelIconColorHex: "#8a8a8a",
        showAlertIcon: false,
        alertIcon: "",
        alertIconColorHex: "#8a8a8a"
      ),
      birthdays: .init(
        showBirthdays: true,
        birthdaysShowAge: true,
        birthdayIcon: "",
        birthdayIconColorHex: nil
      ),
      upcoming: .init(
        events: .init(
          days: 3,
          excludePastEvents: false
        ),
        popup: .init(
          backgroundColorHex: "#111111",
          borderColorHex: "#444444",
          borderWidth: 1,
          cornerRadius: 10,
          paddingX: 10,
          paddingY: 8,
          spacing: 8,
          marginX: 8,
          marginY: 8
        )
      ),
      month: .init(
        popup: .init(
          style: .init(
            backgroundColorHex: "#111111",
            borderColorHex: "#444444",
            borderWidth: 1,
            cornerRadius: 10,
            paddingX: 10,
            paddingY: 8,
            spacing: 8,
            marginX: 8,
            marginY: 8
          ),
          calendar: .init(
            showWeekNumbers: true,
            showEventIndicators: true,
            headerTextColorHex: "#ffffff",
            weekdayTextColorHex: "#91d7e3",
            firstWeekday: nil,
            weekdayFormat: "dd",
            weekdaySymbols: nil,
            resolvedWeekdaySymbols: Config.resolveMonthWeekdaySymbols(
              format: "dd",
              manualSymbols: nil
            ),
            dayTextColorHex: "#d0d0d0",
            outsideMonthTextColorHex: "#6e738d",
            todayCellBackgroundColorHex: "#00000000",
            todayCellBorderColorHex: "#FF0000",
            todayCellBorderWidth: 1.4,
            indicatorColorHex: "#8bd5ca"
          ),
          selection: .init(
            selectedTextColorHex: "#0B1020",
            selectedBackgroundColorHex: "#89B4FA",
            selectionDateFormat: "yyyy-MM-dd",
            selectionDateSeparator: " - ",
            allowsRangeSelection: true,
            resetSelectionOnThirdTap: true
          ),
          agenda: .init(
            layout: Config.MonthCalendarPopupLayout.calendarAppointmentsVertical,
            appointmentsScrollable: true,
            appointmentsMinHeight: 140,
            appointmentsMaxHeight: 240,
            agendaTitle: "Appointments",
            maxVisibleAppointments: 8
          ),
          anchor: .init(
            dateFormat: "EEE d MMM",
            textColorHex: "#ffffff",
            showDateText: true
          ),
          composer: .init(
            createTitle: "New Appointment",
            editTitle: "Edit Appointment",
            titleLabel: "Title",
            locationLabel: "Location",
            calendarLabel: "Calendar",
            titlePlaceholder: "What are you doing?",
            locationPlaceholder: "Where are you going?",
            defaultCalendarName: nil,
            defaultAlert: "1_hour",
            defaultTravelTime: "none",
            alertLabels: [
              "none": "None",
              "at_time": "At time of event",
              "5_minutes": "5 minutes before",
              "10_minutes": "10 minutes before",
              "15_minutes": "15 minutes before",
              "30_minutes": "30 minutes before",
              "1_hour": "1 hour before",
              "1_day": "1 day before",
              "custom": "Custom",
            ],
            travelTimeLabels: [
              "none": "None",
              "5_minutes": "5 minutes",
              "10_minutes": "10 minutes",
              "15_minutes": "15 minutes",
              "20_minutes": "20 minutes",
              "30_minutes": "30 minutes",
              "45_minutes": "45 minutes",
              "1_hour": "1 hour",
              "90_minutes": "1.5 hours",
              "2_hours": "2 hours",
              "custom": "Custom",
            ],
            startLabel: "Begin",
            endLabel: "End",
            allDayLabel: "All day",
            travelTimeLabel: "Travel time",
            alertLabel: "Alert",
            addAlertLabel: "Add alert",
            openCalendarLabel: "Calendar",
            cancelLabel: "Cancel",
            saveLabel: "Save",
            updateLabel: "Update",
            removeLabel: "Remove",
            deleteConfirmationTitle: "Remove appointment?",
            deleteConfirmationMessage: "This action cannot be undone."
          ),
          todayButton: .init(
            title: "Today",
            icon: "",
            borderColorHex: "#3F2F6B",
            borderWidth: 1.5
          )
        )
      )
    )
  }

  /// Parses the built-in calendar widget.
  func parseCalendarBuiltin(from builtins: TOMLTable) throws {
    guard let calendar = builtins["calendar"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: calendar,
      path: "builtins.calendar",
      fallback: builtinCalendar.placement
    )

    let styleTable = calendar["style"]?.table ?? TOMLTable()
    let anchorTable = calendar["anchor"]?.table ?? TOMLTable()
    let filtersTable = calendar["filters"]?.table ?? TOMLTable()
    let appointmentsTable = calendar["appointments"]?.table ?? TOMLTable()
    let birthdaysTable = calendar["birthdays"]?.table ?? TOMLTable()

    let upcomingTable = calendar["upcoming"]?.table ?? TOMLTable()
    let upcomingEventsTable = upcomingTable["events"]?.table ?? TOMLTable()
    let upcomingPopupTable = upcomingTable["popup"]?.table ?? TOMLTable()

    let monthTable = calendar["month"]?.table ?? TOMLTable()
    let monthPopupTable = monthTable["popup"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.calendar.style",
      fallback: builtinCalendar.style
    )

    let popupMode = try parseCalendarPopupMode(
      try optionalString(
        calendar["popup_mode"],
        path: "builtins.calendar.popup_mode"
      ) ?? builtinCalendar.popupMode.rawValue,
      path: "builtins.calendar.popup_mode"
    )

    let anchor = try parseCalendarAnchor(
      from: anchorTable,
      fallback: builtinCalendar.anchor
    )

    let filters = try parseCalendarFilters(
      from: filtersTable,
      fallback: builtinCalendar.filters
    )

    let appointments = try parseCalendarAppointments(
      from: appointmentsTable,
      fallback: builtinCalendar.appointments
    )

    let birthdays = try parseCalendarBirthdays(
      from: birthdaysTable,
      fallback: builtinCalendar.birthdays
    )

    let upcoming = try parseCalendarUpcoming(
      eventsTable: upcomingEventsTable,
      popupTable: upcomingPopupTable,
      fallback: builtinCalendar.upcoming
    )

    let month = try parseCalendarMonth(
      popupTable: monthPopupTable,
      fallback: builtinCalendar.month
    )

    builtinCalendar = CalendarBuiltinConfig(
      placement: placement,
      style: style,
      popupMode: popupMode,
      anchor: anchor,
      filters: filters,
      appointments: appointments,
      birthdays: birthdays,
      upcoming: upcoming,
      month: month
    )
  }

  /// Parses the shared built-in calendar filters block.
  func parseCalendarFilters(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "builtins.calendar.filters.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "builtins.calendar.filters.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames
    )
  }

  /// Parses the shared built-in calendar appointment row settings.
  func parseCalendarAppointments(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.appointments.item_indent"
      ) ?? fallback.itemIndent,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "builtins.calendar.appointments.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "builtins.calendar.appointments.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "builtins.calendar.appointments.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      travelTextColorHex: try optionalString(
        table["travel_text_color"],
        path: "builtins.calendar.appointments.travel_text_color"
      ) ?? fallback.travelTextColorHex,
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.appointments.empty_text"
      ) ?? fallback.emptyText,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.appointments.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "builtins.calendar.appointments.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      showHolidayAllDayLabel: try optionalBool(
        table["show_holiday_all_day_label"],
        path: "builtins.calendar.appointments.show_holiday_all_day_label"
      ) ?? fallback.showHolidayAllDayLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "builtins.calendar.appointments.all_day_label"
      ) ?? fallback.allDayLabel,
      showLocation: try optionalBool(
        table["show_location"],
        path: "builtins.calendar.appointments.show_location"
      ) ?? fallback.showLocation,
      showTravelTime: try optionalBool(
        table["show_travel_time"],
        path: "builtins.calendar.appointments.show_travel_time"
      ) ?? fallback.showTravelTime,
      showEndTime: try optionalBool(
        table["show_end_time"],
        path: "builtins.calendar.appointments.show_end_time"
      ) ?? fallback.showEndTime,
      travelIcon: try optionalString(
        table["travel_icon"],
        path: "builtins.calendar.appointments.travel_icon"
      ) ?? fallback.travelIcon,
      travelIconColorHex: try optionalString(
        table["travel_icon_color"],
        path: "builtins.calendar.appointments.travel_icon_color"
      ) ?? fallback.travelIconColorHex,
      showAlertIcon: try optionalBool(
        table["show_alert_icon"],
        path: "builtins.calendar.appointments.show_alert_icon"
      ) ?? fallback.showAlertIcon,
      alertIcon: try optionalString(
        table["alert_icon"],
        path: "builtins.calendar.appointments.alert_icon"
      ) ?? fallback.alertIcon,
      alertIconColorHex: try optionalString(
        table["alert_icon_color"],
        path: "builtins.calendar.appointments.alert_icon_color"
      ) ?? fallback.alertIconColorHex
    )
  }

  /// Parses the shared built-in calendar birthday settings.
  func parseCalendarBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "builtins.calendar.birthdays.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "builtins.calendar.birthdays.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "builtins.calendar.birthdays.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "builtins.calendar.birthdays.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }
}
