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
        var selectionDateFormat: String
        var composerTitlePlaceholder: String
        var composerLocationPlaceholder: String
        var composerDefaultCalendarName: String?
        var composerDefaultAlert: String
        var composerDefaultTravelTime: String
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
          birthdayIconColorHex: nil,
          selectionDateFormat: "yyyy-MM-dd",
          composerTitlePlaceholder: "What are you doing?",
          composerLocationPlaceholder: "Where are you going?",
          composerDefaultCalendarName: nil,
          composerDefaultAlert: "1_hour",
          composerDefaultTravelTime: "none"
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
  func parseCalendarAnchor(
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
}
