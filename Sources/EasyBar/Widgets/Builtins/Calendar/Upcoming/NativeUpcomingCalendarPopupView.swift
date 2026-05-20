import EasyBarCalendarUI
import SwiftUI

/// EasyBar adapter for the reusable upcoming-calendar popup.
struct NativeUpcomingCalendarPopupView: View {
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  /// Renders the EasyBar-wired upcoming-calendar popup.
  var body: some View {
    CalendarUpcomingPopupView(
      store: NativeUpcomingCalendarStore.shared,
      config: Config.shared.builtinCalendar.calendarUpcomingPopupUIConfig,
      appointmentsStyle: Config.shared.builtinCalendar.appointmentsCalendarUIStyle,
      birthdays: Config.shared.builtinCalendar.birthdayCalendarUIStyle,
      emptyText: Config.shared.builtinCalendar.appointments.emptyText,
      onEventTap: { event in
        composerPanel.present(event: event) {
          MonthCalendarAgentClient.shared.refresh()
          UpcomingCalendarAgentClient.shared.refresh()
        }
      }
    )
  }
}
