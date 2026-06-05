import EasyBarCalendarUI
import SwiftUI

/// EasyBar adapter for the reusable upcoming-calendar popup.
struct NativeUpcomingCalendarPopupView: View {
  @EnvironmentObject private var configStore: ConfigSnapshotStore
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  /// Renders the EasyBar-wired upcoming-calendar popup.
  var body: some View {
    let config = configStore.snapshot.builtins.calendar

    CalendarUpcomingPopupView(
      store: NativeUpcomingCalendarStore.shared,
      config: config.calendarUpcomingPopupUIConfig,
      appointmentsStyle: config.appointmentsCalendarUIStyle,
      birthdays: config.birthdayCalendarUIStyle,
      emptyText: config.appointments.emptyText,
      eventActions: CalendarEventActionFactory.makeActions(),
      onEventTap: { event in
        composerPanel.present(event: event, config: config) {
          MonthCalendarAgentClient.shared.refresh()
          UpcomingCalendarAgentClient.shared.refresh()
        }
      }
    )
  }
}
