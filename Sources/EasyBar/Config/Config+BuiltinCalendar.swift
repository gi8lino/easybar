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
        struct Style {
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
        }

        struct CalendarStyle {
          var showWeekNumbers: Bool
          var showEventIndicators: Bool
          var headerTextColorHex: String
          var weekdayTextColorHex: String
          var firstWeekday: Int?
          var weekdayFormat: String
          var weekdaySymbols: [String]?
          var resolvedWeekdaySymbols: [String]
          var dayTextColorHex: String
          var outsideMonthTextColorHex: String
          var todayBackgroundColorHex: String
          var todayBorderColorHex: String
          var todayBorderWidth: Double
          var indicatorColorHex: String
        }

        struct SelectionStyle {
          var selectedTextColorHex: String
          var selectedBackgroundColorHex: String
          var selectionDateFormat: String
          var selectionDateSeparator: String
          var allowsRangeSelection: Bool
          var resetSelectionOnThirdTap: Bool
        }

        struct AgendaStyle {
          var eventTextColorHex: String
          var emptyTextColorHex: String
          var secondaryTextColorHex: String
          var travelTextColorHex: String
          var layout: MonthCalendarPopupLayout
          var appointmentsScrollable: Bool
          var appointmentsMinHeight: Double
          var appointmentsMaxHeight: Double
          var emptyText: String
          var agendaTitle: String
          var showCalendarName: Bool
          var showAllDayLabel: Bool
          var showHolidayAllDayLabel: Bool
          var allDayLabel: String
          var showLocation: Bool
          var showTravelTime: Bool
          var travelIcon: String
          var travelIconColorHex: String?
          var showAlertIcon: Bool
          var alertIcon: String
          var alertIconColorHex: String?
          var maxVisibleAppointments: Int
        }

        struct BirthdaysStyle {
          var showBirthdays: Bool
          var birthdaysShowAge: Bool
          var birthdayIcon: String
          var birthdayIconColorHex: String?
        }

        struct Filters {
          var includedCalendarNames: [String]
          var excludedCalendarNames: [String]
        }

        struct AnchorStyle {
          var dateFormat: String
          var textColorHex: String?
          var showDateText: Bool
        }

        struct ComposerStyle {
          var createTitle: String
          var editTitle: String
          var titleLabel: String
          var locationLabel: String
          var calendarLabel: String
          var titlePlaceholder: String
          var locationPlaceholder: String
          var defaultCalendarName: String?
          var defaultAlert: String
          var defaultTravelTime: String
          var startLabel: String
          var endLabel: String
          var allDayLabel: String
          var travelTimeLabel: String
          var alertLabel: String
          var addAlertLabel: String
          var openCalendarLabel: String
          var cancelLabel: String
          var saveLabel: String
          var updateLabel: String
          var removeLabel: String
          var deleteConfirmationTitle: String
          var deleteConfirmationMessage: String
        }

        struct TodayButtonStyle {
          var title: String
          var borderColorHex: String
          var borderWidth: Double
        }

        var style: Style
        var calendar: CalendarStyle
        var selection: SelectionStyle
        var agenda: AgendaStyle
        var birthdays: BirthdaysStyle
        var filters: Filters
        var anchor: AnchorStyle
        var composer: ComposerStyle
        var todayButton: TodayButtonStyle

        var backgroundColorHex: String {
          get { style.backgroundColorHex }
          set { style.backgroundColorHex = newValue }
        }

        var borderColorHex: String {
          get { style.borderColorHex }
          set { style.borderColorHex = newValue }
        }

        var borderWidth: Double {
          get { style.borderWidth }
          set { style.borderWidth = newValue }
        }

        var cornerRadius: Double {
          get { style.cornerRadius }
          set { style.cornerRadius = newValue }
        }

        var paddingX: Double {
          get { style.paddingX }
          set { style.paddingX = newValue }
        }

        var paddingY: Double {
          get { style.paddingY }
          set { style.paddingY = newValue }
        }

        var spacing: Double {
          get { style.spacing }
          set { style.spacing = newValue }
        }

        var itemIndent: Double {
          get { style.itemIndent }
          set { style.itemIndent = newValue }
        }

        var marginX: Double {
          get { style.marginX }
          set { style.marginX = newValue }
        }

        var marginY: Double {
          get { style.marginY }
          set { style.marginY = newValue }
        }

        var showWeekNumbers: Bool {
          get { calendar.showWeekNumbers }
          set { calendar.showWeekNumbers = newValue }
        }

        var showEventIndicators: Bool {
          get { calendar.showEventIndicators }
          set { calendar.showEventIndicators = newValue }
        }

        var headerTextColorHex: String {
          get { calendar.headerTextColorHex }
          set { calendar.headerTextColorHex = newValue }
        }

        var weekdayTextColorHex: String {
          get { calendar.weekdayTextColorHex }
          set { calendar.weekdayTextColorHex = newValue }
        }

        var firstWeekday: Int? {
          get { calendar.firstWeekday }
          set { calendar.firstWeekday = newValue }
        }

        var weekdayFormat: String {
          get { calendar.weekdayFormat }
          set { calendar.weekdayFormat = newValue }
        }

        var weekdaySymbols: [String]? {
          get { calendar.weekdaySymbols }
          set { calendar.weekdaySymbols = newValue }
        }

        var resolvedWeekdaySymbols: [String] {
          get { calendar.resolvedWeekdaySymbols }
          set { calendar.resolvedWeekdaySymbols = newValue }
        }

        var dayTextColorHex: String {
          get { calendar.dayTextColorHex }
          set { calendar.dayTextColorHex = newValue }
        }

        var outsideMonthTextColorHex: String {
          get { calendar.outsideMonthTextColorHex }
          set { calendar.outsideMonthTextColorHex = newValue }
        }

        var todayBackgroundColorHex: String {
          get { calendar.todayBackgroundColorHex }
          set { calendar.todayBackgroundColorHex = newValue }
        }

        var todayBorderColorHex: String {
          get { calendar.todayBorderColorHex }
          set { calendar.todayBorderColorHex = newValue }
        }

        var todayBorderWidth: Double {
          get { calendar.todayBorderWidth }
          set { calendar.todayBorderWidth = newValue }
        }

        var indicatorColorHex: String {
          get { calendar.indicatorColorHex }
          set { calendar.indicatorColorHex = newValue }
        }

        var selectedTextColorHex: String {
          get { selection.selectedTextColorHex }
          set { selection.selectedTextColorHex = newValue }
        }

        var selectedBackgroundColorHex: String {
          get { selection.selectedBackgroundColorHex }
          set { selection.selectedBackgroundColorHex = newValue }
        }

        var selectionDateFormat: String {
          get { selection.selectionDateFormat }
          set { selection.selectionDateFormat = newValue }
        }

        var selectionDateSeparator: String {
          get { selection.selectionDateSeparator }
          set { selection.selectionDateSeparator = newValue }
        }

        var allowsRangeSelection: Bool {
          get { selection.allowsRangeSelection }
          set { selection.allowsRangeSelection = newValue }
        }

        var resetSelectionOnThirdTap: Bool {
          get { selection.resetSelectionOnThirdTap }
          set { selection.resetSelectionOnThirdTap = newValue }
        }

        var eventTextColorHex: String {
          get { agenda.eventTextColorHex }
          set { agenda.eventTextColorHex = newValue }
        }

        var emptyTextColorHex: String {
          get { agenda.emptyTextColorHex }
          set { agenda.emptyTextColorHex = newValue }
        }

        var secondaryTextColorHex: String {
          get { agenda.secondaryTextColorHex }
          set { agenda.secondaryTextColorHex = newValue }
        }

        var layout: MonthCalendarPopupLayout {
          get { agenda.layout }
          set { agenda.layout = newValue }
        }

        var travelTextColorHex: String {
          get { agenda.travelTextColorHex }
          set { agenda.travelTextColorHex = newValue }
        }

        var appointmentsScrollable: Bool {
          get { agenda.appointmentsScrollable }
          set { agenda.appointmentsScrollable = newValue }
        }

        var appointmentsMinHeight: Double {
          get { agenda.appointmentsMinHeight }
          set { agenda.appointmentsMinHeight = newValue }
        }

        var appointmentsMaxHeight: Double {
          get { agenda.appointmentsMaxHeight }
          set { agenda.appointmentsMaxHeight = newValue }
        }

        var emptyText: String {
          get { agenda.emptyText }
          set { agenda.emptyText = newValue }
        }

        var agendaTitle: String {
          get { agenda.agendaTitle }
          set { agenda.agendaTitle = newValue }
        }

        var showCalendarName: Bool {
          get { agenda.showCalendarName }
          set { agenda.showCalendarName = newValue }
        }

        var showAllDayLabel: Bool {
          get { agenda.showAllDayLabel }
          set { agenda.showAllDayLabel = newValue }
        }

        var showHolidayAllDayLabel: Bool {
          get { agenda.showHolidayAllDayLabel }
          set { agenda.showHolidayAllDayLabel = newValue }
        }

        var allDayLabel: String {
          get { agenda.allDayLabel }
          set { agenda.allDayLabel = newValue }
        }

        var showLocation: Bool {
          get { agenda.showLocation }
          set { agenda.showLocation = newValue }
        }

        var showTravelTime: Bool {
          get { agenda.showTravelTime }
          set { agenda.showTravelTime = newValue }
        }

        var travelIcon: String {
          get { agenda.travelIcon }
          set { agenda.travelIcon = newValue }
        }

        var travelIconColorHex: String? {
          get { agenda.travelIconColorHex }
          set { agenda.travelIconColorHex = newValue }
        }

        var showAlertIcon: Bool {
          get { agenda.showAlertIcon }
          set { agenda.showAlertIcon = newValue }
        }

        var alertIcon: String {
          get { agenda.alertIcon }
          set { agenda.alertIcon = newValue }
        }

        var alertIconColorHex: String? {
          get { agenda.alertIconColorHex }
          set { agenda.alertIconColorHex = newValue }
        }

        var maxVisibleAppointments: Int {
          get { agenda.maxVisibleAppointments }
          set { agenda.maxVisibleAppointments = newValue }
        }

        var showBirthdays: Bool {
          get { birthdays.showBirthdays }
          set { birthdays.showBirthdays = newValue }
        }

        var birthdaysShowAge: Bool {
          get { birthdays.birthdaysShowAge }
          set { birthdays.birthdaysShowAge = newValue }
        }

        var birthdayIcon: String {
          get { birthdays.birthdayIcon }
          set { birthdays.birthdayIcon = newValue }
        }

        var birthdayIconColorHex: String? {
          get { birthdays.birthdayIconColorHex }
          set { birthdays.birthdayIconColorHex = newValue }
        }

        var includedCalendarNames: [String] {
          get { filters.includedCalendarNames }
          set { filters.includedCalendarNames = newValue }
        }

        var excludedCalendarNames: [String] {
          get { filters.excludedCalendarNames }
          set { filters.excludedCalendarNames = newValue }
        }

        var anchorDateFormat: String {
          get { anchor.dateFormat }
          set { anchor.dateFormat = newValue }
        }

        var anchorTextColorHex: String? {
          get { anchor.textColorHex }
          set { anchor.textColorHex = newValue }
        }

        var anchorShowDateText: Bool {
          get { anchor.showDateText }
          set { anchor.showDateText = newValue }
        }

        var composerTitlePlaceholder: String {
          get { composer.titlePlaceholder }
          set { composer.titlePlaceholder = newValue }
        }

        var composerCreateTitle: String {
          get { composer.createTitle }
          set { composer.createTitle = newValue }
        }

        var composerEditTitle: String {
          get { composer.editTitle }
          set { composer.editTitle = newValue }
        }

        var composerTitleLabel: String {
          get { composer.titleLabel }
          set { composer.titleLabel = newValue }
        }

        var composerLocationLabel: String {
          get { composer.locationLabel }
          set { composer.locationLabel = newValue }
        }

        var composerCalendarLabel: String {
          get { composer.calendarLabel }
          set { composer.calendarLabel = newValue }
        }

        var composerLocationPlaceholder: String {
          get { composer.locationPlaceholder }
          set { composer.locationPlaceholder = newValue }
        }

        var composerDefaultCalendarName: String? {
          get { composer.defaultCalendarName }
          set { composer.defaultCalendarName = newValue }
        }

        var composerDefaultAlert: String {
          get { composer.defaultAlert }
          set { composer.defaultAlert = newValue }
        }

        var composerDefaultTravelTime: String {
          get { composer.defaultTravelTime }
          set { composer.defaultTravelTime = newValue }
        }

        var composerStartLabel: String {
          get { composer.startLabel }
          set { composer.startLabel = newValue }
        }

        var composerEndLabel: String {
          get { composer.endLabel }
          set { composer.endLabel = newValue }
        }

        var composerAllDayLabel: String {
          get { composer.allDayLabel }
          set { composer.allDayLabel = newValue }
        }

        var composerTravelTimeLabel: String {
          get { composer.travelTimeLabel }
          set { composer.travelTimeLabel = newValue }
        }

        var composerAlertLabel: String {
          get { composer.alertLabel }
          set { composer.alertLabel = newValue }
        }

        var composerAddAlertLabel: String {
          get { composer.addAlertLabel }
          set { composer.addAlertLabel = newValue }
        }

        var composerOpenCalendarLabel: String {
          get { composer.openCalendarLabel }
          set { composer.openCalendarLabel = newValue }
        }

        var composerCancelLabel: String {
          get { composer.cancelLabel }
          set { composer.cancelLabel = newValue }
        }

        var composerSaveLabel: String {
          get { composer.saveLabel }
          set { composer.saveLabel = newValue }
        }

        var composerUpdateLabel: String {
          get { composer.updateLabel }
          set { composer.updateLabel = newValue }
        }

        var composerRemoveLabel: String {
          get { composer.removeLabel }
          set { composer.removeLabel = newValue }
        }

        var composerDeleteConfirmationTitle: String {
          get { composer.deleteConfirmationTitle }
          set { composer.deleteConfirmationTitle = newValue }
        }

        var composerDeleteConfirmationMessage: String {
          get { composer.deleteConfirmationMessage }
          set { composer.deleteConfirmationMessage = newValue }
        }

        var todayButtonTitle: String {
          get { todayButton.title }
          set { todayButton.title = newValue }
        }

        var todayButtonBorderColorHex: String {
          get { todayButton.borderColorHex }
          set { todayButton.borderColorHex = newValue }
        }

        var todayButtonBorderWidth: Double {
          get { todayButton.borderWidth }
          set { todayButton.borderWidth = newValue }
        }
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
            todayBackgroundColorHex: "#3F2F6B",
            todayBorderColorHex: "#3F2F6B",
            todayBorderWidth: 3.0,
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
            layout: .calendarAppointmentsVertical,
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
