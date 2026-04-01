import SwiftUI

// MARK: - Top-Level Layout

extension NativeMonthCalendarPopupView {
  /// Builds the configured popup layout.
  @ViewBuilder
  var popupLayoutView: some View {
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
  var minimumPopupWidth: CGFloat {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 560
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return 320
    }
  }

  /// Returns the fixed width used by the calendar pane.
  var calendarContainerWidth: CGFloat {
    260
  }

  /// Returns the fixed height used by the calendar pane in vertical layouts.
  var verticalCalendarHeight: CGFloat {
    250
  }

  /// Builds the calendar container.
  var calendarContainerView: some View {
    VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
      headerView
      weekdayHeaderView
      monthGridView
    }
    .frame(
      minWidth: calendarContainerWidth,
      maxWidth: calendarContainerWidth,
      minHeight: isVerticalLayout ? verticalCalendarHeight : nil,
      maxHeight: isVerticalLayout ? verticalCalendarHeight : nil,
      alignment: .topLeading
    )
  }

  /// Builds the agenda container.
  var agendaContainerView: some View {
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
  var isHorizontalLayout: Bool {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return true
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return false
    }
  }

  /// Returns whether the current popup layout is vertical.
  var isVerticalLayout: Bool {
    !isHorizontalLayout
  }

  /// Returns the minimum height of the appointments area.
  var appointmentsMinHeight: CGFloat {
    CGFloat(min(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }

  /// Returns the maximum height of the appointments area.
  var appointmentsMaxHeight: CGFloat {
    CGFloat(max(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }
}

// MARK: - Header

extension NativeMonthCalendarPopupView {
  /// Builds the popup month header.
  var headerView: some View {
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

      headerButtonsContainerView

      Button(action: showNextMonth) {
        Text("›")
          .foregroundStyle(color(config.headerTextColorHex))
      }
      .buttonStyle(.plain)
    }
  }

  /// Builds the grouped header action buttons.
  var headerButtonsContainerView: some View {
    HStack(spacing: 8) {
      Button(action: showToday) {
        Text(config.todayButtonTitle)
          .foregroundStyle(color(config.headerTextColorHex))
      }
      .buttonStyle(.plain)

      Button(action: openComposer) {
        Image(systemName: "plus")
          .foregroundStyle(color(config.headerTextColorHex))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color(config.todayBackgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          color(config.borderColorHex),
          lineWidth: max(CGFloat(config.borderWidth), 1)
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: 8)
    )
  }

  /// Shows the current month and selects today.
  func showToday() {
    let today = resolvedCalendar.startOfDay(for: Date())
    visibleMonth = Self.startOfMonth(today, calendar: resolvedCalendar)
    selectedStartDate = today
    selectedEndDate = today

    Logger.debug("month calendar popup show_today visible_month=\(debugDate(visibleMonth))")
  }

  /// Shows the previous visible month.
  func showPreviousMonth() {
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
  func showNextMonth() {
    guard let newMonth = resolvedCalendar.date(byAdding: .month, value: 1, to: visibleMonth) else {
      return
    }

    visibleMonth = Self.startOfMonth(newMonth, calendar: resolvedCalendar)
    selectedStartDate = visibleMonth
    selectedEndDate = visibleMonth

    Logger.debug("month calendar popup show_next_month visible_month=\(debugDate(visibleMonth))")
  }

  /// Returns the visible month title.
  var monthTitle: String {
    let formatter = DateFormatter()
    formatter.calendar = resolvedCalendar
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: visibleMonth)
  }
}

// MARK: - Weekday Header

extension NativeMonthCalendarPopupView {
  /// Builds the weekday header row.
  var weekdayHeaderView: some View {
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
  var weekdaySymbols: [String] {
    reorderMondayFirstWeekdaySymbolsToCalendarOrder(config.resolvedWeekdaySymbols)
  }

  /// Reorders Monday-first weekday symbols into the current calendar order.
  func reorderMondayFirstWeekdaySymbolsToCalendarOrder(_ symbols: [String]) -> [String] {
    guard symbols.count == 7 else { return symbols }

    let mondayFirstIndex = mondayFirstWeekdayIndex(for: resolvedCalendar.firstWeekday)
    return Array(symbols[mondayFirstIndex...]) + Array(symbols[..<mondayFirstIndex])
  }

  /// Converts `Calendar.firstWeekday` into a Monday-first zero-based index.
  func mondayFirstWeekdayIndex(for firstWeekday: Int) -> Int {
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
  var monthGridView: some View {
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
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: MonthCalendarGridFramePreferenceKey.self,
          value: proxy.frame(in: .named("month-calendar-grid"))
        )
      }
    )
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          handleGridDragChanged(value)
        }
        .onEnded { value in
          handleGridDragEnded(value)
        }
    )
    .onPreferenceChange(MonthCalendarGridFramePreferenceKey.self) { frame in
      monthGridFrame = frame
    }
    .onPreferenceChange(MonthCalendarDayFramePreferenceKey.self) { frames in
      dayCellFrames = frames
    }
    .coordinateSpace(name: "month-calendar-grid")
  }

  /// Builds one interactive day cell.
  func dayCellView(_ day: DayCell) -> some View {
    let normalizedDate = resolvedCalendar.startOfDay(for: day.date)

    return VStack(spacing: 2) {
      Text("\(resolvedCalendar.component(.day, from: day.date))")
        .frame(width: 28, height: 22)
        .background(dayBackground(day))
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              dayBorderColor(day),
              lineWidth: dayBorderWidth(day)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))

      dayIndicatorBar(for: day.date)
    }
    .frame(maxWidth: .infinity, minHeight: 30)
    .foregroundStyle(dayForeground(day))
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: MonthCalendarDayFramePreferenceKey.self,
          value: [normalizedDate: proxy.frame(in: .named("month-calendar-grid"))]
        )
      }
    )
  }

  /// Builds the appointment-indicator bar for one day.
  @ViewBuilder
  func dayIndicatorBar(for date: Date) -> some View {
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
  func dayIndicatorSegments(for date: Date) -> [DayIndicatorSegment] {
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
  func normalizedIndicatorColorHex(for event: NativeMonthCalendarEvent) -> String {
    if let hex = event.calendarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
      !hex.isEmpty
    {
      return hex
    }

    return config.indicatorColorHex
  }

  /// Returns the computed week rows for the visible month.
  var weekRows: [WeekRow] {
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

// MARK: - Styling

extension NativeMonthCalendarPopupView {
  /// Returns the foreground color for one day cell.
  func dayForeground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedTextColorHex)
    }

    if day.isCurrentMonth {
      return color(config.dayTextColorHex)
    }

    return color(config.outsideMonthTextColorHex)
  }

  /// Returns the background for one day cell.
  func dayBackground(_ day: DayCell) -> Color {
    if isSelected(day.date) {
      return color(config.selectedBackgroundColorHex)
    }

    if resolvedCalendar.isDateInToday(day.date) {
      return color(config.todayBackgroundColorHex)
    }

    return .clear
  }

  /// Returns the border color for one day cell.
  func dayBorderColor(_ day: DayCell) -> Color {
    if resolvedCalendar.isDateInToday(day.date) {
      return color(config.todayBorderColorHex)
    }

    return .clear
  }

  /// Returns the border width for one day cell.
  func dayBorderWidth(_ day: DayCell) -> CGFloat {
    if resolvedCalendar.isDateInToday(day.date) {
      return CGFloat(max(config.todayBorderWidth, 0))
    }

    return 0
  }

  /// Returns whether one day is inside the active selection.
  func isSelected(_ date: Date) -> Bool {
    let normalizedDate = resolvedCalendar.startOfDay(for: date)
    let start = resolvedCalendar.startOfDay(for: min(selectedStartDate, selectedEndDate))
    let end = resolvedCalendar.startOfDay(for: max(selectedStartDate, selectedEndDate))
    return normalizedDate >= start && normalizedDate <= end
  }

  /// Converts one hex string into SwiftUI color.
  func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}
