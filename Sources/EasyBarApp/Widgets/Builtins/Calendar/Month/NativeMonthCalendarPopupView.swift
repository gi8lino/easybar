import EasyBarCalendarUI
import SwiftUI

/// EasyBar adapter for the reusable month-calendar popup.
struct NativeMonthCalendarPopupView: View {
  @EnvironmentObject private var configStore: ConfigSnapshotStore
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  /// Renders the EasyBar-wired month-calendar popup.
  var body: some View {
    let config = configStore.snapshot.builtins.calendar

    CalendarMonthPopupView(
      store: NativeMonthCalendarStore.shared,
      logger: NativeMonthCalendarStore.shared.logger,
      config: config.calendarMonthPopupUIConfig,
      appointmentsStyle: config.appointmentsCalendarUIStyle,
      birthdays: config.birthdayCalendarUIStyle,
      emptyText: config.appointments.emptyText,
      eventActions: CalendarEventActionFactory.makeActions(),
      onVisibleMonthChanged: { visibleMonth in
        MonthCalendarAgentClient.shared.focusVisibleMonth(visibleMonth)
      },
      onCreateEvent: { defaultDate, onChanged in
        composerPanel.present(
          defaultDate: defaultDate,
          config: config,
          onChanged: onChanged
        )
      },
      onEditEvent: { event, onChanged in
        composerPanel.present(
          event: event,
          config: config,
          onChanged: onChanged
        )
      },
      onRefreshRequested: {
        MonthCalendarAgentClient.shared.refresh()
        UpcomingCalendarAgentClient.shared.refresh()
      }
    )
  }
}
