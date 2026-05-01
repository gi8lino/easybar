import SwiftUI

struct NativeUpcomingCalendarPopupView: View {

  @ObservedObject private var store = NativeUpcomingCalendarStore.shared
  @StateObject private var composerPanel = CalendarEventComposerPanelController()

  private let popup = Config.shared.builtinCalendar.upcoming.popup
  private let appointments = Config.shared.builtinCalendar.appointments
  private let birthdays = Config.shared.builtinCalendar.birthdays
  private let monthPopup = Config.shared.builtinCalendar.month.popup
  private let upcoming = Config.shared.builtinCalendar.upcoming

  private var resolvedCalendar: Calendar {
    var calendar = Calendar.current

    if let firstWeekday = monthPopup.firstWeekday {
      calendar.firstWeekday = firstWeekday
    }

    return calendar
  }

  /// Renders the native upcoming-calendar popup content.
  var body: some View {
    VStack(alignment: .leading, spacing: popup.spacing) {
      ForEach(upcomingDates, id: \.self) { date in
        CalendarAppointmentsListView(
          title: title(for: date),
          rows: appointmentRows(for: date),
          emptyText: appointments.emptyText,
          style: appointments,
          birthdayIcon: birthdays.birthdayIcon,
          birthdayIconColorHex: birthdays.birthdayIconColorHex,
          defaultIndicatorColorHex: monthPopup.indicatorColorHex,
          calendar: resolvedCalendar,
          dateHeaderText: formattedDayHeader,
          onEventTap: { event in
            openComposer(for: event)
          }
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, popup.paddingX)
    .padding(.vertical, popup.paddingY)
    .background(color(popup.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: popup.cornerRadius)
        .stroke(
          color(popup.borderColorHex),
          lineWidth: popup.borderWidth
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: popup.cornerRadius)
    )
    .padding(.horizontal, popup.marginX)
    .padding(.vertical, popup.marginY)
    .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
  }

  /// Returns the three dates rendered by the upcoming popup.
  private var upcomingDates: [Date] {
    let start = resolvedCalendar.startOfDay(for: Date())

    return (0..<max(1, upcoming.events.days)).compactMap { offset in
      resolvedCalendar.date(byAdding: .day, value: offset, to: start)
    }
  }

  /// Returns one formatted section title for the given date.
  private func title(for date: Date) -> String {
    if resolvedCalendar.isDateInToday(date) {
      return "Today:"
    }

    if resolvedCalendar.isDateInTomorrow(date) {
      return "Tomorrow:"
    }

    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = "dd.MM.yyyy"
    return "\(formatter.string(from: date)):"
  }

  /// Returns the event rows displayed for one upcoming day.
  private func appointmentRows(for date: Date) -> [CalendarAppointmentsListRow] {
    events(for: date).map { event in
      CalendarAppointmentsListRow(id: event.id, kind: .event(event))
    }
  }

  /// Returns the visible events for one day using the current upcoming filtering mode.
  private func events(for date: Date) -> [NativeUpcomingCalendarEvent] {
    let startOfDay = resolvedCalendar.startOfDay(for: date)
    guard let endOfDay = resolvedCalendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      return []
    }

    let now = Date()
    let effectiveStart =
      upcoming.events.excludePastEvents && resolvedCalendar.isDateInToday(date)
      ? max(startOfDay, now) : startOfDay

    return store.events
      .filter { event in
        event.startDate < endOfDay && event.endDate > effectiveStart
      }
      .sorted { lhs, rhs in
        if lhs.startDate != rhs.startDate {
          return lhs.startDate < rhs.startDate
        }

        if lhs.endDate != rhs.endDate {
          return lhs.endDate < rhs.endDate
        }

        return lhs.id < rhs.id
      }
  }

  /// Formats one day header using the month popup selection format.
  private func formattedDayHeader(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = monthPopup.selectionDateFormat
    return formatter.string(from: date)
  }

  /// Opens the shared event composer for one existing appointment.
  private func openComposer(for event: NativeUpcomingCalendarEvent) {
    composerPanel.present(event: event) {
      MonthCalendarAgentClient.shared.refresh()
      UpcomingCalendarAgentClient.shared.refresh()
    }
  }

  /// Converts one hex string into SwiftUI color.
  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}
