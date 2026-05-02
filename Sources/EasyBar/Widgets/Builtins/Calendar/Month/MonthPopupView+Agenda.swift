import EasyBarShared
import SwiftUI

// MARK: - Selection And Agenda

extension NativeMonthCalendarPopupView {
  /// Builds the appointments container, optionally scrollable.
  @ViewBuilder
  var appointmentsContainerView: some View {
    VStack(alignment: .leading, spacing: 8) {
      appointmentsHeaderView

      if config.appointmentsScrollable {
        ScrollView(.vertical, showsIndicators: true) {
          appointmentsContentView
        }
        .frame(
          maxWidth: .infinity,
          minHeight: appointmentsMinHeight,
          maxHeight: appointmentsMaxHeight,
          alignment: .topLeading
        )
      } else {
        appointmentsContentView
          .frame(
            maxWidth: .infinity,
            minHeight: appointmentsMinHeight,
            maxHeight: appointmentsMaxHeight,
            alignment: .topLeading
          )
      }
    }
  }

  /// Builds the appointments header row with section title and create action.
  var appointmentsHeaderView: some View {
    HStack(alignment: .center, spacing: 10) {
      Text(config.agendaTitle)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(color(config.headerTextColorHex))

      Spacer()

      Button(action: openComposer) {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(color(config.headerTextColorHex))
          .frame(width: 24, height: 24)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(Color.white.opacity(0.05))
          )
          .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .stroke(color(config.borderColorHex).opacity(0.8), lineWidth: 1)
          }
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, agendaTitleTopPadding)
  }

  /// Builds the selected appointments content.
  @ViewBuilder
  var appointmentsContentView: some View {
    CalendarAppointmentsListView(
      title: nil,
      rows: appointmentListRows,
      emptyText: appointments.emptyText,
      style: appointments,
      birthdayIcon: birthdays.birthdayIcon,
      birthdayIconColorHex: birthdays.birthdayIconColorHex,
      defaultIndicatorColorHex: config.indicatorColorHex,
      calendar: resolvedCalendar,
      dateHeaderText: formattedSelectionDate,
      onEventTap: { event in
        openComposer(for: event)
      }
    )
  }

  /// Returns the extra top padding for the agenda title in vertical layouts.
  var agendaTitleTopPadding: CGFloat {
    switch config.layout {
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return 2
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 0
    }
  }

  /// Returns the shared appointment rows rendered in the month popup.
  var appointmentListRows: [CalendarAppointmentsListRow] {
    visibleAgendaRows.map { row in
      switch row.kind {
      case .dayHeader(let date):
        return CalendarAppointmentsListRow(
          id: row.id,
          kind: .dayHeader(date)
        )
      case .event(let event):
        return CalendarAppointmentsListRow(
          id: row.id,
          kind: .event(event)
        )
      }
    }
  }

  /// Returns whether the given event is a birthday event.
  func isBirthdayEvent(_ event: EasyBarShared.CalendarAgentEvent) -> Bool {
    return event.id.hasPrefix("birthday-")
  }

  /// Returns the currently selected events.
  var selectedEvents: [EasyBarShared.CalendarAgentEvent] {
    store.eventsInRange(from: selectedStartDate, to: selectedEndDate)
      .sorted { lhs, rhs in
        let lhsDate = displayDate(for: lhs)
        let rhsDate = displayDate(for: rhs)

        if lhsDate != rhsDate {
          return lhsDate < rhsDate
        }

        let lhsIsBirthday = isBirthdayEvent(lhs)
        let rhsIsBirthday = isBirthdayEvent(rhs)

        if lhsIsBirthday != rhsIsBirthday {
          return lhsIsBirthday && !rhsIsBirthday
        }

        if lhs.isAllDay != rhs.isAllDay {
          return lhs.isAllDay && !rhs.isAllDay
        }

        if lhs.startDate != rhs.startDate {
          return lhs.startDate < rhs.startDate
        }

        if lhs.endDate != rhs.endDate {
          return lhs.endDate < rhs.endDate
        }

        return lhs.id < rhs.id
      }
  }

  /// Returns the visible agenda rows, grouped by date for multi-day selections.
  var visibleAgendaRows: [AgendaRow] {
    let rows = agendaRows

    guard !config.appointmentsScrollable else {
      return rows
    }

    var limited: [AgendaRow] = []
    var visibleEventCount = 0
    let maxVisible = max(1, config.maxVisibleAppointments)

    for row in rows {
      switch row.kind {
      case .dayHeader:
        limited.append(row)

      case .event:
        guard visibleEventCount < maxVisible else { break }
        limited.append(row)
        visibleEventCount += 1
      }
    }

    while limited.last.map({
      if case .dayHeader = $0.kind { return true }
      return false
    }) == true {
      _ = limited.popLast()
    }

    return limited
  }

  /// Returns all agenda rows for the current selection.
  var agendaRows: [AgendaRow] {
    guard !selectedEvents.isEmpty else { return [] }

    guard selectionSpansMultipleDays else {
      return selectedEvents.map { event in
        AgendaRow(id: event.id, kind: .event(event))
      }
    }

    let grouped = Dictionary(grouping: selectedEvents, by: displayDate(for:))
    let sortedDates = grouped.keys.sorted()

    var rows: [AgendaRow] = []

    for date in sortedDates {
      rows.append(
        AgendaRow(
          id: "header-\(resolvedCalendar.startOfDay(for: date).timeIntervalSince1970)",
          kind: .dayHeader(date)
        )
      )

      let dayEvents =
        (grouped[date] ?? [])
        .sorted { lhs, rhs in
          let lhsIsBirthday = isBirthdayEvent(lhs)
          let rhsIsBirthday = isBirthdayEvent(rhs)

          if lhsIsBirthday != rhsIsBirthday {
            return lhsIsBirthday && !rhsIsBirthday
          }

          if lhs.isAllDay != rhs.isAllDay {
            return lhs.isAllDay && !rhs.isAllDay
          }

          if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
          }

          if lhs.endDate != rhs.endDate {
            return lhs.endDate < rhs.endDate
          }

          return lhs.id < rhs.id
        }

      rows.append(
        contentsOf: dayEvents.map { event in
          AgendaRow(id: event.id, kind: .event(event))
        })
    }

    return rows
  }

  /// Starts one pointer interaction.
  func beginPointerInteraction(on date: Date) {
    isDragSelecting = true
    dragAnchorDate = date
    dragDidCrossIntoAnotherDay = false
    lastResolvedDragDate = date

    logger.debug(
      "month calendar popup pointer_begin",
      .field("date", "\(debugDate(date))"),
    )
  }

  /// Updates the current drag selection.
  func updateDragSelection(to date: Date) {
    guard let dragAnchorDate else { return }

    if date != dragAnchorDate {
      dragDidCrossIntoAnotherDay = true
    }

    guard lastResolvedDragDate != date else { return }
    lastResolvedDragDate = date

    selectedStartDate = min(dragAnchorDate, date)
    selectedEndDate = max(dragAnchorDate, date)

    logger.debug(
      "month calendar popup drag_update",
      .field("anchor", "\(debugDate(dragAnchorDate))"),
      .field("current", "\(debugDate(date))"),
      .field("start", "\(debugDate(selectedStartDate))"),
      .field("end", "\(debugDate(selectedEndDate))"),
    )
  }

  /// Handles one grid drag change.
  func handleGridDragChanged(_ value: DragGesture.Value) {
    let startLocation = value.startLocation
    let currentLocation = value.location

    guard let startDate = resolvedDay(at: startLocation) else { return }

    if !isDragSelecting {
      beginPointerInteraction(on: startDate)
      selectedStartDate = startDate
      selectedEndDate = startDate
    }

    guard config.allowsRangeSelection else { return }
    guard let currentDate = resolvedDay(at: currentLocation) else { return }

    updateDragSelection(to: currentDate)
  }

  /// Handles one grid drag end.
  func handleGridDragEnded(_ value: DragGesture.Value) {
    defer {
      isDragSelecting = false
      dragAnchorDate = nil
      lastResolvedDragDate = nil
      dragDidCrossIntoAnotherDay = false
    }

    guard let startDate = resolvedDay(at: value.startLocation) else { return }
    let endDate = resolvedDay(at: value.location) ?? startDate

    if !dragDidCrossIntoAnotherDay || startDate == endDate {
      selectedStartDate = startDate
      selectedEndDate = startDate
      logger.debug(
        "month calendar popup click_select",
        .field("date", "\(debugDate(startDate))"),
      )
      return
    }

    selectedStartDate = min(startDate, endDate)
    selectedEndDate = max(startDate, endDate)

    logger.debug(
      "month calendar popup drag_end",
      .field("start", "\(debugDate(selectedStartDate))"),
      .field("end", "\(debugDate(selectedEndDate))"),
    )
  }

  /// Formats one grouped selection date header.
  func formattedSelectionDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = config.selectionDateFormat
    return formatter.string(from: date)
  }

  /// Returns whether the active selection spans more than one day.
  var selectionSpansMultipleDays: Bool {
    resolvedCalendar.startOfDay(for: selectedStartDate)
      != resolvedCalendar.startOfDay(for: selectedEndDate)
  }

  /// Returns the display date used to group one event in the agenda.
  func displayDate(for event: EasyBarShared.CalendarAgentEvent) -> Date {
    let eventStartDay = resolvedCalendar.startOfDay(for: event.startDate)
    let selectionStartDay = resolvedCalendar.startOfDay(
      for: min(selectedStartDate, selectedEndDate))
    return max(eventStartDay, selectionStartDay)
  }
}
