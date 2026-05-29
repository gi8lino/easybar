import EasyBarShared
import Foundation

/// Native Wi-Fi widget backed by the network agent snapshot store.
@MainActor
final class WiFiNativeWidget: NativeWidget {

  let rootID = "builtin_wifi"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.networkChange.rawValue
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private var isHovered = false
  private var started = false
  private var startedNetworkAgent = false
  private lazy var renderer = WiFiRenderer(rootID: rootID)

  struct Snapshot {
    let config: Config.WiFiBuiltinConfig
    let network: NetworkAgentSnapshot?
    let content: WiFiPresentation.Content
    let signalLevel: Int
    let visualState: WiFiPresentation.VisualState
    let activeColorHex: String
    let inactiveColorHex: String
    let inlineContentVisible: Bool
    let popupVisible: Bool
  }

  // MARK: - Lifecycle

  /// Starts the Wi-Fi widget.
  func start() {
    guard !started else { return }
    started = true

    let config = Config.shared.builtinWiFi

    NativeWidgetEventDriver.start(
      observer: eventObserver,
      eventNames: appEventSubscriptions.union([
        WidgetEvent.mouseEntered.rawValue,
        WidgetEvent.mouseExited.rawValue,
      ]),
      widgetTargetIDs: [rootID],
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
    guard started else { return }
    started = false

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
      content: presentation.content,
      signalLevel: presentation.signalLevel,
      visualState: presentation.visualState,
      activeColorHex: presentation.activeColorHex,
      inactiveColorHex: presentation.inactiveColorHex,
      inlineContentVisible: shouldShowInlineContent(config: config),
      popupVisible: shouldShowPopupContent(config: config)
    )
  }
}

// MARK: - Events

extension WiFiNativeWidget {

  /// Handles app-wide Wi-Fi-related events.
  private func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
    guard let event = payload.appEvent else { return false }

    switch event {
    case .networkChange:
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
    guard NativeWidgetHoverSupport.updateHoverState(event, isHovered: &isHovered) else { return }
    publish()
  }

  /// Returns whether inline content should be visible.
  private func shouldShowInlineContent(config: Config.WiFiBuiltinConfig) -> Bool {
    switch config.surface {
    case .always:
      return true
    case .hover:
      return config.hoverSurface == .inline && isHovered
    }
  }

  /// Returns whether popup content should be visible.
  private func shouldShowPopupContent(config: Config.WiFiBuiltinConfig) -> Bool {
    config.surface == .hover && config.hoverSurface == .popup
  }
}
