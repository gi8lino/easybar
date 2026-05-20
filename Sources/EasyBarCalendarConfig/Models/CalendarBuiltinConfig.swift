import EasyBarShared
import Foundation

public enum CalendarPopupMode: String, CaseIterable {
  case none
  case upcoming
  case month
}

public enum MonthCalendarPopupLayout: String, CaseIterable {
  case calendarAppointmentsHorizontal = "calendar_appointments_horizontal"
  case appointmentsCalendarHorizontal = "appointments_calendar_horizontal"
  case calendarAppointmentsVertical = "calendar_appointments_vertical"
  case appointmentsCalendarVertical = "appointments_calendar_vertical"
}

public enum CalendarAnchorLayout: String, Codable {
  case item
  case stack
  case inline
}

public struct CalendarWidgetPlacement {
  public var enabled: Bool
  public var position: WidgetPosition
  public var order: Int
  public var group: String?

  public init(
    enabled: Bool,
    position: WidgetPosition,
    order: Int,
    group: String? = nil
  ) {
    self.enabled = enabled
    self.position = position
    self.order = order
    self.group = group
  }

  public var groupID: String? {
    guard let group else { return nil }

    let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    return trimmed
  }
}

public struct CalendarWidgetStyle {
  public var icon: String
  public var textColorHex: String?
  public var backgroundColorHex: String?
  public var borderColorHex: String?
  public var borderWidth: Double
  public var cornerRadius: Double
  public var marginX: Double
  public var marginY: Double
  public var paddingX: Double
  public var paddingY: Double
  public var spacing: Double
  public var opacity: Double

  public init(
    icon: String,
    textColorHex: String?,
    backgroundColorHex: String?,
    borderColorHex: String?,
    borderWidth: Double,
    cornerRadius: Double,
    marginX: Double,
    marginY: Double,
    paddingX: Double,
    paddingY: Double,
    spacing: Double,
    opacity: Double
  ) {
    self.icon = icon
    self.textColorHex = textColorHex
    self.backgroundColorHex = backgroundColorHex
    self.borderColorHex = borderColorHex
    self.borderWidth = borderWidth
    self.cornerRadius = cornerRadius
    self.marginX = marginX
    self.marginY = marginY
    self.paddingX = paddingX
    self.paddingY = paddingY
    self.spacing = spacing
    self.opacity = opacity
  }
}

public struct CalendarBuiltinConfig {
  public struct Filters {
    public var includedCalendarNames: [String]
    public var excludedCalendarNames: [String]

    public init(includedCalendarNames: [String], excludedCalendarNames: [String]) {
      self.includedCalendarNames = includedCalendarNames
      self.excludedCalendarNames = excludedCalendarNames
    }
  }

  public struct Appointments {
    public var itemIndent: Double
    public var eventTextColorHex: String
    public var emptyTextColorHex: String
    public var secondaryTextColorHex: String
    public var travelTextColorHex: String
    public var emptyText: String
    public var showCalendarName: Bool
    public var showAllDayLabel: Bool
    public var showHolidayAllDayLabel: Bool
    public var allDayLabel: String
    public var showLocation: Bool
    public var showTravelTime: Bool
    public var showEndTime: Bool
    public var travelIcon: String
    public var travelIconColorHex: String?
    public var showAlertIcon: Bool
    public var alertIcon: String
    public var alertIconColorHex: String?

    public init(
      itemIndent: Double,
      eventTextColorHex: String,
      emptyTextColorHex: String,
      secondaryTextColorHex: String,
      travelTextColorHex: String,
      emptyText: String,
      showCalendarName: Bool,
      showAllDayLabel: Bool,
      showHolidayAllDayLabel: Bool,
      allDayLabel: String,
      showLocation: Bool,
      showTravelTime: Bool,
      showEndTime: Bool,
      travelIcon: String,
      travelIconColorHex: String?,
      showAlertIcon: Bool,
      alertIcon: String,
      alertIconColorHex: String?
    ) {
      self.itemIndent = itemIndent
      self.eventTextColorHex = eventTextColorHex
      self.emptyTextColorHex = emptyTextColorHex
      self.secondaryTextColorHex = secondaryTextColorHex
      self.travelTextColorHex = travelTextColorHex
      self.emptyText = emptyText
      self.showCalendarName = showCalendarName
      self.showAllDayLabel = showAllDayLabel
      self.showHolidayAllDayLabel = showHolidayAllDayLabel
      self.allDayLabel = allDayLabel
      self.showLocation = showLocation
      self.showTravelTime = showTravelTime
      self.showEndTime = showEndTime
      self.travelIcon = travelIcon
      self.travelIconColorHex = travelIconColorHex
      self.showAlertIcon = showAlertIcon
      self.alertIcon = alertIcon
      self.alertIconColorHex = alertIconColorHex
    }
  }

  public struct Birthdays {
    public var showBirthdays: Bool
    public var birthdaysShowAge: Bool
    public var birthdayIcon: String
    public var birthdayIconColorHex: String?

    public init(
      showBirthdays: Bool,
      birthdaysShowAge: Bool,
      birthdayIcon: String,
      birthdayIconColorHex: String?
    ) {
      self.showBirthdays = showBirthdays
      self.birthdaysShowAge = birthdaysShowAge
      self.birthdayIcon = birthdayIcon
      self.birthdayIconColorHex = birthdayIconColorHex
    }
  }

  public struct Anchor {
    public var itemFormat: String
    public var layout: CalendarAnchorLayout
    public var topFormat: String
    public var bottomFormat: String
    public var lineSpacing: Double
    public var topTextColorHex: String?
    public var bottomTextColorHex: String?

    public init(
      itemFormat: String,
      layout: CalendarAnchorLayout,
      topFormat: String,
      bottomFormat: String,
      lineSpacing: Double,
      topTextColorHex: String?,
      bottomTextColorHex: String?
    ) {
      self.itemFormat = itemFormat
      self.layout = layout
      self.topFormat = topFormat
      self.bottomFormat = bottomFormat
      self.lineSpacing = lineSpacing
      self.topTextColorHex = topTextColorHex
      self.bottomTextColorHex = bottomTextColorHex
    }
  }

  public struct Composer {
    public struct Style {
      public var backgroundColorHex: String
      public var borderColorHex: String
      public var borderWidth: Double
      public var cornerRadius: Double
      public var paddingX: Double
      public var paddingY: Double
      public var headerTextColorHex: String

      public init(
        backgroundColorHex: String,
        borderColorHex: String,
        borderWidth: Double,
        cornerRadius: Double,
        paddingX: Double,
        paddingY: Double,
        headerTextColorHex: String
      ) {
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.headerTextColorHex = headerTextColorHex
      }
    }

    public struct Content {
      public var createTitle: String
      public var editTitle: String
      public var titleLabel: String
      public var locationLabel: String
      public var calendarLabel: String
      public var titlePlaceholder: String
      public var locationPlaceholder: String
      public var defaultCalendarName: String?
      public var defaultAlert: String
      public var defaultTravelTime: String
      public var alertLabels: [String: String]
      public var travelTimeLabels: [String: String]
      public var startLabel: String
      public var endLabel: String
      public var allDayLabel: String
      public var travelTimeLabel: String
      public var alertLabel: String
      public var addAlertLabel: String
      public var openCalendarLabel: String
      public var cancelLabel: String
      public var saveLabel: String
      public var updateLabel: String
      public var removeLabel: String
      public var deleteConfirmationTitle: String
      public var deleteConfirmationMessage: String

      public init(
        createTitle: String,
        editTitle: String,
        titleLabel: String,
        locationLabel: String,
        calendarLabel: String,
        titlePlaceholder: String,
        locationPlaceholder: String,
        defaultCalendarName: String?,
        defaultAlert: String,
        defaultTravelTime: String,
        alertLabels: [String: String],
        travelTimeLabels: [String: String],
        startLabel: String,
        endLabel: String,
        allDayLabel: String,
        travelTimeLabel: String,
        alertLabel: String,
        addAlertLabel: String,
        openCalendarLabel: String,
        cancelLabel: String,
        saveLabel: String,
        updateLabel: String,
        removeLabel: String,
        deleteConfirmationTitle: String,
        deleteConfirmationMessage: String
      ) {
        self.createTitle = createTitle
        self.editTitle = editTitle
        self.titleLabel = titleLabel
        self.locationLabel = locationLabel
        self.calendarLabel = calendarLabel
        self.titlePlaceholder = titlePlaceholder
        self.locationPlaceholder = locationPlaceholder
        self.defaultCalendarName = defaultCalendarName
        self.defaultAlert = defaultAlert
        self.defaultTravelTime = defaultTravelTime
        self.alertLabels = alertLabels
        self.travelTimeLabels = travelTimeLabels
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.allDayLabel = allDayLabel
        self.travelTimeLabel = travelTimeLabel
        self.alertLabel = alertLabel
        self.addAlertLabel = addAlertLabel
        self.openCalendarLabel = openCalendarLabel
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.updateLabel = updateLabel
        self.removeLabel = removeLabel
        self.deleteConfirmationTitle = deleteConfirmationTitle
        self.deleteConfirmationMessage = deleteConfirmationMessage
      }
    }

    public var style: Style
    public var content: Content

    public init(style: Style, content: Content) {
      self.style = style
      self.content = content
    }

    public var backgroundColorHex: String {
      get { style.backgroundColorHex }
      set { style.backgroundColorHex = newValue }
    }

    public var borderColorHex: String {
      get { style.borderColorHex }
      set { style.borderColorHex = newValue }
    }

    public var borderWidth: Double {
      get { style.borderWidth }
      set { style.borderWidth = newValue }
    }

    public var cornerRadius: Double {
      get { style.cornerRadius }
      set { style.cornerRadius = newValue }
    }

    public var paddingX: Double {
      get { style.paddingX }
      set { style.paddingX = newValue }
    }

    public var paddingY: Double {
      get { style.paddingY }
      set { style.paddingY = newValue }
    }

    public var headerTextColorHex: String {
      get { style.headerTextColorHex }
      set { style.headerTextColorHex = newValue }
    }

    public var createTitle: String {
      get { content.createTitle }
      set { content.createTitle = newValue }
    }

    public var editTitle: String {
      get { content.editTitle }
      set { content.editTitle = newValue }
    }

    public var titleLabel: String {
      get { content.titleLabel }
      set { content.titleLabel = newValue }
    }

    public var locationLabel: String {
      get { content.locationLabel }
      set { content.locationLabel = newValue }
    }

    public var calendarLabel: String {
      get { content.calendarLabel }
      set { content.calendarLabel = newValue }
    }

    public var titlePlaceholder: String {
      get { content.titlePlaceholder }
      set { content.titlePlaceholder = newValue }
    }

    public var locationPlaceholder: String {
      get { content.locationPlaceholder }
      set { content.locationPlaceholder = newValue }
    }

    public var defaultCalendarName: String? {
      get { content.defaultCalendarName }
      set { content.defaultCalendarName = newValue }
    }

    public var defaultAlert: String {
      get { content.defaultAlert }
      set { content.defaultAlert = newValue }
    }

    public var defaultTravelTime: String {
      get { content.defaultTravelTime }
      set { content.defaultTravelTime = newValue }
    }

    public var alertLabels: [String: String] {
      get { content.alertLabels }
      set { content.alertLabels = newValue }
    }

    public var travelTimeLabels: [String: String] {
      get { content.travelTimeLabels }
      set { content.travelTimeLabels = newValue }
    }

    public var startLabel: String {
      get { content.startLabel }
      set { content.startLabel = newValue }
    }

    public var endLabel: String {
      get { content.endLabel }
      set { content.endLabel = newValue }
    }

    public var allDayLabel: String {
      get { content.allDayLabel }
      set { content.allDayLabel = newValue }
    }

    public var travelTimeLabel: String {
      get { content.travelTimeLabel }
      set { content.travelTimeLabel = newValue }
    }

    public var alertLabel: String {
      get { content.alertLabel }
      set { content.alertLabel = newValue }
    }

    public var addAlertLabel: String {
      get { content.addAlertLabel }
      set { content.addAlertLabel = newValue }
    }

    public var openCalendarLabel: String {
      get { content.openCalendarLabel }
      set { content.openCalendarLabel = newValue }
    }

    public var cancelLabel: String {
      get { content.cancelLabel }
      set { content.cancelLabel = newValue }
    }

    public var saveLabel: String {
      get { content.saveLabel }
      set { content.saveLabel = newValue }
    }

    public var updateLabel: String {
      get { content.updateLabel }
      set { content.updateLabel = newValue }
    }

    public var removeLabel: String {
      get { content.removeLabel }
      set { content.removeLabel = newValue }
    }

    public var deleteConfirmationTitle: String {
      get { content.deleteConfirmationTitle }
      set { content.deleteConfirmationTitle = newValue }
    }

    public var deleteConfirmationMessage: String {
      get { content.deleteConfirmationMessage }
      set { content.deleteConfirmationMessage = newValue }
    }
  }

  public struct Upcoming {
    public struct Events {
      public var days: Int
      public var excludePastEvents: Bool

      public init(days: Int, excludePastEvents: Bool) {
        self.days = days
        self.excludePastEvents = excludePastEvents
      }
    }

    public struct Popup {
      public var backgroundColorHex: String
      public var borderColorHex: String
      public var borderWidth: Double
      public var cornerRadius: Double
      public var paddingX: Double
      public var paddingY: Double
      public var spacing: Double
      public var marginX: Double
      public var marginY: Double

      public init(
        backgroundColorHex: String,
        borderColorHex: String,
        borderWidth: Double,
        cornerRadius: Double,
        paddingX: Double,
        paddingY: Double,
        spacing: Double,
        marginX: Double,
        marginY: Double
      ) {
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.spacing = spacing
        self.marginX = marginX
        self.marginY = marginY
      }
    }

    public var events: Events
    public var popup: Popup

    public init(events: Events, popup: Popup) {
      self.events = events
      self.popup = popup
    }
  }

  public struct Month {
    public struct Popup {
      public struct Style {
        public var backgroundColorHex: String
        public var borderColorHex: String
        public var borderWidth: Double
        public var cornerRadius: Double
        public var paddingX: Double
        public var paddingY: Double
        public var spacing: Double
        public var marginX: Double
        public var marginY: Double

        public init(
          backgroundColorHex: String,
          borderColorHex: String,
          borderWidth: Double,
          cornerRadius: Double,
          paddingX: Double,
          paddingY: Double,
          spacing: Double,
          marginX: Double,
          marginY: Double
        ) {
          self.backgroundColorHex = backgroundColorHex
          self.borderColorHex = borderColorHex
          self.borderWidth = borderWidth
          self.cornerRadius = cornerRadius
          self.paddingX = paddingX
          self.paddingY = paddingY
          self.spacing = spacing
          self.marginX = marginX
          self.marginY = marginY
        }
      }

      public struct CalendarStyle {
        public var showWeekNumbers: Bool
        public var showEventIndicators: Bool
        public var headerTextColorHex: String
        public var weekdayTextColorHex: String
        public var firstWeekday: Int?
        public var weekdayFormat: String
        public var weekdaySymbols: [String]?
        public var resolvedWeekdaySymbols: [String]
        public var dayTextColorHex: String
        public var outsideMonthTextColorHex: String
        public var todayCellBackgroundColorHex: String
        public var todayCellBorderColorHex: String
        public var todayCellBorderWidth: Double
        public var indicatorColorHex: String

        public init(
          showWeekNumbers: Bool,
          showEventIndicators: Bool,
          headerTextColorHex: String,
          weekdayTextColorHex: String,
          firstWeekday: Int?,
          weekdayFormat: String,
          weekdaySymbols: [String]?,
          resolvedWeekdaySymbols: [String],
          dayTextColorHex: String,
          outsideMonthTextColorHex: String,
          todayCellBackgroundColorHex: String,
          todayCellBorderColorHex: String,
          todayCellBorderWidth: Double,
          indicatorColorHex: String
        ) {
          self.showWeekNumbers = showWeekNumbers
          self.showEventIndicators = showEventIndicators
          self.headerTextColorHex = headerTextColorHex
          self.weekdayTextColorHex = weekdayTextColorHex
          self.firstWeekday = firstWeekday
          self.weekdayFormat = weekdayFormat
          self.weekdaySymbols = weekdaySymbols
          self.resolvedWeekdaySymbols = resolvedWeekdaySymbols
          self.dayTextColorHex = dayTextColorHex
          self.outsideMonthTextColorHex = outsideMonthTextColorHex
          self.todayCellBackgroundColorHex = todayCellBackgroundColorHex
          self.todayCellBorderColorHex = todayCellBorderColorHex
          self.todayCellBorderWidth = todayCellBorderWidth
          self.indicatorColorHex = indicatorColorHex
        }
      }

      public struct SelectionStyle {
        public var selectedTextColorHex: String
        public var selectedBackgroundColorHex: String
        public var selectionDateFormat: String
        public var selectionDateSeparator: String
        public var allowsRangeSelection: Bool
        public var resetSelectionOnThirdTap: Bool

        public init(
          selectedTextColorHex: String,
          selectedBackgroundColorHex: String,
          selectionDateFormat: String,
          selectionDateSeparator: String,
          allowsRangeSelection: Bool,
          resetSelectionOnThirdTap: Bool
        ) {
          self.selectedTextColorHex = selectedTextColorHex
          self.selectedBackgroundColorHex = selectedBackgroundColorHex
          self.selectionDateFormat = selectionDateFormat
          self.selectionDateSeparator = selectionDateSeparator
          self.allowsRangeSelection = allowsRangeSelection
          self.resetSelectionOnThirdTap = resetSelectionOnThirdTap
        }
      }

      public struct AgendaStyle {
        public var layout: MonthCalendarPopupLayout
        public var appointmentsScrollable: Bool
        public var appointmentsMinHeight: Double
        public var appointmentsMaxHeight: Double
        public var agendaTitle: String
        public var maxVisibleAppointments: Int

        public init(
          layout: MonthCalendarPopupLayout,
          appointmentsScrollable: Bool,
          appointmentsMinHeight: Double,
          appointmentsMaxHeight: Double,
          agendaTitle: String,
          maxVisibleAppointments: Int
        ) {
          self.layout = layout
          self.appointmentsScrollable = appointmentsScrollable
          self.appointmentsMinHeight = appointmentsMinHeight
          self.appointmentsMaxHeight = appointmentsMaxHeight
          self.agendaTitle = agendaTitle
          self.maxVisibleAppointments = maxVisibleAppointments
        }
      }

      public struct AnchorStyle {
        public var dateFormat: String
        public var textColorHex: String?
        public var showDateText: Bool

        public init(dateFormat: String, textColorHex: String?, showDateText: Bool) {
          self.dateFormat = dateFormat
          self.textColorHex = textColorHex
          self.showDateText = showDateText
        }
      }

      public struct TodayButtonStyle {
        public var title: String
        public var icon: String
        public var borderColorHex: String
        public var borderWidth: Double

        public init(
          title: String,
          icon: String,
          borderColorHex: String,
          borderWidth: Double
        ) {
          self.title = title
          self.icon = icon
          self.borderColorHex = borderColorHex
          self.borderWidth = borderWidth
        }
      }

      public var style: Style
      public var calendar: CalendarStyle
      public var selection: SelectionStyle
      public var agenda: AgendaStyle
      public var anchor: AnchorStyle
      public var todayButton: TodayButtonStyle

      public init(
        style: Style,
        calendar: CalendarStyle,
        selection: SelectionStyle,
        agenda: AgendaStyle,
        anchor: AnchorStyle,
        todayButton: TodayButtonStyle
      ) {
        self.style = style
        self.calendar = calendar
        self.selection = selection
        self.agenda = agenda
        self.anchor = anchor
        self.todayButton = todayButton
      }

      public var backgroundColorHex: String {
        get { style.backgroundColorHex }
        set { style.backgroundColorHex = newValue }
      }

      public var borderColorHex: String {
        get { style.borderColorHex }
        set { style.borderColorHex = newValue }
      }

      public var borderWidth: Double {
        get { style.borderWidth }
        set { style.borderWidth = newValue }
      }

      public var cornerRadius: Double {
        get { style.cornerRadius }
        set { style.cornerRadius = newValue }
      }

      public var paddingX: Double {
        get { style.paddingX }
        set { style.paddingX = newValue }
      }

      public var paddingY: Double {
        get { style.paddingY }
        set { style.paddingY = newValue }
      }

      public var spacing: Double {
        get { style.spacing }
        set { style.spacing = newValue }
      }

      public var marginX: Double {
        get { style.marginX }
        set { style.marginX = newValue }
      }

      public var marginY: Double {
        get { style.marginY }
        set { style.marginY = newValue }
      }

      public var showWeekNumbers: Bool {
        get { calendar.showWeekNumbers }
        set { calendar.showWeekNumbers = newValue }
      }

      public var showEventIndicators: Bool {
        get { calendar.showEventIndicators }
        set { calendar.showEventIndicators = newValue }
      }

      public var headerTextColorHex: String {
        get { calendar.headerTextColorHex }
        set { calendar.headerTextColorHex = newValue }
      }

      public var weekdayTextColorHex: String {
        get { calendar.weekdayTextColorHex }
        set { calendar.weekdayTextColorHex = newValue }
      }

      public var firstWeekday: Int? {
        get { calendar.firstWeekday }
        set { calendar.firstWeekday = newValue }
      }

      public var weekdayFormat: String {
        get { calendar.weekdayFormat }
        set { calendar.weekdayFormat = newValue }
      }

      public var weekdaySymbols: [String]? {
        get { calendar.weekdaySymbols }
        set { calendar.weekdaySymbols = newValue }
      }

      public var resolvedWeekdaySymbols: [String] {
        get { calendar.resolvedWeekdaySymbols }
        set { calendar.resolvedWeekdaySymbols = newValue }
      }

      public var dayTextColorHex: String {
        get { calendar.dayTextColorHex }
        set { calendar.dayTextColorHex = newValue }
      }

      public var outsideMonthTextColorHex: String {
        get { calendar.outsideMonthTextColorHex }
        set { calendar.outsideMonthTextColorHex = newValue }
      }

      public var todayCellBackgroundColorHex: String {
        get { calendar.todayCellBackgroundColorHex }
        set { calendar.todayCellBackgroundColorHex = newValue }
      }

      public var todayCellBorderColorHex: String {
        get { calendar.todayCellBorderColorHex }
        set { calendar.todayCellBorderColorHex = newValue }
      }

      public var todayCellBorderWidth: Double {
        get { calendar.todayCellBorderWidth }
        set { calendar.todayCellBorderWidth = newValue }
      }

      public var indicatorColorHex: String {
        get { calendar.indicatorColorHex }
        set { calendar.indicatorColorHex = newValue }
      }

      public var selectedTextColorHex: String {
        get { selection.selectedTextColorHex }
        set { selection.selectedTextColorHex = newValue }
      }

      public var selectedBackgroundColorHex: String {
        get { selection.selectedBackgroundColorHex }
        set { selection.selectedBackgroundColorHex = newValue }
      }

      public var selectionDateFormat: String {
        get { selection.selectionDateFormat }
        set { selection.selectionDateFormat = newValue }
      }

      public var selectionDateSeparator: String {
        get { selection.selectionDateSeparator }
        set { selection.selectionDateSeparator = newValue }
      }

      public var allowsRangeSelection: Bool {
        get { selection.allowsRangeSelection }
        set { selection.allowsRangeSelection = newValue }
      }

      public var resetSelectionOnThirdTap: Bool {
        get { selection.resetSelectionOnThirdTap }
        set { selection.resetSelectionOnThirdTap = newValue }
      }

      public var layout: MonthCalendarPopupLayout {
        get { agenda.layout }
        set { agenda.layout = newValue }
      }

      public var appointmentsScrollable: Bool {
        get { agenda.appointmentsScrollable }
        set { agenda.appointmentsScrollable = newValue }
      }

      public var appointmentsMinHeight: Double {
        get { agenda.appointmentsMinHeight }
        set { agenda.appointmentsMinHeight = newValue }
      }

      public var appointmentsMaxHeight: Double {
        get { agenda.appointmentsMaxHeight }
        set { agenda.appointmentsMaxHeight = newValue }
      }

      public var agendaTitle: String {
        get { agenda.agendaTitle }
        set { agenda.agendaTitle = newValue }
      }

      public var maxVisibleAppointments: Int {
        get { agenda.maxVisibleAppointments }
        set { agenda.maxVisibleAppointments = newValue }
      }

      public var anchorDateFormat: String {
        get { anchor.dateFormat }
        set { anchor.dateFormat = newValue }
      }

      public var anchorTextColorHex: String? {
        get { anchor.textColorHex }
        set { anchor.textColorHex = newValue }
      }

      public var anchorShowDateText: Bool {
        get { anchor.showDateText }
        set { anchor.showDateText = newValue }
      }

      public var todayButtonTitle: String {
        get { todayButton.title }
        set { todayButton.title = newValue }
      }

      public var todayButtonIcon: String {
        get { todayButton.icon }
        set { todayButton.icon = newValue }
      }

      public var todayButtonBorderColorHex: String {
        get { todayButton.borderColorHex }
        set { todayButton.borderColorHex = newValue }
      }

      public var todayButtonBorderWidth: Double {
        get { todayButton.borderWidth }
        set { todayButton.borderWidth = newValue }
      }
    }

    public var popup: Popup

    public init(popup: Popup) {
      self.popup = popup
    }
  }

  public var placement: CalendarWidgetPlacement
  public var style: CalendarWidgetStyle
  public var popupMode: CalendarPopupMode
  public var anchor: Anchor
  public var filters: Filters
  public var appointments: Appointments
  public var birthdays: Birthdays
  public var composer: Composer
  public var upcoming: Upcoming
  public var month: Month

  public init(
    placement: CalendarWidgetPlacement,
    style: CalendarWidgetStyle,
    popupMode: CalendarPopupMode,
    anchor: Anchor,
    filters: Filters,
    appointments: Appointments,
    birthdays: Birthdays,
    composer: Composer,
    upcoming: Upcoming,
    month: Month
  ) {
    self.placement = placement
    self.style = style
    self.popupMode = popupMode
    self.anchor = anchor
    self.filters = filters
    self.appointments = appointments
    self.birthdays = birthdays
    self.composer = composer
    self.upcoming = upcoming
    self.month = month
  }

  public var enabled: Bool {
    get { placement.enabled }
    set { placement.enabled = newValue }
  }

  public var position: WidgetPosition {
    get { placement.position }
    set { placement.position = newValue }
  }

  public var order: Int {
    get { placement.order }
    set { placement.order = newValue }
  }
}

extension CalendarBuiltinConfig {
  public static let `default` = CalendarBuiltinConfig(
    placement: .init(enabled: false, position: .right, order: 60),
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
    filters: .init(includedCalendarNames: [], excludedCalendarNames: []),
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
    composer: .init(
      style: .init(
        backgroundColorHex: "#111111",
        borderColorHex: "#444444",
        borderWidth: 1,
        cornerRadius: 10,
        paddingX: 14,
        paddingY: 14,
        headerTextColorHex: "#ffffff"
      ),
      content: .init(
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
      )
    ),
    upcoming: .init(
      events: .init(days: 3, excludePastEvents: false),
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
          resolvedWeekdaySymbols: resolveMonthWeekdaySymbols(format: "dd", manualSymbols: nil),
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
          layout: .calendarAppointmentsVertical,
          appointmentsScrollable: true,
          appointmentsMinHeight: 140,
          appointmentsMaxHeight: 240,
          agendaTitle: "Appointments",
          maxVisibleAppointments: 8
        ),
        anchor: .init(dateFormat: "EEE d MMM", textColorHex: "#ffffff", showDateText: true),
        todayButton: .init(
          title: "Today",
          icon: "",
          borderColorHex: "#3F2F6B",
          borderWidth: 1.5
        )
      )
    )
  )

  public static func resolveMonthWeekdaySymbols(
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

    guard sundayFirstSymbols.count == 7 else {
      return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    return Array(sundayFirstSymbols[1...6]) + [sundayFirstSymbols[0]]
  }
}
