import Foundation

/// Native month-calendar widget with a popup calendar.
final class MonthCalendarNativeWidget: NativeWidget {

  let rootID = "builtin_month_calendar"

  private var timer: Timer?

  private struct Snapshot {
    let config: Config.MonthCalendarBuiltinConfig
    let now: Date
  }

  /// Starts the month-calendar widget.
  func start() {
    guard Config.shared.calendarAgentEnabled else {
      startTimer()
      publish()
      return
    }

    let snapshot = currentSnapshot()
    _ = NativeMonthCalendarStore.shared.prepareMonthSubscriptionRange(for: snapshot.now)

    MonthCalendarAgentClient.shared.start()
    startTimer()
    publish()
  }

  /// Stops the month-calendar widget.
  func stop() {
    timer?.invalidate()
    timer = nil

    if Config.shared.calendarAgentEnabled {
      MonthCalendarAgentClient.shared.stop()
    }

    WidgetStore.shared.apply(root: rootID, nodes: [])
    NativeMonthCalendarStore.shared.clear()
  }

  /// Publishes the current widget tree.
  private func publish() {
    let snapshot = currentSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot))
  }
}

// MARK: - Snapshot

extension MonthCalendarNativeWidget {
  /// Returns the current render snapshot.
  private func currentSnapshot() -> Snapshot {
    Snapshot(
      config: Config.shared.builtinMonthCalendar,
      now: Date()
    )
  }

  /// Returns the fetch range required by the month-calendar widget.
  ///
  /// This loads the previous, current, and next visible month around `referenceDate`.
  static func requestedDateRange(
    config: Config.MonthCalendarBuiltinConfig,
    referenceDate: Date
  ) -> DateInterval {
    let calendar = Calendar.current

    let currentMonthStart =
      calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))
      ?? calendar.startOfDay(for: referenceDate)

    let start =
      calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
      ?? currentMonthStart

    let end =
      calendar.date(byAdding: .month, value: 2, to: currentMonthStart)
      ?? referenceDate.addingTimeInterval(90 * 86_400)

    return DateInterval(start: start, end: end)
  }
}

// MARK: - Node Building

extension MonthCalendarNativeWidget {
  /// Builds the rendered widget nodes.
  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
    let placement = config.placement
    let style = config.style

    var nodes: [WidgetNodeState] = [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: placement,
        style: style
      )
    ]

    if !style.icon.isEmpty {
      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: rootID,
          childID: "\(rootID)_icon",
          position: placement.position,
          order: 0,
          icon: style.icon,
          color: style.textColorHex
        )
      )
    }

    if config.showDateText {
      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: rootID,
          childID: "\(rootID)_label",
          position: placement.position,
          order: 1,
          text: anchorText(for: snapshot.now, config: config),
          color: config.textColorHex ?? style.textColorHex
        )
      )
    }

    return nodes
  }

  /// Returns the rendered anchor text.
  private func anchorText(
    for date: Date,
    config: Config.MonthCalendarBuiltinConfig
  ) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = config.dateFormat
    return formatter.string(from: date)
  }
}

// MARK: - Timer

extension MonthCalendarNativeWidget {
  /// Starts the periodic refresh timer.
  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.publish()
    }
  }
}
