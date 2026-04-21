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
    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var popupMode: CalendarPopupMode
    var anchor: Anchor
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
      upcoming: .init(
        events: .init(
          days: 3,
          emptyText: "No upcoming events"
        ),
        birthdays: .init(
          show: true,
          title: "Birthdays",
          dateFormat: "dd.MM.yyyy",
          showAge: false
        ),
        popup: .init(
          backgroundColorHex: "#111111",
          borderColorHex: "#444444",
          borderWidth: 1,
          cornerRadius: 10,
          paddingX: 10,
          paddingY: 8,
          spacing: 8,
          itemIndent: 8,
          marginX: 8,
          marginY: 8,
          showCalendarName: true,
          useCalendarColors: true,
          birthdays: .init(
            titleColorHex: "#89CFEF",
            itemColorHex: "#7285A5",
            emptyColorHex: "#c0c0c0"
          ),
          today: .init(
            titleColorHex: "#5F9EA0",
            itemColorHex: "#d0d0d0",
            emptyColorHex: "#c0c0c0"
          ),
          tomorrow: .init(
            titleColorHex: "#8bd5ca",
            itemColorHex: "#cfeee8",
            emptyColorHex: "#c0c0c0"
          ),
          future: .init(
            titleColorHex: "#91d7e3",
            itemColorHex: "#d0d0d0",
            emptyColorHex: "#c0c0c0"
          )
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
            itemIndent: 8,
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
            eventTextColorHex: "#d0d0d0",
            emptyTextColorHex: "#c0c0c0",
            secondaryTextColorHex: "#91d7e3",
            travelTextColorHex: "#8a8a8a",
            layout: Config.MonthCalendarPopupLayout.calendarAppointmentsVertical,
            appointmentsScrollable: true,
            appointmentsMinHeight: 140,
            appointmentsMaxHeight: 240,
            emptyText: "No appointments",
            agendaTitle: "Appointments",
            showCalendarName: false,
            showAllDayLabel: true,
            showHolidayAllDayLabel: false,
            allDayLabel: "All day",
            showLocation: true,
            showTravelTime: true,
            travelIcon: "",
            travelIconColorHex: "#8a8a8a",
            showAlertIcon: false,
            alertIcon: "",
            alertIconColorHex: "#8a8a8a",
            maxVisibleAppointments: 8
          ),
          birthdays: .init(
            showBirthdays: true,
            birthdaysShowAge: true,
            birthdayIcon: "",
            birthdayIconColorHex: nil
          ),
          filters: .init(
            includedCalendarNames: [],
            excludedCalendarNames: []
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

    let upcomingTable = calendar["upcoming"]?.table ?? TOMLTable()
    let upcomingEventsTable = upcomingTable["events"]?.table ?? TOMLTable()
    let upcomingBirthdaysTable = upcomingTable["birthdays"]?.table ?? TOMLTable()
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

    let upcoming = try parseCalendarUpcoming(
      eventsTable: upcomingEventsTable,
      birthdaysTable: upcomingBirthdaysTable,
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
      upcoming: upcoming,
      month: month
    )
  }
}
