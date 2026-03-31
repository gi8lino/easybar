import Foundation

final class UpcomingCalendarNativeWidget: NativeWidget {

  let rootID = "builtin_calendar"

  private var timer: Timer?

  private struct Snapshot {
    let config: Config.CalendarBuiltinConfig
    let now: Date
  }

  /// Starts the upcoming-calendar widget.
  func start() {
    let snapshot = currentSnapshot()

    Logger.info(
      "starting native widget id=\(rootID) enabled=\(snapshot.config.enabled) layout=\(snapshot.config.layout.rawValue) position=\(snapshot.config.position.rawValue) days=\(snapshot.config.days) show_birthdays=\(snapshot.config.showBirthdays)"
    )

    guard Config.shared.calendarAgentEnabled else {
      Logger.info("calendar agent disabled in config")
      startTimer()
      publish()
      return
    }

    CalendarAgentClient.shared.start()
    startTimer()
    publish()
  }

  /// Stops the upcoming-calendar widget.
  func stop() {
    Logger.info("stopping native widget id=\(rootID)")

    timer?.invalidate()
    timer = nil

    if Config.shared.calendarAgentEnabled {
      CalendarAgentClient.shared.stop()
    }

    WidgetStore.shared.apply(root: rootID, nodes: [])
    NativeUpcomingCalendarStore.shared.clear()
  }

  /// Publishes the current calendar nodes.
  private func publish() {
    let snapshot = currentSnapshot()

    Logger.debug(
      "publishing native upcoming calendar widget layout=\(snapshot.config.layout.rawValue)")
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot))
  }
}

// MARK: - Snapshot

extension UpcomingCalendarNativeWidget {
  /// Returns the current upcoming-calendar render snapshot.
  private func currentSnapshot() -> Snapshot {
    Snapshot(
      config: Config.shared.builtinCalendar,
      now: Date()
    )
  }

  /// Returns the fetch range required by the upcoming-calendar widget.
  static func requestedDateRange(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> DateInterval {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: now)
    let dayCount = max(1, config.days)
    let end =
      calendar.date(byAdding: .day, value: dayCount, to: start)
      ?? now.addingTimeInterval(TimeInterval(dayCount * 86_400))

    return DateInterval(start: start, end: end)
  }
}

// MARK: - Node Building

extension UpcomingCalendarNativeWidget {
  /// Builds nodes for the selected anchor layout.
  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    switch snapshot.config.layout {
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
        spacing: config.lineSpacing,
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
        text: formatDate(snapshot.now, format: config.topFormat),
        color: config.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_bottom",
        position: placement.position,
        order: 1,
        text: formatDate(snapshot.now, format: config.bottomFormat),
        color: config.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds inline-layout nodes.
  private func makeInlineNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
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
        text: formatDate(snapshot.now, format: config.topFormat),
        color: config.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_right",
        position: placement.position,
        order: 2,
        text: formatDate(snapshot.now, format: config.bottomFormat),
        color: config.bottomTextColorHex ?? style.textColorHex
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
        text: formatDate(snapshot.now, format: snapshot.config.itemFormat)
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

extension UpcomingCalendarNativeWidget {

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
