import EasyBarShared
import SwiftUI

struct CalendarAppointmentsListRow: Identifiable {
  enum Kind {
    case dayHeader(Date)
    case event(CalendarAgentEvent)
  }

  let id: String
  let kind: Kind
}

struct CalendarAppointmentsListView: View {
  let title: String?
  let rows: [CalendarAppointmentsListRow]
  let emptyText: String
  let style: Config.CalendarBuiltinConfig.Appointments
  let birthdayIcon: String
  let birthdayIconColorHex: String?
  let defaultIndicatorColorHex: String
  let calendar: Calendar
  let dateHeaderText: (Date) -> String
  let onEventTap: ((CalendarAgentEvent) -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let title, !title.isEmpty {
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(color(style.secondaryTextColorHex))
          .padding(.top, 2)
          .padding(.bottom, 1)
      }

      if rows.isEmpty {
        Text(emptyText)
          .foregroundStyle(color(style.emptyTextColorHex))
      } else {
        ForEach(rows) { row in
          switch row.kind {
          case .dayHeader(let date):
            Text(dateHeaderText(date))
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(color(style.secondaryTextColorHex))
              .padding(.top, 2)
              .padding(.bottom, 1)

          case .event(let event):
            appointmentRow(event)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func appointmentRow(_ event: CalendarAgentEvent) -> some View {
    let isBirthday = isBirthdayEvent(event)
    let content = appointmentRowContent(event, showsChevron: !isBirthday && onEventTap != nil)

    if let onEventTap, !isBirthday {
      return AnyView(
        content
          .contentShape(Rectangle())
          .onTapGesture {
            onEventTap(event)
          }
      )
    }

    return AnyView(content)
  }

  private func appointmentRowContent(
    _ event: CalendarAgentEvent,
    showsChevron: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Rectangle()
        .fill(color(indicatorColorHex(for: event)))
        .frame(width: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))

      VStack(alignment: .leading, spacing: 2) {
        appointmentMetaTopView(for: event)
        appointmentTitleView(for: event)
        appointmentEndTimeView(for: event)

        if style.showCalendarName,
          let calendarName = event.calendarName,
          !calendarName.isEmpty
        {
          Text(calendarName)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color(style.secondaryTextColorHex))
        }

        if style.showLocation,
          let locationText = event.location,
          !locationText.isEmpty
        {
          Text(locationText)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color(style.secondaryTextColorHex))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(color(style.secondaryTextColorHex).opacity(0.8))
          .padding(.top, 3)
      }
    }
    .padding(.leading, CGFloat(style.itemIndent))
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private func appointmentTitleView(for event: CalendarAgentEvent) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if event.isAllDay {
        let prefix = appointmentPrefix(for: event)

        if !prefix.isEmpty {
          Text(prefix)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color(style.secondaryTextColorHex))
        }
      } else {
        Text(CalendarEventPresentation.formattedEventTime(event.startDate, calendar: calendar))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(color(style.eventTextColorHex))
      }

      if isBirthdayEvent(event) {
        Text(birthdayIcon)
          .font(Theme.iconFont(size: 13))
          .foregroundStyle(color(birthdayIconColorHex ?? style.eventTextColorHex))
      }

      Text(event.title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(color(style.eventTextColorHex))
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      if !event.isAllDay {
        Spacer(minLength: 0)

        if style.showAlertIcon, event.hasAlert {
          Text(style.alertIcon)
            .font(Theme.iconFont(size: 11))
            .foregroundStyle(color(style.alertIconColorHex ?? style.travelTextColorHex))
        }
      }
    }
  }

  @ViewBuilder
  private func appointmentMetaTopView(for event: CalendarAgentEvent) -> some View {
    if !event.isAllDay,
      style.showTravelTime,
      let travelTimeSeconds = event.travelTimeSeconds,
      let travelTimeText = CalendarEventPresentation.travelTimeText(
        travelTimeSeconds: travelTimeSeconds),
      let departureTimeText = CalendarEventPresentation.travelDepartureTimeText(
        startDate: event.startDate,
        travelTimeSeconds: travelTimeSeconds,
        calendar: calendar
      )
    {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(departureTimeText)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(color(style.travelTextColorHex))

        Text(style.travelIcon)
          .font(Theme.iconFont(size: 11))
          .foregroundStyle(color(style.travelIconColorHex ?? style.travelTextColorHex))

        Text(travelTimeText)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(color(style.travelTextColorHex))
      }
    }
  }

  @ViewBuilder
  private func appointmentEndTimeView(for event: CalendarAgentEvent) -> some View {
    if style.showEndTime,
      let endTimeText = CalendarEventPresentation.endTimeText(
        startDate: event.startDate,
        endDate: event.endDate,
        isAllDay: event.isAllDay,
        calendar: calendar
      )
    {
      Text(endTimeText)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color(style.travelTextColorHex))
    }
  }

  private func appointmentPrefix(for event: CalendarAgentEvent) -> String {
    guard event.isAllDay else { return "" }
    guard !isBirthdayEvent(event) else { return "" }
    guard !event.isHoliday || style.showHolidayAllDayLabel else { return "" }
    return style.showAllDayLabel ? style.allDayLabel : ""
  }

  private func isBirthdayEvent(_ event: CalendarAgentEvent) -> Bool {
    event.id.hasPrefix("birthday-")
  }

  private func indicatorColorHex(for event: CalendarAgentEvent) -> String {
    if let hex = event.calendarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
      !hex.isEmpty
    {
      return hex
    }

    return defaultIndicatorColorHex
  }

  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}
