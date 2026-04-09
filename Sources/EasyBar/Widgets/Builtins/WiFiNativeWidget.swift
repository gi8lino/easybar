import EasyBarShared
import Foundation

final class WiFiNativeWidget: NativeWidget {
  let rootID = "builtin_wifi"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.networkChange.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private var isHovered = false
  private var startedNetworkAgent = false

  private struct Snapshot {
    let config: Config.WiFiBuiltinConfig
    let network: NetworkAgentSnapshot?
    let labelText: String
    let iconText: String
    let iconColorHex: String
    let labelVisible: Bool
  }

  func start() {
    let config = Config.shared.builtinWiFi
    easybarLog.info(
      "starting native widget id=\(rootID) enabled=\(config.enabled) position=\(config.position.rawValue)"
    )

    NativeWidgetEventDriver.start(
      observer: eventObserver,
      appHandler: { [weak self] payload in
        self?.handleAppEvent(payload) ?? false
      },
      widgetHandler: { [weak self] payload in
        self?.handleWidgetEvent(payload)
      }
    )

    startedNetworkAgent = config.enabled && Config.shared.networkAgentEnabled

    guard startedNetworkAgent else {
      easybarLog.info("network agent disabled in config")
      publish()
      return
    }

    NetworkAgentClient.shared.start()
    publish()
  }

  func stop() {
    easybarLog.info("stopping native widget id=\(rootID)")

    eventObserver.stop()
    isHovered = false

    if startedNetworkAgent {
      NetworkAgentClient.shared.stop()
    }

    startedNetworkAgent = false
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private func publish() {
    let snapshot = makeSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot))
  }

  /// Returns the current render snapshot.
  private func makeSnapshot() -> Snapshot {
    let config = Config.shared.builtinWiFi
    let network = NativeWiFiStore.shared.snapshot
    let labelText = resolvedLabelText(snapshot: network, config: config)

    return Snapshot(
      config: config,
      network: network,
      labelText: labelText,
      iconText: resolvedSignalIcon(snapshot: network),
      iconColorHex: resolvedSignalColor(snapshot: network, config: config),
      labelVisible: config.showSSIDOnHover && isHovered && !labelText.isEmpty
    )
  }

  /// Handles app-wide events relevant to the Wi-Fi widget.
  private func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
    guard let event = payload.appEvent else { return false }

    switch event {
    case .networkChange, .systemWoke:
      publish()
      return true
    default:
      return false
    }
  }

  /// Handles widget-local hover events.
  private func handleWidgetEvent(_ payload: EasyBarEventPayload) {
    guard payload.widgetID == rootID else { return }
    guard let event = payload.widgetEvent else { return }

    switch event {
    case .mouseEntered:
      guard !isHovered else { return }
      isHovered = true
      publish()

    case .mouseExited:
      guard isHovered else { return }
      isHovered = false
      publish()

    default:
      return
    }
  }

  /// Builds the Wi-Fi widget nodes for the current snapshot.
  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      makeRootNode(config: snapshot.config),
      makeIconNode(snapshot: snapshot),
      makeLabelNode(snapshot: snapshot),
    ]
  }

  /// Builds the root row node.
  private func makeRootNode(config: Config.WiFiBuiltinConfig) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeRowContainerNode(
      rootID: rootID,
      placement: config.placement,
      style: config.style
    )
  }

  /// Builds the signal icon node.
  private func makeIconNode(snapshot: Snapshot) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_icon",
      position: snapshot.config.placement.position,
      order: 0,
      icon: snapshot.iconText,
      color: snapshot.iconColorHex,
      fontSize: 16
    )
  }

  /// Builds the optional SSID label node.
  private func makeLabelNode(snapshot: Snapshot) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_label",
      position: snapshot.config.placement.position,
      order: 1,
      text: snapshot.labelText,
      color: snapshot.config.textColorHex,
      visible: snapshot.labelVisible,
      spacing: 4
    )
  }

  private func resolvedSignalBars(snapshot: NetworkAgentSnapshot?) -> Int {
    guard
      let snapshot,
      snapshot.accessGranted,
      snapshot.ssid != nil,
      let rssi = snapshot.rssi
    else {
      return 0
    }

    switch rssi {
    case let value where value >= -58:
      return 4
    case let value where value >= -67:
      return 3
    case let value where value >= -75:
      return 2
    case let value where value >= -83:
      return 1
    default:
      return 0
    }
  }

  private func resolvedSignalIcon(snapshot: NetworkAgentSnapshot?) -> String {
    let bars = resolvedSignalBars(snapshot: snapshot)

    switch bars {
    case 4:
      return "󰤨 "
    case 3:
      return "󰤥 "
    case 2:
      return "󰤢 "
    case 1:
      return "󰤟 "
    default:
      return "󰤮 "
    }
  }

  private func resolvedSignalColor(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> String {
    guard let snapshot, snapshot.accessGranted, snapshot.ssid != nil else {
      return config.inactiveColorHex
    }

    return config.activeColorHex
  }

  private func resolvedLabelText(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> String {
    guard let snapshot else { return config.disconnectedText }

    guard snapshot.accessGranted else {
      return config.deniedText
    }

    return snapshot.ssid ?? config.disconnectedText
  }
}
