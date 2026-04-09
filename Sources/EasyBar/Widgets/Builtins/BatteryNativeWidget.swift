import Foundation
import IOKit.ps

/// Native battery widget with configurable colors and hover display modes.
final class BatteryNativeWidget: NativeWidget {
  let rootID = "builtin_battery"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.powerSourceChange.rawValue,
      AppEvent.chargingStateChange.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private var timer: Timer?
  private var isHovered = false

  private struct Snapshot {
    let placement: Config.BuiltinWidgetPlacement
    let style: Config.BuiltinWidgetStyle
    let icon: String
    let text: String
    let colorHex: String?
  }

  /// Starts the widget and listens for battery-related events.
  func start() {
    NativeWidgetEventDriver.start(
      observer: eventObserver,
      appHandler: { [weak self] payload in
        self?.handleAppEvent(payload) ?? false
      },
      widgetHandler: { [weak self] payload in
        self?.handleWidgetEvent(payload)
      }
    )

    timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
      self?.publish()
    }

    publish()
  }
}

// MARK: - Lifecycle

extension BatteryNativeWidget {
  /// Stops the widget and clears its nodes.
  func stop() {
    eventObserver.stop()

    timer?.invalidate()
    timer = nil
    isHovered = false

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the current widget tree.
  private func publish() {
    let snapshot = readBatterySnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot))
  }
}

// MARK: - Node Building

extension BatteryNativeWidget {
  /// Builds the normal inline battery layout.
  fileprivate func makeInlineNodes(
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    text: String,
    icon: String,
    colorHex: String?,
    showInlineLabel: Bool
  ) -> [WidgetNodeState] {
    let config = Config.shared.builtinBattery

    return [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: placement,
        style: style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: placement.position,
        order: 0,
        icon: icon,
        color: colorHex,
        fontSize: config.iconSize
      ),

      inlineLabelNode(
        placement: placement,
        text: text,
        colorHex: colorHex,
        showInlineLabel: showInlineLabel
      ),
    ]
  }

  /// Builds the hover popup layout used for `display_mode = "tooltip"`.
  fileprivate func makeTooltipPopupNodes(
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    icon: String,
    text: String,
    colorHex: String?
  ) -> [WidgetNodeState] {
    let config = Config.shared.builtinBattery
    let popup = config.popup

    let root = BuiltinNativeNodeFactory.makePopupRootNode(
      rootID: rootID,
      placement: placement,
      style: style
    )

    let anchorRow = BuiltinNativeNodeFactory.makePopupAnchorRowNode(
      rootID: rootID,
      anchorID: "\(rootID)_anchor",
      position: placement.position,
      spacing: style.spacing
    )

    let anchorIcon = BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: "\(rootID)_anchor",
      childID: "\(rootID)_icon",
      position: placement.position,
      order: 0,
      icon: icon,
      color: colorHex,
      fontSize: config.iconSize
    )

    let popupSpacer = BuiltinNativeNodeFactory.makeSpacerNode(
      rootID: rootID,
      spacerID: "\(rootID)_popup_spacer",
      parentID: rootID,
      position: placement.position,
      order: 1,
      visible: false,
      paddingX: popup.marginX,
      paddingY: popup.marginY,
      opacity: 1
    )

    let popupColumn = BuiltinNativeNodeFactory.makePopupContentColumnNode(
      rootID: rootID,
      contentID: "\(rootID)_popup",
      position: placement.position,
      order: 0,
      visible: !text.isEmpty,
      paddingX: popup.paddingX,
      paddingY: popup.paddingY,
      spacing: 4,
      backgroundColor: popup.backgroundColorHex,
      borderColor: popup.borderColorHex,
      borderWidth: popup.borderWidth,
      cornerRadius: popup.cornerRadius,
      opacity: 1
    )

    let popupText = BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: "\(rootID)_popup",
      childID: "\(rootID)_popup_text",
      position: placement.position,
      order: 0,
      text: text,
      color: resolvedPopupTextColor(
        popupTextColorHex: popup.textColorHex,
        fallbackColorHex: colorHex,
        styleTextColorHex: style.textColorHex
      ),
      visible: !text.isEmpty
    )

    return [
      root,
      anchorRow,
      anchorIcon,
      popupSpacer,
      popupColumn,
      popupText,
    ]
  }
}

// MARK: - Snapshot And Events

extension BatteryNativeWidget {
  /// Returns the current battery snapshot.
  private func readBatterySnapshot() -> Snapshot {
    let config = Config.shared.builtinBattery
    let placement = config.placement
    let style = config.style

    guard
      let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else {
      return unavailableSnapshot(
        placement: placement,
        style: style,
        config: config
      )
    }

    for source in list {
      guard
        let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
          as? [String: Any],
        (description[kIOPSIsPresentKey as String] as? Bool) == true
      else {
        continue
      }

      let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
      let max = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
      let percentage = max > 0 ? Int((Double(current) / Double(max)) * 100.0) : 0

      let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
      let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
      let charging = powerSourceState == kIOPSACPowerValue || isCharging

      let text = "\(percentage)%"

      return Snapshot(
        placement: placement,
        style: style,
        icon: resolvedBatteryIcon(for: percentage, charging: charging),
        text: text,
        colorHex: resolvedBatteryColor(
          for: percentage,
          mode: config.colorMode,
          fixedColorHex: config.fixedColorHex ?? config.style.textColorHex,
          colors: config.colors
        )
      )
    }

    return unavailableSnapshot(
      placement: placement,
      style: style,
      config: config
    )
  }

  private func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
    guard let event = payload.appEvent else {
      return false
    }

    guard event == .powerSourceChange || event == .chargingStateChange || event == .systemWoke
    else {
      return false
    }

    publish()
    return true
  }

  private func handleWidgetEvent(_ payload: EasyBarEventPayload) {
    guard let event = payload.widgetEvent else { return }
    guard payload.widgetID == rootID else { return }

    switch event {
    case .mouseEntered:
      guard !isHovered else { return }
      isHovered = true
      publishIfHoverAffectsLayout()

    case .mouseExited:
      guard isHovered else { return }
      isHovered = false
      publishIfHoverAffectsLayout()

    default:
      break
    }
  }

  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = Config.shared.builtinBattery

    guard config.displayMode != .tooltip else {
      return makeTooltipPopupNodes(
        placement: snapshot.placement,
        style: snapshot.style,
        icon: snapshot.icon,
        text: snapshot.text,
        colorHex: snapshot.colorHex
      )
    }

    return makeInlineNodes(
      placement: snapshot.placement,
      style: snapshot.style,
      text: snapshot.text,
      icon: snapshot.icon,
      colorHex: snapshot.colorHex,
      showInlineLabel: shouldShowInlineLabel(
        mode: config.displayMode,
        text: snapshot.text
      )
    )
  }

  private func unavailableSnapshot(
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    config: Config.BatteryBuiltinConfig
  ) -> Snapshot {
    Snapshot(
      placement: placement,
      style: style,
      icon: style.icon,
      text: config.unavailableText,
      colorHex: resolvedUnavailableColor(config: config)
    )
  }
}

// MARK: - Display Decisions

extension BatteryNativeWidget {
  /// Returns true when the inline label should be shown.
  fileprivate func shouldShowInlineLabel(
    mode: Config.BuiltinBatteryDisplayMode,
    text: String
  ) -> Bool {
    guard !text.isEmpty else { return false }

    switch mode {
    case .none:
      return false
    case .tooltip:
      return false
    case .expand:
      return isHovered
    case .always:
      return true
    }
  }

  /// Hover only changes the rendered node tree for inline hover-only mode.
  fileprivate func publishIfHoverAffectsLayout() {
    guard Config.shared.builtinBattery.displayMode == .expand else { return }
    publish()
  }

  /// Keeps the row width stable while toggling the label visually on hover.
  fileprivate func inlineLabelNode(
    placement: Config.BuiltinWidgetPlacement,
    text: String,
    colorHex: String?,
    showInlineLabel: Bool
  ) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_label",
      position: placement.position,
      order: 1,
      text: showInlineLabel ? text : "",
      color: colorHex,
      visible: showInlineLabel && !text.isEmpty,
      spacing: 4
    )
  }

  /// Resolves the popup text color.
  fileprivate func resolvedPopupTextColor(
    popupTextColorHex: String?,
    fallbackColorHex: String?,
    styleTextColorHex: String?
  ) -> String? {
    popupTextColorHex ?? fallbackColorHex ?? styleTextColorHex
  }

  /// Resolves the icon for the current battery state.
  fileprivate func resolvedBatteryIcon(for percentage: Int, charging: Bool) -> String {
    if charging {
      switch percentage {
      case 100: return "󰂅"
      case 90...99: return "󰂋"
      case 80...89: return "󰂊"
      case 70...79: return "󰢞"
      case 60...69: return "󰂉"
      case 50...59: return "󰢝"
      case 40...49: return "󰂈"
      case 30...39: return "󰂇"
      case 20...29: return "󰂆"
      case 10...19: return "󰢜"
      default: return "󰂃"
      }
    }

    switch percentage {
    case 100: return "󰁹"
    case 90...99: return "󰂂"
    case 80...89: return "󰂁"
    case 70...79: return "󰂀"
    case 60...69: return "󰁿"
    case 50...59: return "󰁾"
    case 40...49: return "󰁽"
    case 30...39: return "󰁼"
    case 20...29: return "󰁻"
    case 10...19: return "󰁺"
    default: return "󰂃"
    }
  }

  /// Resolves the displayed battery color.
  fileprivate func resolvedBatteryColor(
    for percentage: Int,
    mode: Config.BuiltinBatteryColorMode,
    fixedColorHex: String?,
    colors: Config.BuiltinBatteryColors
  ) -> String? {
    if mode == .fixed {
      return fixedColorHex
    }

    switch percentage {
    case 70...100:
      return colors.highColorHex
    case 50...69:
      return colors.mediumColorHex
    case 30...49:
      return colors.lowColorHex
    default:
      return colors.criticalColorHex
    }
  }

  /// Resolves the color used when the battery is unavailable.
  fileprivate func resolvedUnavailableColor(config: Config.BatteryBuiltinConfig) -> String? {
    switch config.colorMode {
    case .dynamic:
      return config.style.textColorHex
    case .fixed:
      return config.fixedColorHex ?? config.style.textColorHex
    }
  }
}
