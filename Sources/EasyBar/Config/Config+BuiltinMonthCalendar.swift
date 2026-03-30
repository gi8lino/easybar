import Foundation
import TOMLKit

extension Config {

  /// Popup layout variants for the native month-calendar widget.
  enum MonthCalendarPopupLayout: String {
    case calendarAppointmentsHorizontal = "calendar_appointments_horizontal"
    case appointmentsCalendarHorizontal = "appointments_calendar_horizontal"
    case calendarAppointmentsVertical = "calendar_appointments_vertical"
    case appointmentsCalendarVertical = "appointments_calendar_vertical"
  }

  /// Built-in month-calendar widget config.
  struct MonthCalendarBuiltinConfig {
    struct Content {
      var showDateText: Bool
      var dateFormat: String
      var textColorHex: String?
      var emptyText: String
      var agendaTitle: String
      var showCalendarName: Bool
      var showAllDayLabel: Bool
      var allowsRangeSelection: Bool
      var resetSelectionOnThirdTap: Bool
      var maxVisibleAppointments: Int
      var includedCalendarNames: [String]
      var excludedCalendarNames: [String]
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
      var showWeekNumbers: Bool
      var showEventIndicators: Bool
      var headerTextColorHex: String
      var weekdayTextColorHex: String
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
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var content: Content
    var popup: Popup

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

    var showDateText: Bool {
      get { content.showDateText }
      set { content.showDateText = newValue }
    }

    var dateFormat: String {
      get { content.dateFormat }
      set { content.dateFormat = newValue }
    }

    var textColorHex: String? {
      get { content.textColorHex }
      set { content.textColorHex = newValue }
    }

    var emptyText: String {
      get { content.emptyText }
      set { content.emptyText = newValue }
    }

    var agendaTitle: String {
      get { content.agendaTitle }
      set { content.agendaTitle = newValue }
    }

    var showCalendarName: Bool {
      get { content.showCalendarName }
      set { content.showCalendarName = newValue }
    }

    var showAllDayLabel: Bool {
      get { content.showAllDayLabel }
      set { content.showAllDayLabel = newValue }
    }

    var allowsRangeSelection: Bool {
      get { content.allowsRangeSelection }
      set { content.allowsRangeSelection = newValue }
    }

    var resetSelectionOnThirdTap: Bool {
      get { content.resetSelectionOnThirdTap }
      set { content.resetSelectionOnThirdTap = newValue }
    }

    var maxVisibleAppointments: Int {
      get { content.maxVisibleAppointments }
      set { content.maxVisibleAppointments = newValue }
    }

    var includedCalendarNames: [String] {
      get { content.includedCalendarNames }
      set { content.includedCalendarNames = newValue }
    }

    var excludedCalendarNames: [String] {
      get { content.excludedCalendarNames }
      set { content.excludedCalendarNames = newValue }
    }

    var popupBackgroundColorHex: String {
      get { popup.backgroundColorHex }
      set { popup.backgroundColorHex = newValue }
    }

    var popupBorderColorHex: String {
      get { popup.borderColorHex }
      set { popup.borderColorHex = newValue }
    }

    var popupBorderWidth: Double {
      get { popup.borderWidth }
      set { popup.borderWidth = newValue }
    }

    var popupCornerRadius: Double {
      get { popup.cornerRadius }
      set { popup.cornerRadius = newValue }
    }

    var popupPaddingX: Double {
      get { popup.paddingX }
      set { popup.paddingX = newValue }
    }

    var popupPaddingY: Double {
      get { popup.paddingY }
      set { popup.paddingY = newValue }
    }

    var popupSpacing: Double {
      get { popup.spacing }
      set { popup.spacing = newValue }
    }

    var popupItemIndent: Double {
      get { popup.itemIndent }
      set { popup.itemIndent = newValue }
    }

    var popupMarginX: Double {
      get { popup.marginX }
      set { popup.marginX = newValue }
    }

    var popupMarginY: Double {
      get { popup.marginY }
      set { popup.marginY = newValue }
    }

    var showWeekNumbers: Bool {
      get { popup.showWeekNumbers }
      set { popup.showWeekNumbers = newValue }
    }

    var showEventIndicators: Bool {
      get { popup.showEventIndicators }
      set { popup.showEventIndicators = newValue }
    }

    var popupHeaderTextColorHex: String {
      get { popup.headerTextColorHex }
      set { popup.headerTextColorHex = newValue }
    }

    var popupWeekdayTextColorHex: String {
      get { popup.weekdayTextColorHex }
      set { popup.weekdayTextColorHex = newValue }
    }

    var popupDayTextColorHex: String {
      get { popup.dayTextColorHex }
      set { popup.dayTextColorHex = newValue }
    }

    var popupOutsideMonthTextColorHex: String {
      get { popup.outsideMonthTextColorHex }
      set { popup.outsideMonthTextColorHex = newValue }
    }

    var popupSelectedTextColorHex: String {
      get { popup.selectedTextColorHex }
      set { popup.selectedTextColorHex = newValue }
    }

    var popupSelectedBackgroundColorHex: String {
      get { popup.selectedBackgroundColorHex }
      set { popup.selectedBackgroundColorHex = newValue }
    }

    var popupTodayBackgroundColorHex: String {
      get { popup.todayBackgroundColorHex }
      set { popup.todayBackgroundColorHex = newValue }
    }

    var popupIndicatorColorHex: String {
      get { popup.indicatorColorHex }
      set { popup.indicatorColorHex = newValue }
    }

    var popupEventTextColorHex: String {
      get { popup.eventTextColorHex }
      set { popup.eventTextColorHex = newValue }
    }

    var popupEmptyTextColorHex: String {
      get { popup.emptyTextColorHex }
      set { popup.emptyTextColorHex = newValue }
    }

    var popupSecondaryTextColorHex: String {
      get { popup.secondaryTextColorHex }
      set { popup.secondaryTextColorHex = newValue }
    }

    var popupLayout: MonthCalendarPopupLayout {
      get { popup.layout }
      set { popup.layout = newValue }
    }

    var popupAppointmentsScrollable: Bool {
      get { popup.appointmentsScrollable }
      set { popup.appointmentsScrollable = newValue }
    }

    static let `default` = MonthCalendarBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 70
      ),
      style: .init(
        icon: "📆",
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
      content: .init(
        showDateText: true,
        dateFormat: "EEE d MMM",
        textColorHex: "#ffffff",
        emptyText: "No appointments",
        agendaTitle: "Appointments",
        showCalendarName: true,
        showAllDayLabel: true,
        allowsRangeSelection: true,
        resetSelectionOnThirdTap: true,
        maxVisibleAppointments: 8,
        includedCalendarNames: [],
        excludedCalendarNames: []
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
        showWeekNumbers: true,
        showEventIndicators: true,
        headerTextColorHex: "#ffffff",
        weekdayTextColorHex: "#91d7e3",
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
        appointmentsScrollable: true
      )
    )
  }

  /// Parses the built-in month-calendar widget.
  func parseMonthCalendarBuiltin(from builtins: TOMLTable) throws {
    guard let monthCalendar = builtins["month_calendar"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: monthCalendar,
      path: "builtins.month_calendar",
      fallback: builtinMonthCalendar.placement
    )

    let styleTable = monthCalendar["style"]?.table ?? TOMLTable()
    let contentTable = monthCalendar["content"]?.table ?? TOMLTable()
    let popupTable = monthCalendar["popup"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.month_calendar.style",
      fallback: builtinMonthCalendar.style
    )

    let content = try parseMonthCalendarContent(
      from: contentTable,
      fallback: builtinMonthCalendar.content
    )

    let popup = try parseMonthCalendarPopup(
      from: popupTable,
      fallback: builtinMonthCalendar.popup
    )

    builtinMonthCalendar = MonthCalendarBuiltinConfig(
      placement: placement,
      style: style,
      content: content,
      popup: popup
    )
  }
}

extension Config {
  /// Parses the month-calendar content block.
  private func parseMonthCalendarContent(
    from table: TOMLTable,
    fallback: MonthCalendarBuiltinConfig.Content
  ) throws -> MonthCalendarBuiltinConfig.Content {
    MonthCalendarBuiltinConfig.Content(
      showDateText: try optionalBool(
        table["show_date_text"],
        path: "builtins.month_calendar.content.show_date_text"
      ) ?? fallback.showDateText,
      dateFormat: try optionalString(
        table["date_format"],
        path: "builtins.month_calendar.content.date_format"
      ) ?? fallback.dateFormat,
      textColorHex: try optionalString(
        table["text_color"],
        path: "builtins.month_calendar.content.text_color"
      ) ?? fallback.textColorHex,
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.month_calendar.content.empty_text"
      ) ?? fallback.emptyText,
      agendaTitle: try optionalString(
        table["agenda_title"],
        path: "builtins.month_calendar.content.agenda_title"
      ) ?? fallback.agendaTitle,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.month_calendar.content.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "builtins.month_calendar.content.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      allowsRangeSelection: try optionalBool(
        table["allows_range_selection"],
        path: "builtins.month_calendar.content.allows_range_selection"
      ) ?? fallback.allowsRangeSelection,
      resetSelectionOnThirdTap: try optionalBool(
        table["reset_selection_on_third_tap"],
        path: "builtins.month_calendar.content.reset_selection_on_third_tap"
      ) ?? fallback.resetSelectionOnThirdTap,
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          table["max_visible_appointments"],
          path: "builtins.month_calendar.content.max_visible_appointments"
        ) ?? fallback.maxVisibleAppointments
      ),
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "builtins.month_calendar.content.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "builtins.month_calendar.content.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames
    )
  }

  /// Parses the month-calendar popup block.
  private func parseMonthCalendarPopup(
    from table: TOMLTable,
    fallback: MonthCalendarBuiltinConfig.Popup
  ) throws -> MonthCalendarBuiltinConfig.Popup {
    MonthCalendarBuiltinConfig.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.month_calendar.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.month_calendar.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.month_calendar.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.month_calendar.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.month_calendar.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.month_calendar.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.month_calendar.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.month_calendar.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.month_calendar.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.month_calendar.popup.margin_y"
      ) ?? fallback.marginY,
      showWeekNumbers: try optionalBool(
        table["show_week_numbers"],
        path: "builtins.month_calendar.popup.show_week_numbers"
      ) ?? fallback.showWeekNumbers,
      showEventIndicators: try optionalBool(
        table["show_event_indicators"],
        path: "builtins.month_calendar.popup.show_event_indicators"
      ) ?? fallback.showEventIndicators,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "builtins.month_calendar.popup.header_text_color"
      ) ?? fallback.headerTextColorHex,
      weekdayTextColorHex: try optionalString(
        table["weekday_text_color"],
        path: "builtins.month_calendar.popup.weekday_text_color"
      ) ?? fallback.weekdayTextColorHex,
      dayTextColorHex: try optionalString(
        table["day_text_color"],
        path: "builtins.month_calendar.popup.day_text_color"
      ) ?? fallback.dayTextColorHex,
      outsideMonthTextColorHex: try optionalString(
        table["outside_month_text_color"],
        path: "builtins.month_calendar.popup.outside_month_text_color"
      ) ?? fallback.outsideMonthTextColorHex,
      selectedTextColorHex: try optionalString(
        table["selected_text_color"],
        path: "builtins.month_calendar.popup.selected_text_color"
      ) ?? fallback.selectedTextColorHex,
      selectedBackgroundColorHex: try optionalString(
        table["selected_background_color"],
        path: "builtins.month_calendar.popup.selected_background_color"
      ) ?? fallback.selectedBackgroundColorHex,
      todayBackgroundColorHex: try optionalString(
        table["today_background_color"],
        path: "builtins.month_calendar.popup.today_background_color"
      ) ?? fallback.todayBackgroundColorHex,
      indicatorColorHex: try optionalString(
        table["indicator_color"],
        path: "builtins.month_calendar.popup.indicator_color"
      ) ?? fallback.indicatorColorHex,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "builtins.month_calendar.popup.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "builtins.month_calendar.popup.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "builtins.month_calendar.popup.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      layout: MonthCalendarPopupLayout(
        rawValue: try optionalString(
          table["layout"],
          path: "builtins.month_calendar.popup.layout"
        ) ?? fallback.layout.rawValue
      ) ?? fallback.layout,
      appointmentsScrollable: try optionalBool(
        table["appointments_scrollable"],
        path: "builtins.month_calendar.popup.appointments_scrollable"
      ) ?? fallback.appointmentsScrollable
    )
  }
}
