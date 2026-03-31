import Foundation

/// Native calendar anchor widget.
///
/// This is the single built-in calendar widget. The configured popup mode
/// decides whether it shows no popup, the upcoming popup, or the month popup.
final class CalendarNativeWidget: NativeWidget {

  let rootID = "builtin_calendar"

  private var timer: Timer?

  private struct Snapshot {
    let config: Config.CalendarBuiltinConfig
    let now: Date
  }

  /// Starts the calendar widget.
  func start() {
    let snapshot = currentSnapshot()
    let upcoming = snapshot.config.upcoming

    Logger.info(
      "starting native widget id=\(rootID) enabled=\(snapshot.config.enabled) layout=\(snapshot.config.anchor.layout.rawValue) position=\(snapshot.config.position.rawValue) popup_mode=\(snapshot.config.popupMode.rawValue) days=\(upcoming.events.days) show_birthdays=\(upcoming.birthdays.show)"
    )

    guard Config.shared.calendarAgentEnabled else {
      Logger.info("calendar agent disabled in config")
      startTimer()
      publish()
      return
    }

    startCalendarAgent(for: snapshot)
    startTimer()
    publish()
  }

  /// Stops the calendar widget.
  func stop() {
    Logger.info("stopping native widget id=\(rootID)")

    timer?.invalidate()
    timer = nil

    if Config.shared.calendarAgentEnabled {
      stopCalendarAgent()
    }

    WidgetStore.shared.apply(root: rootID, nodes: [])
    NativeUpcomingCalendarStore.shared.clear()
    NativeMonthCalendarStore.shared.clear()
  }

  /// Publishes the current calendar nodes.
  private func publish() {
    let snapshot = currentSnapshot()

    Logger.debug(
      "publishing native calendar widget layout=\(snapshot.config.anchor.layout.rawValue) popup_mode=\(snapshot.config.popupMode.rawValue)"
    )
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot))
  }
}

// MARK: - Snapshot

extension CalendarNativeWidget {
  /// Returns the current calendar render snapshot.
  private func currentSnapshot() -> Snapshot {
    Snapshot(
      config: Config.shared.builtinCalendar,
      now: Date()
    )
  }

  /// Returns the fetch range required by the upcoming-calendar popup.
  static func requestedDateRange(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> DateInterval {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: now)
    let dayCount = max(1, config.upcoming.events.days)
    let end =
      calendar.date(byAdding: .day, value: dayCount, to: start)
      ?? now.addingTimeInterval(TimeInterval(dayCount * 86_400))

    return DateInterval(start: start, end: end)
  }
}

// MARK: - Agent Lifecycle

extension CalendarNativeWidget {
  /// Starts the calendar agent required by the active popup mode.
  private func startCalendarAgent(for snapshot: Snapshot) {
    switch snapshot.config.popupMode {
    case .none:
      break

    case .upcoming:
      UpcomingCalendarAgentClient.shared.start()
    case .month:
      _ = NativeMonthCalendarStore.shared.prepareMonthSubscriptionRange(for: snapshot.now)
      MonthCalendarAgentClient.shared.start()
    }
  }

  /// Stops the calendar agent required by the active popup mode.
  private func stopCalendarAgent() {
    switch Config.shared.builtinCalendar.popupMode {
    case .none:
      break

    case .upcoming:
      UpcomingCalendarAgentClient.shared.stop()
    case .month:
      MonthCalendarAgentClient.shared.stop()
    }
  }
}

// MARK: - Node Building

extension CalendarNativeWidget {
  /// Builds nodes for the selected anchor layout.
  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    switch snapshot.config.anchor.layout {
    case .stack:
      return makeStackNodes(snapshot: snapshot)
    case .inline:
      return makeInlineNodes(snapshot: snapshot)
    case .item:
      return makeItemNodes(snapshot: snapshot)
    }
  }

  /// Builds stack-layout nodes.
  private func makeStackNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
    let anchor = config.anchor
    let placement = config.placement
    let style = config.style

    return [
      rootRowNode(placement: placement, style: style),
      iconNode(placement: placement, style: style),

      WidgetNodeState(
        id: "\(rootID)_text_column",
        root: rootID,
        kind: .column,
        parent: rootID,
        position: placement.position,
        order: 1,
        icon: "",
        text: "",
        color: nil,
        iconColor: nil,
        labelColor: nil,
        visible: true,
        role: nil,
        receivesMouseHover: nil,
        receivesMouseClick: nil,
        receivesMouseScroll: nil,
        imagePath: nil,
        imageSize: nil,
        imageCornerRadius: nil,
        fontSize: nil,
        iconFontSize: nil,
        labelFontSize: nil,
        value: nil,
        min: nil,
        max: nil,
        step: nil,
        values: nil,
        lineWidth: nil,
        paddingX: 0,
        paddingY: 0,
        paddingLeft: nil,
        paddingRight: nil,
        paddingTop: nil,
        paddingBottom: nil,
        spacing: anchor.lineSpacing,
        backgroundColor: nil,
        borderColor: nil,
        borderWidth: nil,
        cornerRadius: nil,
        opacity: 1,
        width: nil,
        height: nil,
        yOffset: nil
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_top",
        position: placement.position,
        order: 0,
        text: formatDate(snapshot.now, format: anchor.topFormat),
        color: anchor.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_bottom",
        position: placement.position,
        order: 1,
        text: formatDate(snapshot.now, format: anchor.bottomFormat),
        color: anchor.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds inline-layout nodes.
  private func makeInlineNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
    let anchor = config.anchor
    let placement = config.placement
    let style = config.style

    return [
      rootRowNode(placement: placement, style: style),
      iconNode(placement: placement, style: style),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_left",
        position: placement.position,
        order: 1,
        text: formatDate(snapshot.now, format: anchor.topFormat),
        color: anchor.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_right",
        position: placement.position,
        order: 2,
        text: formatDate(snapshot.now, format: anchor.bottomFormat),
        color: anchor.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds item-layout nodes.
  private func makeItemNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeItemNode(
        rootID: rootID,
        placement: snapshot.config.placement,
        style: snapshot.config.style,
        text: formatDate(snapshot.now, format: snapshot.config.anchor.itemFormat)
      )
    ]
  }

  /// Builds the common root row.
  private func rootRowNode(
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeRowContainerNode(
      rootID: rootID,
      placement: placement,
      style: style
    )
  }

  /// Builds the common leading icon.
  private func iconNode(
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_icon",
      position: placement.position,
      order: 0,
      icon: style.icon,
      color: style.textColorHex
    )
  }
}

// MARK: - Timer And Formatting

extension CalendarNativeWidget {
  /// Starts the periodic date refresh timer.
  fileprivate func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.publish()
    }
  }

  /// Formats one date string.
  fileprivate func formatDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
  }
}
