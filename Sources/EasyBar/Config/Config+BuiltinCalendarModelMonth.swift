import Foundation

extension Config.CalendarBuiltinConfig {

  struct Month {
    struct Popup {
      var style: Style
      var calendar: CalendarStyle
      var selection: SelectionStyle
      var agenda: AgendaStyle
      var anchor: AnchorStyle
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

      var layout: Config.MonthCalendarPopupLayout {
        get { agenda.layout }
        set { agenda.layout = newValue }
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

      var agendaTitle: String {
        get { agenda.agendaTitle }
        set { agenda.agendaTitle = newValue }
      }

      var maxVisibleAppointments: Int {
        get { agenda.maxVisibleAppointments }
        set { agenda.maxVisibleAppointments = newValue }
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
