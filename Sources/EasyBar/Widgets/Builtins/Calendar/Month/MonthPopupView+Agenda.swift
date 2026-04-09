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
    VStack(alignment: .leading, spacing: 4) {
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
      return 2
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 0
    }
  }

  /// Builds one selected-day header row.
  func selectionDayHeaderView(for date: Date) -> some View {
    Text(formattedSelectionDate(date))
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(color(config.secondaryTextColorHex))
      .padding(.top, 2)
      .padding(.bottom, 1)
  }

  /// Builds one appointment row.
  func appointmentRow(_ event: NativeMonthCalendarEvent) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Rectangle()
        .fill(color(normalizedIndicatorColorHex(for: event)))
        .frame(width: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))

      VStack(alignment: .leading, spacing: 2) {
        appointmentMetaTopView(for: event)
        appointmentTitleView(for: event)
        appointmentEndTimeView(for: event)

        if config.showCalendarName,
          let calendarName = event.calendarName,
          !calendarName.isEmpty
        {
          Text(calendarName)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color(config.secondaryTextColorHex))
        }

        if config.showLocation,
          let locationText = event.location,
          !locationText.isEmpty
        {
          Text(locationText)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color(config.secondaryTextColorHex))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: "chevron.right")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color(config.secondaryTextColorHex).opacity(0.8))
        .padding(.top, 3)
    }
    .padding(.leading, CGFloat(config.itemIndent))
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .onTapGesture {
      openComposer(for: event)
    }
  }

  /// Builds the primary appointment title line.
  @ViewBuilder
  func appointmentTitleView(for event: NativeMonthCalendarEvent) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if event.isAllDay {
        let prefix = appointmentPrefix(for: event)

        if !prefix.isEmpty {
          Text(prefix)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color(config.secondaryTextColorHex))
        }
      } else {
        Text(formattedEventTime(event.startDate))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(color(config.eventTextColorHex))
      }

      if isBirthdayEvent(event) {
        Text(config.birthdayIcon)
          .font(Theme.iconFont(size: 13))
          .foregroundStyle(color(config.birthdayIconColorHex ?? config.eventTextColorHex))
      }

      Text(event.title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(color(config.eventTextColorHex))
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      if !event.isAllDay {
        Spacer(minLength: 0)

        if config.showAlertIcon, event.hasAlert {
          Text(config.alertIcon)
            .font(Theme.iconFont(size: 11))
            .foregroundStyle(color(config.alertIconColorHex ?? config.travelTextColorHex))
        }
      }
    }
  }

  /// Builds the top metadata line for timed appointments.
  @ViewBuilder
  func appointmentMetaTopView(for event: NativeMonthCalendarEvent) -> some View {
    if !event.isAllDay,
      config.showTravelTime,
      let travelTimeText = travelTimeText(for: event),
      let departureTimeText = travelDepartureTimeText(for: event)
    {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(departureTimeText)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(color(config.travelTextColorHex))

        Text(config.travelIcon)
          .font(Theme.iconFont(size: 11))
          .foregroundStyle(color(config.travelIconColorHex ?? config.travelTextColorHex))

        Text(travelTimeText)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(color(config.travelTextColorHex))
      }
    }
  }

  /// Builds the end-time line for timed appointments.
  @ViewBuilder
  func appointmentEndTimeView(for event: NativeMonthCalendarEvent) -> some View {
    if let endTimeText = appointmentEndTimeText(for: event) {
      Text(endTimeText)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color(config.travelTextColorHex))
    }
  }

  /// Returns the rendered end time for timed appointments.
  func appointmentEndTimeText(for event: NativeMonthCalendarEvent) -> String? {
    guard !event.isAllDay, event.endDate > event.startDate else { return nil }

    let startTime = formattedEventTime(event.startDate)
    let endTime = formattedEventTime(event.endDate)
    guard startTime != endTime else { return nil }

    return endTime
  }

  /// Returns the rendered departure time when travel time is present.
  func travelDepartureTimeText(for event: NativeMonthCalendarEvent) -> String? {
    guard let travelTimeSeconds = event.travelTimeSeconds, travelTimeSeconds > 0 else { return nil }

    let departureDate = event.startDate.addingTimeInterval(-travelTimeSeconds)
    return formattedEventTime(departureDate)
  }

  /// Returns the rendered travel-time text when available.
  func travelTimeText(for event: NativeMonthCalendarEvent) -> String? {
    guard let travelTimeSeconds = event.travelTimeSeconds, travelTimeSeconds > 0 else { return nil }

    let minutes = Int((travelTimeSeconds / 60).rounded())
    guard minutes > 0 else { return nil }

    if minutes == 1 {
      return "1 min"
    }

    return "\(minutes) min"
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

    easybarLog.debug("month calendar popup pointer_begin date=\(debugDate(date))")
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

    easybarLog.debug(
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
      easybarLog.debug("month calendar popup click_select date=\(debugDate(startDate))")
      return
    }

    selectedStartDate = min(startDate, endDate)
    selectedEndDate = max(startDate, endDate)

    easybarLog.debug(
      "month calendar popup drag_end start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Returns the rendered prefix shown before the title when needed.
  func appointmentPrefix(for event: NativeMonthCalendarEvent) -> String {
    guard event.isAllDay else { return "" }
    guard !isBirthdayEvent(event) else { return "" }
    guard !event.isHoliday || config.showHolidayAllDayLabel else { return "" }
    return config.showAllDayLabel ? config.allDayLabel : ""
  }

  /// Returns whether the given event is a birthday event.
  func isBirthdayEvent(_ event: NativeMonthCalendarEvent) -> Bool {
    event.id.hasPrefix("birthday-")
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
