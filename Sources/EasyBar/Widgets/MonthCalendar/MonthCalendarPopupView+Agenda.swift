import SwiftUI

// MARK: - Selection And Agenda

extension NativeMonthCalendarPopupView {
  /// Builds the appointments container, optionally scrollable.
  @ViewBuilder
  var appointmentsContainerView: some View {
    if config.appointmentsScrollable {
      ScrollView(.vertical, showsIndicators: true) {
        appointmentsView
      }
      .frame(
        maxWidth: .infinity,
        minHeight: appointmentsMinHeight,
        maxHeight: appointmentsMaxHeight,
        alignment: .topLeading
      )
    } else {
      appointmentsView
        .frame(
          maxWidth: .infinity,
          minHeight: appointmentsMinHeight,
          maxHeight: appointmentsMaxHeight,
          alignment: .topLeading
        )
    }
  }

  /// Builds the selected appointments list.
  @ViewBuilder
  var appointmentsView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(config.agendaTitle)
        .foregroundStyle(color(config.headerTextColorHex))
        .padding(.top, agendaTitleTopPadding)

      if visibleAgendaRows.isEmpty {
        Text(config.emptyText)
          .foregroundStyle(color(config.emptyTextColorHex))
      } else {
        ForEach(visibleAgendaRows) { row in
          switch row.kind {
          case .dayHeader(let date):
            selectionDayHeaderView(for: date)

          case .event(let event):
            appointmentRow(event)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  /// Returns the extra top padding for the agenda title in vertical layouts.
  var agendaTitleTopPadding: CGFloat {
    switch config.layout {
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return 6
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 0
    }
  }

  /// Builds one selected-day header row.
  func selectionDayHeaderView(for date: Date) -> some View {
    Text(formattedSelectionDate(date))
      .foregroundStyle(color(config.secondaryTextColorHex))
      .padding(.top, 2)
  }

  /// Builds one appointment row.
  func appointmentRow(_ event: NativeMonthCalendarEvent) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Rectangle()
        .fill(color(normalizedIndicatorColorHex(for: event)))
        .frame(width: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))

      VStack(alignment: .leading, spacing: 2) {
        if let travelTimeText = travelTimeText(for: event) {
          Text(travelTimeText)
            .foregroundStyle(color(config.secondaryTextColorHex))
        }

        appointmentTitleView(for: event)

        if config.showCalendarName,
          let calendarName = event.calendarName,
          !calendarName.isEmpty
        {
          Text(calendarName)
            .foregroundStyle(color(config.secondaryTextColorHex))
        }

        if let locationText = event.location, !locationText.isEmpty {
          Text(locationText)
            .foregroundStyle(color(config.secondaryTextColorHex))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.leading, CGFloat(config.itemIndent))
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
      openComposer(for: event)
    }
  }

  /// Builds the primary appointment title line.
  @ViewBuilder
  func appointmentTitleView(for event: NativeMonthCalendarEvent) -> some View {
    let prefix = appointmentPrefix(for: event)

    HStack(alignment: .firstTextBaseline, spacing: 4) {
      if !prefix.isEmpty {
        Text(prefix)
          .foregroundStyle(color(config.eventTextColorHex))
      }

      if isBirthdayEvent(event) {
        Text(config.birthdayIcon)
          .font(Theme.iconFont(size: 13))
          .foregroundStyle(color(config.birthdayIconColorHex ?? config.eventTextColorHex))
      }

      Text(event.title)
        .foregroundStyle(color(config.eventTextColorHex))
    }
  }

  /// Returns the currently selected events.
  var selectedEvents: [NativeMonthCalendarEvent] {
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

    Logger.debug("month calendar popup pointer_begin date=\(debugDate(date))")
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

    Logger.debug(
      "month calendar popup drag_update anchor=\(debugDate(dragAnchorDate)) current=\(debugDate(date)) start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
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
      Logger.debug("month calendar popup click_select date=\(debugDate(startDate))")
      return
    }

    selectedStartDate = min(startDate, endDate)
    selectedEndDate = max(startDate, endDate)

    Logger.debug(
      "month calendar popup drag_end start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Returns the rendered prefix shown before the title when needed.
  func appointmentPrefix(for event: NativeMonthCalendarEvent) -> String {
    if event.isAllDay {
      if isBirthdayEvent(event) {
        return ""
      }

      return config.showAllDayLabel ? "All day" : ""
    }

    return formattedEventTime(event.startDate)
  }

  /// Returns whether the given event is a birthday event.
  func isBirthdayEvent(_ event: NativeMonthCalendarEvent) -> Bool {
    event.id.hasPrefix("birthday-")
  }

  /// Returns the rendered travel-time text when available.
  func travelTimeText(for event: NativeMonthCalendarEvent) -> String? {
    guard let travelTimeSeconds = event.travelTimeSeconds, travelTimeSeconds > 0 else { return nil }

    let minutes = Int((travelTimeSeconds / 60).rounded())
    guard minutes > 0 else { return nil }

    return "\(minutes) min"
  }

  /// Formats one event time.
  func formattedEventTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
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
  func displayDate(for event: NativeMonthCalendarEvent) -> Date {
    let eventStartDay = resolvedCalendar.startOfDay(for: event.startDate)
    let selectionStartDay = resolvedCalendar.startOfDay(
      for: min(selectedStartDate, selectedEndDate))
    return max(eventStartDay, selectionStartDay)
  }
}
