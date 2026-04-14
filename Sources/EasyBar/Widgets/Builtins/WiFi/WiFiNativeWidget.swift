import EasyBarShared
import Foundation

/// Native Wi-Fi widget backed by the network agent snapshot store.
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
  private lazy var renderer = WiFiRenderer(rootID: rootID)

  struct Snapshot {
    let config: Config.WiFiBuiltinConfig
    let network: NetworkAgentSnapshot?
    let labelText: String
    let signalLevel: Int
    let visualState: WiFiPresentation.VisualState
    let activeColorHex: String
    let inactiveColorHex: String
    let labelVisible: Bool
    let popupVisible: Bool
  }

  // MARK: - Lifecycle

  /// Starts the Wi-Fi widget.
  func start() {
    let config = Config.shared.builtinWiFi

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
      publish()
      return
    }

    NetworkAgentClient.shared.start()
    publish()
  }

  /// Stops the Wi-Fi widget.
  func stop() {
    eventObserver.stop()
    isHovered = false

    if startedNetworkAgent {
      NetworkAgentClient.shared.stop()
    }

    startedNetworkAgent = false
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  // MARK: - Publish

  /// Publishes the current Wi-Fi nodes.
  private func publish() {
    let snapshot = makeSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: renderer.makeNodes(snapshot: snapshot))
  }

  /// Returns the current render snapshot.
  private func makeSnapshot() -> Snapshot {
    let config = Config.shared.builtinWiFi
    let network = NativeWiFiStore.shared.snapshot
    let presentation = WiFiPresentation(snapshot: network, config: config)

    return Snapshot(
      config: config,
      network: network,
      labelText: presentation.labelText,
      signalLevel: presentation.signalLevel,
      visualState: presentation.visualState,
      activeColorHex: presentation.activeColorHex,
      inactiveColorHex: presentation.inactiveColorHex,
      labelVisible: shouldShowInlineLabel(config: config, text: presentation.labelText),
      popupVisible: shouldShowPopupLabel(config: config, text: presentation.labelText)
    )
  }
}

// MARK: - Events

extension WiFiNativeWidget {

  /// Handles app-wide Wi-Fi-related events.
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

  /// Returns whether the Wi-Fi label should be visible inline.
  private func shouldShowInlineLabel(
    config: Config.WiFiBuiltinConfig,
    text: String
  ) -> Bool {
    guard !text.isEmpty else { return false }

    switch config.displayMode {
    case .none, .tooltip:
      return false
    case .expand:
      return isHovered
    case .always:
      return true
    }
  }

  /// Returns whether the Wi-Fi label should be shown in a popup.
  private func shouldShowPopupLabel(
    config: Config.WiFiBuiltinConfig,
    text: String
  ) -> Bool {
    config.displayMode == .tooltip && !text.isEmpty
  }
}
