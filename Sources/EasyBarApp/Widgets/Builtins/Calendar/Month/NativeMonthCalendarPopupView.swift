import EasyBarCalendarUI
import SwiftUI

/// EasyBar adapter for the reusable month-calendar popup.
struct NativeMonthCalendarPopupView: View {
  @ObservedObject private var config = Config.shared
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  /// Renders the EasyBar-wired month-calendar popup.
  var body: some View {
    CalendarMonthPopupView(
      store: NativeMonthCalendarStore.shared,
      logger: NativeMonthCalendarStore.shared.logger,
      config: config.builtinCalendar.calendarMonthPopupUIConfig,
      appointmentsStyle: config.builtinCalendar.appointmentsCalendarUIStyle,
      birthdays: config.builtinCalendar.birthdayCalendarUIStyle,
      emptyText: config.builtinCalendar.appointments.emptyText,
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
