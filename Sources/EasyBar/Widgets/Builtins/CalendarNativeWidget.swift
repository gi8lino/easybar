import Foundation

final class CalendarNativeWidget: NativeWidget {

  let rootID = "builtin_calendar"

  private var timer: Timer?

  /// Starts the calendar widget.
  func start() {
    let config = Config.shared.builtinCalendar

    Logger.info(
      "starting native widget id=\(rootID) enabled=\(config.enabled) layout=\(config.layout.rawValue) position=\(config.position.rawValue) days=\(config.days) show_birthdays=\(config.showBirthdays)"
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

  /// Stops the calendar widget.
  func stop() {
    Logger.info("stopping native widget id=\(rootID)")

    timer?.invalidate()
    timer = nil

    if Config.shared.calendarAgentEnabled {
      CalendarAgentClient.shared.stop()
    }
    WidgetStore.shared.apply(root: rootID, nodes: [])
    NativeCalendarStore.shared.clear()
  }

  /// Publishes the current calendar nodes.
  private func publish() {
    let config = Config.shared.builtinCalendar
    let now = Date()

    Logger.debug("publishing native calendar widget layout=\(config.layout.rawValue)")
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(config: config, now: now))
  }

  /// Builds nodes for the selected anchor layout.
  private func makeNodes(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> [WidgetNodeState] {
    switch config.layout {
    case .stack:
      return makeStackNodes(config: config, now: now)
    case .inline:
      return makeInlineNodes(config: config, now: now)
    case .item:
      return makeItemNodes(config: config, now: now)
    }
  }

  /// Builds stack-layout nodes.
  private func makeStackNodes(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> [WidgetNodeState] {
    let placement = config.placement
    let style = config.style

    return [
      rootRowNode(placement: placement, style: style),
      iconNode(placement: placement, style: style),

      // Stack mode keeps both date strings in one nested column.
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
        text: formatDate(now, format: config.topFormat),
        color: config.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_bottom",
        position: placement.position,
        order: 1,
        text: formatDate(now, format: config.bottomFormat),
        color: config.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds inline-layout nodes.
  private func makeInlineNodes(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> [WidgetNodeState] {
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
        text: formatDate(now, format: config.topFormat),
        color: config.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_right",
        position: placement.position,
        order: 2,
        text: formatDate(now, format: config.bottomFormat),
        color: config.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds item-layout nodes.
  private func makeItemNodes(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeItemNode(
        rootID: rootID,
        placement: config.placement,
        style: config.style,
        text: formatDate(now, format: config.itemFormat)
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

  /// Starts the periodic date refresh timer.
  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.publish()
    }
  }

  /// Formats one date string.
  private func formatDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
  }
}
