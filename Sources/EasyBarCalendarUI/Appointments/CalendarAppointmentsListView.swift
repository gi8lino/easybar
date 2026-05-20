import EasyBarCalendarPresentation
import EasyBarShared
import SwiftUI

/// Reusable style values for calendar appointments lists.
public struct CalendarAppointmentsStyle: Sendable {
  public let secondaryTextColorHex: String
  public let emptyTextColorHex: String
  public let eventTextColorHex: String
  public let travelTextColorHex: String
  public let travelIconColorHex: String?
  public let alertIconColorHex: String?
  public let showCalendarName: Bool
  public let showLocation: Bool
  public let showTravelTime: Bool
  public let showEndTime: Bool
  public let showAlertIcon: Bool
  public let showAllDayLabel: Bool
  public let allDayLabel: String
  public let showHolidayAllDayLabel: Bool
  public let alertIcon: String
  public let travelIcon: String
  public let itemIndent: Double

  public init(
    secondaryTextColorHex: String,
    emptyTextColorHex: String,
    eventTextColorHex: String,
    travelTextColorHex: String,
    travelIconColorHex: String?,
    alertIconColorHex: String?,
    showCalendarName: Bool,
    showLocation: Bool,
    showTravelTime: Bool,
    showEndTime: Bool,
    showAlertIcon: Bool,
    showAllDayLabel: Bool,
    allDayLabel: String,
    showHolidayAllDayLabel: Bool,
    alertIcon: String,
    travelIcon: String,
    itemIndent: Double
  ) {
    self.secondaryTextColorHex = secondaryTextColorHex
    self.emptyTextColorHex = emptyTextColorHex
    self.eventTextColorHex = eventTextColorHex
    self.travelTextColorHex = travelTextColorHex
    self.travelIconColorHex = travelIconColorHex
    self.alertIconColorHex = alertIconColorHex
    self.showCalendarName = showCalendarName
    self.showLocation = showLocation
    self.showTravelTime = showTravelTime
    self.showEndTime = showEndTime
    self.showAlertIcon = showAlertIcon
    self.showAllDayLabel = showAllDayLabel
    self.allDayLabel = allDayLabel
    self.showHolidayAllDayLabel = showHolidayAllDayLabel
    self.alertIcon = alertIcon
    self.travelIcon = travelIcon
    self.itemIndent = itemIndent
  }
}

/// One render row in a calendar appointments list.
public struct CalendarAppointmentsListRow: Identifiable {
  public enum Kind {
    case dayHeader(Date)
    case event(CalendarAgentEvent)
  }

  public let id: String
  public let kind: Kind

  public init(id: String, kind: Kind) {
    self.id = id
    self.kind = kind
  }
}

/// Shared appointments list used by calendar month and upcoming surfaces.
public struct CalendarAppointmentsListView: View {
  public let title: String?
  public let rows: [CalendarAppointmentsListRow]
  public let emptyText: String
  public let style: CalendarAppointmentsStyle
  public let birthdayIcon: String
  public let birthdayIconColorHex: String?
  public let defaultIndicatorColorHex: String
  public let calendar: Calendar
  public let dateHeaderText: (Date) -> String
  public let onEventTap: ((CalendarAgentEvent) -> Void)?

  public init(
    title: String?,
    rows: [CalendarAppointmentsListRow],
    emptyText: String,
    style: CalendarAppointmentsStyle,
    birthdayIcon: String,
    birthdayIconColorHex: String?,
    defaultIndicatorColorHex: String,
    calendar: Calendar,
    dateHeaderText: @escaping (Date) -> String,
    onEventTap: ((CalendarAgentEvent) -> Void)?
  ) {
    self.title = title
    self.rows = rows
    self.emptyText = emptyText
    self.style = style
    self.birthdayIcon = birthdayIcon
    self.birthdayIconColorHex = birthdayIconColorHex
    self.defaultIndicatorColorHex = defaultIndicatorColorHex
    self.calendar = calendar
    self.dateHeaderText = dateHeaderText
    self.onEventTap = onEventTap
  }

  public var body: some View {
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
    let isBirthday = CalendarAgendaBuilder.isBirthdayEvent(event)
    let content = appointmentRowContent(event, showsChevron: !isBirthday && onEventTap != nil)

    if let onEventTap, !isBirthday {
      return AnyView(
        content
          .contentShape(Rectangle())
          .onTapGesture { onEventTap(event) }
      )
    }

    return AnyView(content)
  }

  private func appointmentRowContent(_ event: CalendarAgentEvent, showsChevron: Bool) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Rectangle()
        .fill(color(indicatorColorHex(for: event)))
        .frame(width: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))

      VStack(alignment: .leading, spacing: 2) {
        appointmentMetaTopView(for: event)
        appointmentTitleView(for: event)
        appointmentEndTimeView(for: event)

        if style.showCalendarName, let calendarName = event.calendarName, !calendarName.isEmpty {
          Text(calendarName)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color(style.secondaryTextColorHex))
        }

        if style.showLocation, let locationText = event.location, !locationText.isEmpty {
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
        Text(CalendarEventFormatter.formattedEventTime(event.startDate, calendar: calendar))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(color(style.eventTextColorHex))
      }

      if CalendarAgendaBuilder.isBirthdayEvent(event) {
        Text(birthdayIcon)
          .font(CalendarUIPrimitives.iconFont(size: 13))
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
            .font(CalendarUIPrimitives.iconFont(size: 11))
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
      let travelTimeText = CalendarEventFormatter.travelTimeText(travelTimeSeconds: travelTimeSeconds),
      let departureTimeText = CalendarEventFormatter.travelDepartureTimeText(
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
          .font(CalendarUIPrimitives.iconFont(size: 11))
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
      let endTimeText = CalendarEventFormatter.endTimeText(
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
    guard !CalendarAgendaBuilder.isBirthdayEvent(event) else { return "" }
    guard !event.isHoliday || style.showHolidayAllDayLabel else { return "" }
    return style.showAllDayLabel ? style.allDayLabel : ""
  }

  private func indicatorColorHex(for event: CalendarAgentEvent) -> String {
    if let hex = event.calendarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
      return hex
    }
    return defaultIndicatorColorHex
  }

  private func color(_ hex: String) -> Color {
    Color(calendarHex: hex)
  }
}
