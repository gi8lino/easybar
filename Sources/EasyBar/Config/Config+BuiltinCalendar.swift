import Foundation
import TOMLKit

extension Config {

  /// Popup mode used by the unified calendar widget.
  enum CalendarPopupMode: String {
    case none
    case upcoming
    case month
  }

  /// Popup layout variants for the month calendar popup.
  enum MonthCalendarPopupLayout: String {
    case calendarAppointmentsHorizontal = "calendar_appointments_horizontal"
    case appointmentsCalendarHorizontal = "appointments_calendar_horizontal"
    case calendarAppointmentsVertical = "calendar_appointments_vertical"
    case appointmentsCalendarVertical = "appointments_calendar_vertical"
  }

  /// Built-in calendar widget config.
  struct CalendarBuiltinConfig {
    struct Anchor {
      var itemFormat: String
      var layout: CalendarAnchorLayout
      var topFormat: String
      var bottomFormat: String
      var lineSpacing: Double
      var topTextColorHex: String?
      var bottomTextColorHex: String?
    }

    struct Upcoming {
      struct Events {
        var days: Int
        var emptyText: String
      }

      struct Birthdays {
        var show: Bool
        var title: String
        var dateFormat: String
        var showAge: Bool
      }

      struct PopupSectionStyle {
        var titleColorHex: String
        var itemColorHex: String
        var emptyColorHex: String
      }

      struct Popup {
        var backgroundColorHex: String
        var borderColorHex: String
        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var spacing: Double
        var itemIndent: Double
        var marginX: Double
        var marginY: Double
        var showCalendarName: Bool
        var useCalendarColors: Bool
        var birthdays: PopupSectionStyle
        var today: PopupSectionStyle
        var tomorrow: PopupSectionStyle
        var future: PopupSectionStyle
      }

      var events: Events
      var birthdays: Birthdays
      var popup: Popup
    }

    struct Month {
      struct Popup {
        var backgroundColorHex: String
        var borderColorHex: String
        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var spacing: Double
        var itemIndent: Double
        var marginX: Double
        var marginY: Double
        var showWeekNumbers: Bool
        var showEventIndicators: Bool
        var headerTextColorHex: String
        var weekdayTextColorHex: String
        var firstWeekday: Int?
        var dayTextColorHex: String
        var outsideMonthTextColorHex: String
        var selectedTextColorHex: String
        var selectedBackgroundColorHex: String
        var todayBackgroundColorHex: String
        var indicatorColorHex: String
        var eventTextColorHex: String
        var emptyTextColorHex: String
        var secondaryTextColorHex: String
        var layout: MonthCalendarPopupLayout
        var appointmentsScrollable: Bool
        var appointmentsMinHeight: Double
        var appointmentsMaxHeight: Double
        var emptyText: String
        var agendaTitle: String
        var showCalendarName: Bool
        var showAllDayLabel: Bool
        var allowsRangeSelection: Bool
        var resetSelectionOnThirdTap: Bool
        var maxVisibleAppointments: Int
        var includedCalendarNames: [String]
        var excludedCalendarNames: [String]
        var anchorDateFormat: String
        var anchorTextColorHex: String?
        var anchorShowDateText: Bool
        var weekdayFormat: String
        var weekdaySymbols: [String]?
        var resolvedWeekdaySymbols: [String]
        var showBirthdays: Bool
        var birthdaysShowAge: Bool
        var birthdayIcon: String
        var birthdayIconColorHex: String?
      }

      var popup: Popup
    }

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
      popupMode: .upcoming,
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
          showWeekNumbers: true,
          showEventIndicators: true,
          headerTextColorHex: "#ffffff",
          weekdayTextColorHex: "#91d7e3",
          firstWeekday: nil,
          dayTextColorHex: "#d0d0d0",
          outsideMonthTextColorHex: "#6e738d",
          selectedTextColorHex: "#111111",
          selectedBackgroundColorHex: "#8bd5ca",
          todayBackgroundColorHex: "#8bd5ca33",
          indicatorColorHex: "#8bd5ca",
          eventTextColorHex: "#d0d0d0",
          emptyTextColorHex: "#c0c0c0",
          secondaryTextColorHex: "#91d7e3",
          layout: .calendarAppointmentsVertical,
          appointmentsScrollable: true,
          appointmentsMinHeight: 180,
          appointmentsMaxHeight: 240,
          emptyText: "No appointments",
          agendaTitle: "Appointments",
          showCalendarName: false,
          showAllDayLabel: true,
          allowsRangeSelection: true,
          resetSelectionOnThirdTap: true,
          maxVisibleAppointments: 8,
          includedCalendarNames: [],
          excludedCalendarNames: [],
          anchorDateFormat: "EEE d MMM",
          anchorTextColorHex: "#ffffff",
          anchorShowDateText: true,
          weekdayFormat: "dd",
          weekdaySymbols: nil,
          resolvedWeekdaySymbols: Config.resolveMonthWeekdaySymbols(
            format: "dd",
            manualSymbols: nil
          ),
          showBirthdays: true,
          birthdaysShowAge: true,
          birthdayIcon: "",
          birthdayIconColorHex: nil
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

    let popupMode = normalizedCalendarPopupMode(
      try optionalString(
        calendar["popup_mode"],
        path: "builtins.calendar.popup_mode"
      ) ?? builtinCalendar.popupMode.rawValue
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

  /// Parses the calendar anchor block.
  private func parseCalendarAnchor(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try optionalString(
        table["item_format"],
        path: "builtins.calendar.anchor.item_format"
      ) ?? fallback.itemFormat,
      layout: normalizedCalendarLayout(
        try optionalString(
          table["layout"],
          path: "builtins.calendar.anchor.layout"
        ) ?? fallback.layout.rawValue
      ),
      topFormat: try optionalString(
        table["top_format"],
        path: "builtins.calendar.anchor.top_format"
      ) ?? fallback.topFormat,
      bottomFormat: try optionalString(
        table["bottom_format"],
        path: "builtins.calendar.anchor.bottom_format"
      ) ?? fallback.bottomFormat,
      lineSpacing: try optionalNumber(
        table["line_spacing"],
        path: "builtins.calendar.anchor.line_spacing"
      ) ?? fallback.lineSpacing,
      topTextColorHex: try optionalString(
        table["top_text_color"],
        path: "builtins.calendar.anchor.top_text_color"
      ) ?? fallback.topTextColorHex,
      bottomTextColorHex: try optionalString(
        table["bottom_text_color"],
        path: "builtins.calendar.anchor.bottom_text_color"
      ) ?? fallback.bottomTextColorHex
    )
  }

  /// Parses the upcoming calendar mode.
  private func parseCalendarUpcoming(
    eventsTable: TOMLTable,
    birthdaysTable: TOMLTable,
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseCalendarUpcomingEvents(
        from: eventsTable,
        fallback: fallback.events
      ),
      birthdays: try parseCalendarUpcomingBirthdays(
        from: birthdaysTable,
        fallback: fallback.birthdays
      ),
      popup: try parseCalendarUpcomingPopup(
        from: popupTable,
        fallback: fallback.popup
      )
    )
  }

  /// Parses the upcoming events block.
  private func parseCalendarUpcomingEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "builtins.calendar.upcoming.events.days"
        ) ?? fallback.days
      ),
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.upcoming.events.empty_text"
      ) ?? fallback.emptyText
    )
  }

  /// Parses the upcoming birthdays block.
  private func parseCalendarUpcomingBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Birthdays
  ) throws -> CalendarBuiltinConfig.Upcoming.Birthdays {
    CalendarBuiltinConfig.Upcoming.Birthdays(
      show: try optionalBool(
        table["show"],
        path: "builtins.calendar.upcoming.birthdays.show"
      ) ?? fallback.show,
      title: try optionalString(
        table["title"],
        path: "builtins.calendar.upcoming.birthdays.title"
      ) ?? fallback.title,
      dateFormat: try optionalString(
        table["date_format"],
        path: "builtins.calendar.upcoming.birthdays.date_format"
      ) ?? fallback.dateFormat,
      showAge: try optionalBool(
        table["show_age"],
        path: "builtins.calendar.upcoming.birthdays.show_age"
      ) ?? fallback.showAge
    )
  }

  /// Parses the upcoming popup block.
  private func parseCalendarUpcomingPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let todayTable = table["today"]?.table ?? TOMLTable()
    let tomorrowTable = table["tomorrow"]?.table ?? TOMLTable()
    let futureTable = table["future"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.upcoming.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.upcoming.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.upcoming.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.upcoming.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.upcoming.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.upcoming.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.upcoming.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.upcoming.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.upcoming.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.upcoming.popup.margin_y"
      ) ?? fallback.marginY,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.upcoming.popup.show_calendar_name"
      ) ?? fallback.showCalendarName,
      useCalendarColors: try optionalBool(
        table["use_calendar_colors"],
        path: "builtins.calendar.upcoming.popup.use_calendar_colors"
      ) ?? fallback.useCalendarColors,
      birthdays: try parseCalendarUpcomingPopupSectionStyle(
        from: birthdaysTable,
        path: "builtins.calendar.upcoming.popup.birthdays",
        fallback: fallback.birthdays
      ),
      today: try parseCalendarUpcomingPopupSectionStyle(
        from: todayTable,
        path: "builtins.calendar.upcoming.popup.today",
        fallback: fallback.today
      ),
      tomorrow: try parseCalendarUpcomingPopupSectionStyle(
        from: tomorrowTable,
        path: "builtins.calendar.upcoming.popup.tomorrow",
        fallback: fallback.tomorrow
      ),
      future: try parseCalendarUpcomingPopupSectionStyle(
        from: futureTable,
        path: "builtins.calendar.upcoming.popup.future",
        fallback: fallback.future
      )
    )
  }

  /// Parses one upcoming popup section style block.
  private func parseCalendarUpcomingPopupSectionStyle(
    from table: TOMLTable,
    path: String,
    fallback: CalendarBuiltinConfig.Upcoming.PopupSectionStyle
  ) throws -> CalendarBuiltinConfig.Upcoming.PopupSectionStyle {
    CalendarBuiltinConfig.Upcoming.PopupSectionStyle(
      titleColorHex: try optionalString(
        table["title_color"],
        path: "\(path).title_color"
      ) ?? fallback.titleColorHex,
      itemColorHex: try optionalString(
        table["item_color"],
        path: "\(path).item_color"
      ) ?? fallback.itemColorHex,
      emptyColorHex: try optionalString(
        table["empty_color"],
        path: "\(path).empty_color"
      ) ?? fallback.emptyColorHex
    )
  }

  /// Parses the month calendar mode.
  private func parseCalendarMonth(
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month
  ) throws -> CalendarBuiltinConfig.Month {
    CalendarBuiltinConfig.Month(
      popup: try parseCalendarMonthPopup(
        from: popupTable,
        fallback: fallback.popup
      )
    )
  }

  /// Parses the month popup block.
  private func parseCalendarMonthPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup
  ) throws -> CalendarBuiltinConfig.Month.Popup {
    let parsedMinHeight =
      try optionalNumber(
        table["appointments_min_height"],
        path: "builtins.calendar.month.popup.appointments_min_height"
      ) ?? fallback.appointmentsMinHeight

    let parsedMaxHeight =
      try optionalNumber(
        table["appointments_max_height"],
        path: "builtins.calendar.month.popup.appointments_max_height"
      ) ?? fallback.appointmentsMaxHeight

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    let weekdayFormat = try validatedMonthWeekdayFormat(
      try optionalString(
        table["weekday_format"],
        path: "builtins.calendar.month.popup.weekday_format"
      ) ?? fallback.weekdayFormat,
      path: "builtins.calendar.month.popup.weekday_format"
    )

    let weekdaySymbols = try validatedMonthWeekdaySymbols(
      try optionalStringArray(
        table["weekday_symbols"],
        path: "builtins.calendar.month.popup.weekday_symbols"
      ) ?? fallback.weekdaySymbols,
      path: "builtins.calendar.month.popup.weekday_symbols"
    )

    let parsedFirstWeekday =
      try optionalInt(
        table["first_weekday"],
        path: "builtins.calendar.month.popup.first_weekday"
      ) ?? fallback.firstWeekday

    if let parsedFirstWeekday, !(1...7).contains(parsedFirstWeekday) {
      throw ConfigError.invalidValue(
        path: "builtins.calendar.month.popup.first_weekday",
        message: "expected integer from 1 to 7"
      )
    }

    let resolvedWeekdaySymbols = Self.resolveMonthWeekdaySymbols(
      format: weekdayFormat,
      manualSymbols: weekdaySymbols
    )

    return CalendarBuiltinConfig.Month.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.month.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.month.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.month.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.month.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.month.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.month.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.month.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.month.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.month.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.month.popup.margin_y"
      ) ?? fallback.marginY,
      showWeekNumbers: try optionalBool(
        table["show_week_numbers"],
        path: "builtins.calendar.month.popup.show_week_numbers"
      ) ?? fallback.showWeekNumbers,
      showEventIndicators: try optionalBool(
        table["show_event_indicators"],
        path: "builtins.calendar.month.popup.show_event_indicators"
      ) ?? fallback.showEventIndicators,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "builtins.calendar.month.popup.header_text_color"
      ) ?? fallback.headerTextColorHex,
      weekdayTextColorHex: try optionalString(
        table["weekday_text_color"],
        path: "builtins.calendar.month.popup.weekday_text_color"
      ) ?? fallback.weekdayTextColorHex,
      firstWeekday: parsedFirstWeekday,
      dayTextColorHex: try optionalString(
        table["day_text_color"],
        path: "builtins.calendar.month.popup.day_text_color"
      ) ?? fallback.dayTextColorHex,
      outsideMonthTextColorHex: try optionalString(
        table["outside_month_text_color"],
        path: "builtins.calendar.month.popup.outside_month_text_color"
      ) ?? fallback.outsideMonthTextColorHex,
      selectedTextColorHex: try optionalString(
        table["selected_text_color"],
        path: "builtins.calendar.month.popup.selected_text_color"
      ) ?? fallback.selectedTextColorHex,
      selectedBackgroundColorHex: try optionalString(
        table["selected_background_color"],
        path: "builtins.calendar.month.popup.selected_background_color"
      ) ?? fallback.selectedBackgroundColorHex,
      todayBackgroundColorHex: try optionalString(
        table["today_background_color"],
        path: "builtins.calendar.month.popup.today_background_color"
      ) ?? fallback.todayBackgroundColorHex,
      indicatorColorHex: try optionalString(
        table["indicator_color"],
        path: "builtins.calendar.month.popup.indicator_color"
      ) ?? fallback.indicatorColorHex,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "builtins.calendar.month.popup.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "builtins.calendar.month.popup.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "builtins.calendar.month.popup.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      layout: MonthCalendarPopupLayout(
        rawValue: try optionalString(
          table["layout"],
          path: "builtins.calendar.month.popup.layout"
        ) ?? fallback.layout.rawValue
      ) ?? fallback.layout,
      appointmentsScrollable: try optionalBool(
        table["appointments_scrollable"],
        path: "builtins.calendar.month.popup.appointments_scrollable"
      ) ?? fallback.appointmentsScrollable,
      appointmentsMinHeight: minHeight,
      appointmentsMaxHeight: maxHeight,
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.month.popup.empty_text"
      ) ?? fallback.emptyText,
      agendaTitle: try optionalString(
        table["agenda_title"],
        path: "builtins.calendar.month.popup.agenda_title"
      ) ?? fallback.agendaTitle,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.month.popup.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "builtins.calendar.month.popup.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      allowsRangeSelection: try optionalBool(
        table["allows_range_selection"],
        path: "builtins.calendar.month.popup.allows_range_selection"
      ) ?? fallback.allowsRangeSelection,
      resetSelectionOnThirdTap: try optionalBool(
        table["reset_selection_on_third_tap"],
        path: "builtins.calendar.month.popup.reset_selection_on_third_tap"
      ) ?? fallback.resetSelectionOnThirdTap,
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          table["max_visible_appointments"],
          path: "builtins.calendar.month.popup.max_visible_appointments"
        ) ?? fallback.maxVisibleAppointments
      ),
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "builtins.calendar.month.popup.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "builtins.calendar.month.popup.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames,
      anchorDateFormat: try optionalString(
        table["anchor_date_format"],
        path: "builtins.calendar.month.popup.anchor_date_format"
      ) ?? fallback.anchorDateFormat,
      anchorTextColorHex: try optionalString(
        table["anchor_text_color"],
        path: "builtins.calendar.month.popup.anchor_text_color"
      ) ?? fallback.anchorTextColorHex,
      anchorShowDateText: try optionalBool(
        table["anchor_show_date_text"],
        path: "builtins.calendar.month.popup.anchor_show_date_text"
      ) ?? fallback.anchorShowDateText,
      weekdayFormat: weekdayFormat,
      weekdaySymbols: weekdaySymbols,
      resolvedWeekdaySymbols: resolvedWeekdaySymbols,
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "builtins.calendar.month.popup.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "builtins.calendar.month.popup.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "builtins.calendar.month.popup.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "builtins.calendar.month.popup.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }

  /// Validates the configured localized weekday format.
  private func validatedMonthWeekdayFormat(
    _ value: String,
    path: String
  ) throws -> String {
    switch value {
    case "d", "dd", "ddd":
      return value
    case "dddd":
      throw ConfigError.invalidValue(
        path: path,
        message:
          "dddd is not allowed because full weekday names are too wide; use d, dd, ddd, or weekday_symbols"
      )
    default:
      throw ConfigError.invalidValue(
        path: path,
        message: "expected one of d, dd, or ddd"
      )
    }
  }

  /// Validates the optional manual weekday labels in Monday-to-Sunday order.
  private func validatedMonthWeekdaySymbols(
    _ value: [String]?,
    path: String
  ) throws -> [String]? {
    guard let value else { return nil }

    guard value.count == 7 else {
      throw ConfigError.invalidValue(
        path: path,
        message: "expected exactly 7 weekday symbols ordered Monday through Sunday"
      )
    }

    let trimmed = value.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    guard trimmed.allSatisfy({ !$0.isEmpty }) else {
      throw ConfigError.invalidValue(
        path: path,
        message: "weekday symbols must not be empty"
      )
    }

    return trimmed
  }

  /// Resolves final localized weekday labels in Monday-to-Sunday order.
  static func resolveMonthWeekdaySymbols(
    format: String,
    manualSymbols: [String]?
  ) -> [String] {
    if let manualSymbols {
      return manualSymbols
    }

    let formatter = DateFormatter()

    let sundayFirstSymbols: [String]
    switch format {
    case "d":
      sundayFirstSymbols =
        formatter.veryShortStandaloneWeekdaySymbols
        ?? formatter.veryShortWeekdaySymbols
        ?? ["S", "M", "T", "W", "T", "F", "S"]

    case "dd":
      let baseSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
      sundayFirstSymbols = baseSymbols.map { String($0.prefix(2)) }

    case "ddd":
      sundayFirstSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    default:
      sundayFirstSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }

    return normalizeSundayFirstWeekdaySymbolsToMondayFirst(sundayFirstSymbols)
  }

  /// Converts Sunday-first weekday symbols into Monday-first order.
  private static func normalizeSundayFirstWeekdaySymbolsToMondayFirst(_ symbols: [String])
    -> [String]
  {
    guard symbols.count == 7 else {
      return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    return Array(symbols[1...6]) + [symbols[0]]
  }
}
