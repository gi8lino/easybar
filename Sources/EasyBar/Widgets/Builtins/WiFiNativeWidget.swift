import EasyBarShared
import Foundation

final class WiFiNativeWidget: NativeWidget {
  let rootID = "builtin_wifi"

  private let eventObserver = EasyBarEventObserver()
  private var storeToken: NSObjectProtocol?
  private var isHovered = false

  func start() {
    let config = Config.shared.builtinWiFi
    Logger.info(
      "starting native widget id=\(rootID) enabled=\(config.enabled) position=\(config.position.rawValue)"
    )

    startEventObserver()
    startStoreObserver()

    guard Config.shared.networkAgentEnabled else {
      Logger.info("network agent disabled in config")
      publish()
      return
    }

    NetworkAgentClient.shared.start()

    publish()
  }

  func stop() {
    Logger.info("stopping native widget id=\(rootID)")

    eventObserver.stop()
    if let storeToken {
      NotificationCenter.default.removeObserver(storeToken)
      self.storeToken = nil
    }
    isHovered = false

    if Config.shared.networkAgentEnabled {
      NetworkAgentClient.shared.stop()
    }

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private func publish() {
    let config = Config.shared.builtinWiFi
    let snapshot = NativeWiFiStore.shared.snapshot
    WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot, config: config))
  }

  /// Starts widget mouse event observation.
  private func startEventObserver() {
    eventObserver.start { [weak self] payload in
      self?.handleEvent(payload)
    }
  }

  /// Starts store change observation.
  private func startStoreObserver() {
    storeToken = NotificationCenter.default.addObserver(
      forName: NativeWiFiStore.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.publish()
    }
  }

  /// Handles widget hover events.
  private func handleEvent(_ payload: EasyBarEventPayload) {
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
  private func makeNodes(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> [WidgetNodeState] {
    let labelText = resolvedLabelText(snapshot: snapshot, config: config)
    return [
      makeRootNode(config: config),
      makeIconNode(snapshot: snapshot, config: config),
      makeLabelNode(text: labelText, config: config),
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
  private func makeIconNode(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_icon",
      position: config.placement.position,
      order: 13,
      icon: resolvedSignalIcon(snapshot: snapshot),
      color: resolvedSignalColor(snapshot: snapshot, config: config),
      fontSize: 16
    )
  }

  /// Builds the optional SSID label node.
  private func makeLabelNode(text: String, config: Config.WiFiBuiltinConfig) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeChildItemNode(
      rootID: rootID,
      parentID: rootID,
      childID: "\(rootID)_label",
      position: config.placement.position,
      order: 13,
      text: text,
      color: config.textColorHex,
      visible: config.showSSIDOnHover && isHovered && !text.isEmpty,
      spacing: 4
    )
  }

  private func resolvedSignalBars(snapshot: NetworkAgentSnapshot?) -> Int {
    guard let snapshot, snapshot.accessGranted else { return 0 }
    return max(0, min(4, snapshot.signalBars))
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
