import Foundation

extension Config.CalendarBuiltinConfig {

  struct Month {
    struct Popup {
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

      var todayCellBackgroundColorHex: String {
        get { calendar.todayCellBackgroundColorHex }
        set { calendar.todayCellBackgroundColorHex = newValue }
      }

      var todayCellBorderColorHex: String {
        get { calendar.todayCellBorderColorHex }
        set { calendar.todayCellBorderColorHex = newValue }
      }

      var todayCellBorderWidth: Double {
        get { calendar.todayCellBorderWidth }
        set { calendar.todayCellBorderWidth = newValue }
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

      var layout: Config.MonthCalendarPopupLayout {
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

      var composerAlertLabels: [String: String] {
        get { composer.alertLabels }
        set { composer.alertLabels = newValue }
      }

      var composerTravelTimeLabels: [String: String] {
        get { composer.travelTimeLabels }
        set { composer.travelTimeLabels = newValue }
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

      var todayButtonIcon: String {
        get { todayButton.icon }
        set { todayButton.icon = newValue }
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
}
