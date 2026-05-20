import EasyBarCalendarUI
import SwiftUI

/// EasyBar adapter for the reusable month-calendar popup.
struct NativeMonthCalendarPopupView: View {
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  /// Renders the EasyBar-wired month-calendar popup.
  var body: some View {
    CalendarMonthPopupView(
      store: NativeMonthCalendarStore.shared,
      logger: NativeMonthCalendarStore.shared.logger,
      config: Config.shared.builtinCalendar.month.popup.calendarMonthPopupConfig,
      appointmentsStyle: Config.shared.builtinCalendar.appointments.calendarUIStyle,
      birthdays: Config.shared.builtinCalendar.birthdays.calendarBirthdayStyle,
      emptyText: Config.shared.builtinCalendar.appointments.emptyText,
      onVisibleMonthChanged: { visibleMonth in
        MonthCalendarAgentClient.shared.focusVisibleMonth(visibleMonth)
      },
      onCreateEvent: { defaultDate, onChanged in
        composerPanel.present(defaultDate: defaultDate, onChanged: onChanged)
      },
      onEditEvent: { event, onChanged in
        composerPanel.present(event: event, onChanged: onChanged)
      },
      onRefreshRequested: {
        MonthCalendarAgentClient.shared.refresh()
        UpcomingCalendarAgentClient.shared.refresh()
      }
    )
  }
}
