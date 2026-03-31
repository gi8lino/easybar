import SwiftUI

/// Renders the popup for the native month-calendar widget.
struct NativeMonthCalendarPopupView: View {

  private struct DayCell: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
  }

  private struct WeekRow: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let days: [DayCell]
  }

  private struct DayIndicatorSegment: Identifiable {
    let id: String
    let colorHex: String
    let fraction: CGFloat
  }

  @ObservedObject private var store = NativeMonthCalendarStore.shared
  private let config = Config.shared.builtinCalendar.month.popup
  private let calendar = Calendar.current

  @State private var visibleMonth = Self.startOfMonth(Date())
  @State private var selectedStartDate = Date()
  @State private var selectedEndDate = Date()

  @State private var isDragSelecting = false
  @State private var dragAnchorDate: Date?
  @State private var didDragBeyondAnchor = false

  /// Renders the month calendar popup.
  var body: some View {
    popupLayoutView
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, CGFloat(config.paddingX))
      .padding(.vertical, CGFloat(config.paddingY))
      .background(color(config.backgroundColorHex))
      .overlay {
        RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
          .stroke(
            color(config.borderColorHex),
            lineWidth: CGFloat(config.borderWidth)
          )
      }
      .clipShape(
        RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
      )
      .padding(.horizontal, CGFloat(config.marginX))
      .padding(.vertical, CGFloat(config.marginY))
      .frame(minWidth: minimumPopupWidth, maxWidth: .infinity, alignment: .leading)
      .onAppear {
        syncSelectionIntoVisibleMonth()
        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(for: visibleMonth)
        logSelection("on_appear")
      }
      .onChange(of: visibleMonth) { _, newValue in
        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(for: newValue)
      }
      .onChange(of: selectedStartDate) { _, _ in
        logSelection("selected_start_changed")
        logResolvedAppointments("selected_start_changed")
      }
      .onChange(of: selectedEndDate) { _, _ in
        logSelection("selected_end_changed")
        logResolvedAppointments("selected_end_changed")
      }
      .onChange(of: store.events.count) { _, count in
        Logger.debug("month calendar popup store events changed count=\(count)")
        logResolvedAppointments("store_events_changed")
      }
  }
}

// MARK: - Top-Level Layout

extension NativeMonthCalendarPopupView {
  /// Builds the configured popup layout.
  @ViewBuilder
  private var popupLayoutView: some View {
    switch config.layout {
    case .calendarAppointmentsHorizontal:
      HStack(alignment: .top, spacing: CGFloat(config.spacing)) {
        calendarContainerView
        agendaContainerView
      }

    case .appointmentsCalendarHorizontal:
      HStack(alignment: .top, spacing: CGFloat(config.spacing)) {
        agendaContainerView
        calendarContainerView
      }

    case .calendarAppointmentsVertical:
      VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
        calendarContainerView
        agendaContainerView
      }

    case .appointmentsCalendarVertical:
      VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
        agendaContainerView
        calendarContainerView
      }
    }
  }

  /// Returns the minimum popup width for the current layout.
  private var minimumPopupWidth: CGFloat {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 560
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return 320
    }
  }

  /// Returns the fixed height used by the calendar pane in vertical layouts.
  private var verticalCalendarHeight: CGFloat {
    250
  }

  /// Builds the calendar container.
  private var calendarContainerView: some View {
    VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
      headerView
      weekdayHeaderView
      monthGridView
    }
    .frame(
      minWidth: isHorizontalLayout ? 220 : nil,
      maxWidth: .infinity,
      minHeight: isVerticalLayout ? verticalCalendarHeight : nil,
      maxHeight: isVerticalLayout ? verticalCalendarHeight : nil,
      alignment: .topLeading
    )
  }

  /// Builds the agenda container.
  private var agendaContainerView: some View {
    VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
      appointmentsContainerView
    }
    .frame(
      minWidth: isHorizontalLayout ? 220 : nil,
      maxWidth: .infinity,
      alignment: .topLeading
    )
  }

  /// Returns whether the current popup layout is horizontal.
  private var isHorizontalLayout: Bool {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return true
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return false
    }
  }

  /// Returns whether the current popup layout is vertical.
  private var isVerticalLayout: Bool {
    !isHorizontalLayout
  }

  /// Returns the minimum height of the appointments area.
  private var appointmentsMinHeight: CGFloat {
    CGFloat(min(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }

  /// Returns the maximum height of the appointments area.
  private var appointmentsMaxHeight: CGFloat {
    CGFloat(max(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }
}

// MARK: - Header

extension NativeMonthCalendarPopupView {
  /// Builds the popup month header.
  private var headerView: some View {
    HStack(spacing: 10) {
      Button(action: showPreviousMonth) {
        Text("‹")
          .foregroundStyle(color(config.headerTextColorHex))
      }
      .buttonStyle(.plain)

      Spacer()

      Text(monthTitle)
        .foregroundStyle(color(config.headerTextColorHex))

      Spacer()

      Button(action: showNextMonth) {
        Text("›")
          .foregroundStyle(color(config.headerTextColorHex))
      }
      .buttonStyle(.plain)
    }
  }

  /// Shows the previous visible month.
  private func showPreviousMonth() {
    guard let newMonth = resolvedCalendar.date(byAdding: .month, value: -1, to: visibleMonth) else {
      return
    }

    visibleMonth = Self.startOfMonth(newMonth, calendar: resolvedCalendar)
    selectedStartDate = visibleMonth
    selectedEndDate = visibleMonth

    Logger.debug(
      "month calendar popup show_previous_month visible_month=\(debugDate(visibleMonth))")
  }

  /// Shows the next visible month.
  private func showNextMonth() {
    guard let newMonth = resolvedCalendar.date(byAdding: .month, value: 1, to: visibleMonth) else {
      return
    }

    visibleMonth = Self.startOfMonth(newMonth, calendar: resolvedCalendar)
    selectedStartDate = visibleMonth
    selectedEndDate = visibleMonth

    Logger.debug("month calendar popup show_next_month visible_month=\(debugDate(visibleMonth))")
  }

  /// Returns the visible month title.
  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: visibleMonth)
  }
}

// MARK: - Weekday Header

extension NativeMonthCalendarPopupView {
  /// Builds the weekday header row.
  private var weekdayHeaderView: some View {
    HStack(spacing: 6) {
      if config.showWeekNumbers {
        Text("W")
          .frame(width: 20, alignment: .trailing)
          .foregroundStyle(color(config.weekdayTextColorHex))
      }

      ForEach(weekdaySymbols, id: \.self) { symbol in
        Text(symbol)
          .frame(maxWidth: .infinity)
          .foregroundStyle(color(config.weekdayTextColorHex))
      }
    }
  }

  /// Returns the weekday symbols in calendar order.
  private var weekdaySymbols: [String] {
    reorderMondayFirstWeekdaySymbolsToCalendarOrder(config.resolvedWeekdaySymbols)
  }

  /// Reorders Monday-first weekday symbols into the current calendar order.
  private func reorderMondayFirstWeekdaySymbolsToCalendarOrder(_ symbols: [String]) -> [String] {
    guard symbols.count == 7 else { return symbols }

    let mondayFirstIndex = mondayFirstWeekdayIndex(for: resolvedCalendar.firstWeekday)
    return Array(symbols[mondayFirstIndex...]) + Array(symbols[..<mondayFirstIndex])
  }

  /// Converts `Calendar.firstWeekday` into a Monday-first zero-based index.
  private func mondayFirstWeekdayIndex(for firstWeekday: Int) -> Int {
    let normalized = ((firstWeekday - 1) % 7 + 7) % 7

    if normalized == 0 {
      return 6
    }

    return normalized - 1
  }
}

// MARK: - Grid

extension NativeMonthCalendarPopupView {
  /// Builds the visible month grid.
  private var monthGridView: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(weekRows) { row in
        HStack(spacing: 6) {
          if config.showWeekNumbers {
            Text("\(row.weekNumber)")
              .frame(width: 20, alignment: .trailing)
              .foregroundStyle(color(config.outsideMonthTextColorHex))
          }

          ForEach(row.days) { day in
            dayCellView(day)
          }
        }
      }
    }
  }

  /// Builds one interactive day cell.
  private func dayCellView(_ day: DayCell) -> some View {
    let normalizedDate = resolvedCalendar.startOfDay(for: day.date)

    return ZStack {
      VStack(spacing: 2) {
        Text("\(resolvedCalendar.component(.day, from: day.date))")
          .frame(width: 28, height: 22)
          .background(dayBackground(day))
          .clipShape(RoundedRectangle(cornerRadius: 6))

        dayIndicatorBar(for: day.date)
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(dayForeground(day))

      Rectangle()
        .fill(Color.clear)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              handlePointerDownOrDrag(
                on: normalizedDate,
                translation: value.translation
              )
            }
            .onEnded { _ in
              finishPointerInteraction(on: normalizedDate)
            }
        )
        .onHover { hovering in
          handleHover(on: normalizedDate, hovering: hovering)
        }
    }
    .frame(maxWidth: .infinity, minHeight: 30)
  }

  /// Builds the appointment-indicator bar for one day.
  @ViewBuilder
  private func dayIndicatorBar(for date: Date) -> some View {
    let segments = dayIndicatorSegments(for: date)

    if config.showEventIndicators, !segments.isEmpty {
      HStack(spacing: 1) {
        ForEach(segments) { segment in
          Rectangle()
            .fill(color(segment.colorHex))
            .frame(
              width: max(1, floor(18 * segment.fraction)),
              height: 3
            )
        }
      }
      .frame(width: 18, height: 3, alignment: .center)
      .clipShape(RoundedRectangle(cornerRadius: 1.5))
      .opacity(1)
    } else {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(Color.clear)
        .frame(width: 18, height: 3)
        .opacity(0)
    }
  }

  /// Returns the per-calendar indicator segments for one day.
  private func dayIndicatorSegments(for date: Date) -> [DayIndicatorSegment] {
    let events = store.eventsForDay(date)
    guard !events.isEmpty else { return [] }

    var countsByColor: [String: Int] = [:]
    var orderedColors: [String] = []

    for event in events {
      let colorHex = normalizedIndicatorColorHex(for: event)

      if countsByColor[colorHex] == nil {
        orderedColors.append(colorHex)
        countsByColor[colorHex] = 0
      }

      countsByColor[colorHex, default: 0] += 1
    }

    let total = max(1, countsByColor.values.reduce(0, +))

    return orderedColors.compactMap { colorHex in
      guard let count = countsByColor[colorHex], count > 0 else { return nil }

      return DayIndicatorSegment(
        id: "\(resolvedCalendar.startOfDay(for: date).timeIntervalSince1970)-\(colorHex)",
        colorHex: colorHex,
        fraction: CGFloat(count) / CGFloat(total)
      )
    }
  }

  /// Returns the indicator color for one event, falling back to the configured default.
  private func normalizedIndicatorColorHex(for event: NativeMonthCalendarEvent) -> String {
    if let hex = event.calendarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
      !hex.isEmpty
    {
      return hex
    }

    return config.indicatorColorHex
  }

  /// Returns the computed week rows for the visible month.
  private var weekRows: [WeekRow] {
    guard let monthRange = resolvedCalendar.dateInterval(of: .month, for: visibleMonth) else {
      return []
    }

    let firstWeekStart =
      resolvedCalendar.dateInterval(of: .weekOfMonth, for: monthRange.start)?.start
      ?? monthRange.start

    let lastVisibleDay =
      resolvedCalendar.date(byAdding: .day, value: -1, to: monthRange.end)
      ?? monthRange.end

    let lastWeekEnd =
      resolvedCalendar.dateInterval(of: .weekOfMonth, for: lastVisibleDay)?.end
      ?? monthRange.end

    var rows: [WeekRow] = []
    var currentWeekStart = firstWeekStart

    while currentWeekStart < lastWeekEnd {
      let weekNumber = resolvedCalendar.component(.weekOfYear, from: currentWeekStart)

      let days = (0..<7).compactMap { offset -> DayCell? in
        guard let date = resolvedCalendar.date(byAdding: .day, value: offset, to: currentWeekStart)
        else {
          return nil
        }

        return DayCell(
          date: date,
          isCurrentMonth: resolvedCalendar.isDate(
            date,
            equalTo: visibleMonth,
            toGranularity: .month
          )
        )
      }

      rows.append(
        WeekRow(
          weekNumber: weekNumber,
          days: days
        )
      )

      guard let nextWeek = resolvedCalendar.date(byAdding: .day, value: 7, to: currentWeekStart)
      else {
        break
      }

      currentWeekStart = nextWeek
    }

    return rows
  }
}

// MARK: - Selection And Agenda

extension NativeMonthCalendarPopupView {
  /// Builds the appointments container, optionally scrollable.
  @ViewBuilder
  private var appointmentsContainerView: some View {
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
  private var appointmentsView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(config.agendaTitle)
        .foregroundStyle(color(config.headerTextColorHex))

      if selectedEvents.isEmpty {
        Text(config.emptyText)
          .foregroundStyle(color(config.emptyTextColorHex))
      } else {
        ForEach(visibleSelectedEvents) { event in
          appointmentRow(event)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  /// Builds one appointment row.
  private func appointmentRow(_ event: NativeMonthCalendarEvent) -> some View {
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
  }

  /// Builds the primary appointment title line.
  @ViewBuilder
  private func appointmentTitleView(for event: NativeMonthCalendarEvent) -> some View {
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
  private var selectedEvents: [NativeMonthCalendarEvent] {
    store.eventsInRange(from: selectedStartDate, to: selectedEndDate)
      .sorted { lhs, rhs in
        let lhsIsBirthday = isBirthdayEvent(lhs)
        let rhsIsBirthday = isBirthdayEvent(rhs)

        if lhsIsBirthday != rhsIsBirthday {
          return lhsIsBirthday && !rhsIsBirthday
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

  /// Returns the visible selected events limited by config when scrolling is disabled.
  private var visibleSelectedEvents: [NativeMonthCalendarEvent] {
    if config.appointmentsScrollable {
      return selectedEvents
    }

    return Array(selectedEvents.prefix(config.maxVisibleAppointments))
  }

  /// Handles one pointer-down or drag update on a day.
  private func handlePointerDownOrDrag(on date: Date, translation: CGSize) {
    if !isDragSelecting {
      beginPointerInteraction(on: date)
    }

    let movedEnough = abs(translation.width) > 4 || abs(translation.height) > 4
    if movedEnough {
      didDragBeyondAnchor = true
    }

    guard didDragBeyondAnchor else { return }
    guard config.allowsRangeSelection else { return }

    updateDragSelection(to: date)
  }

  /// Starts one pointer interaction.
  private func beginPointerInteraction(on date: Date) {
    isDragSelecting = true
    didDragBeyondAnchor = false
    dragAnchorDate = date

    Logger.debug("month calendar popup pointer_begin date=\(debugDate(date))")
  }

  /// Updates the current drag selection.
  private func updateDragSelection(to date: Date) {
    guard let dragAnchorDate else { return }

    selectedStartDate = min(dragAnchorDate, date)
    selectedEndDate = max(dragAnchorDate, date)

    Logger.debug(
      "month calendar popup drag_update anchor=\(debugDate(dragAnchorDate)) current=\(debugDate(date)) start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Updates the current drag selection while hovering across days.
  private func handleHover(on date: Date, hovering: Bool) {
    guard hovering else { return }
    guard isDragSelecting else { return }
    guard didDragBeyondAnchor else { return }
    guard config.allowsRangeSelection else { return }

    updateDragSelection(to: date)
  }

  /// Finishes one pointer interaction.
  private func finishPointerInteraction(on date: Date) {
    defer {
      isDragSelecting = false
      dragAnchorDate = nil
      didDragBeyondAnchor = false
    }

    if !didDragBeyondAnchor {
      selectedStartDate = date
      selectedEndDate = date

      Logger.debug("month calendar popup click_select date=\(debugDate(date))")
      return
    }

    Logger.debug(
      "month calendar popup drag_end start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Returns the rendered prefix shown before the title when needed.
  private func appointmentPrefix(for event: NativeMonthCalendarEvent) -> String {
    if event.isAllDay {
      if isBirthdayEvent(event) {
        return ""
      }

      return config.showAllDayLabel ? "All day" : ""
    }

    return formattedEventTime(event.startDate)
  }

  /// Returns whether the given event is a birthday event.
  private func isBirthdayEvent(_ event: NativeMonthCalendarEvent) -> Bool {
    event.id.hasPrefix("birthday-")
  }

  /// Returns the rendered travel-time text when available.
  private func travelTimeText(for event: NativeMonthCalendarEvent) -> String? {
    guard let travelTimeSeconds = event.travelTimeSeconds, travelTimeSeconds > 0 else { return nil }

    let minutes = Int((travelTimeSeconds / 60).rounded())
    guard minutes > 0 else { return nil }

    return "\(minutes) min"
  }

  /// Formats one event time.
  private func formattedEventTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }
}

// MARK: - Styling

extension NativeMonthCalendarPopupView {
  /// Returns the foreground color for one day cell.
  private func dayForeground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedTextColorHex)
    }

    if day.isCurrentMonth {
      return color(config.dayTextColorHex)
    }

    return color(config.outsideMonthTextColorHex)
  }

  /// Returns the background for one day cell.
  private func dayBackground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedBackgroundColorHex)
    }

    if resolvedCalendar.isDateInToday(day.date) {
      return color(config.todayBackgroundColorHex)
    }

    return .clear
  }

  /// Returns whether one day is inside the active selection.
  private func isSelected(_ date: Date) -> Bool {
    let normalizedDate = resolvedCalendar.startOfDay(for: date)
    let start = resolvedCalendar.startOfDay(for: min(selectedStartDate, selectedEndDate))
    let end = resolvedCalendar.startOfDay(for: max(selectedStartDate, selectedEndDate))
    return normalizedDate >= start && normalizedDate <= end
  }

  /// Converts one hex string into SwiftUI color.
  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}

// MARK: - Logging And Helpers

extension NativeMonthCalendarPopupView {
  /// Returns the calendar resolved for month popup rendering.
  private var resolvedCalendar: Calendar {
    var resolved = calendar

    if let firstWeekday = config.firstWeekday {
      resolved.firstWeekday = firstWeekday
    }

    return resolved
  }

  /// Keeps the selection inside the current visible month on first show.
  private func syncSelectionIntoVisibleMonth() {
    if !resolvedCalendar.isDate(selectedStartDate, equalTo: visibleMonth, toGranularity: .month) {
      selectedStartDate = visibleMonth
      selectedEndDate = visibleMonth
    }
  }

  /// Logs the current selection.
  private func logSelection(_ reason: String) {
    Logger.debug(
      "month calendar popup selection reason=\(reason) start=\(debugDate(selectedStartDate)) end=\(debugDate(selectedEndDate))"
    )
  }

  /// Logs the appointments resolved for the current selection.
  private func logResolvedAppointments(_ reason: String) {
    Logger.debug(
      "month calendar popup appointments reason=\(reason) count=\(selectedEvents.count)"
    )
  }

  /// Returns the first day of one month.
  private static func startOfMonth(_ date: Date, calendar: Calendar = Calendar.current) -> Date {
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components) ?? calendar.startOfDay(for: date)
  }

  /// Formats one debug date.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
