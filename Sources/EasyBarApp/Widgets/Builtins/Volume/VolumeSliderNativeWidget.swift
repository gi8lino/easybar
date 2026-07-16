import CoreAudio
import Foundation

/// Native volume widget with optional inline expansion.
@MainActor
final class VolumeSliderNativeWidget: NativeWidget {

  let rootID = "builtin_volume"
  let widgetStore: WidgetStore

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.volumeChange.rawValue,
      AppEvent.muteChange.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  let config: Config.VolumeBuiltinConfig
  let eventObserver: EasyBarEventObserver
  var isHovered = false
  var isAdjustingSlider = false
  var autoHideTask: Task<Void, Never>?
  var autoHideTaskID: UInt64?
  var nextAutoHideTaskID: UInt64 = 1
  private lazy var renderer = VolumeRenderer(rootID: rootID)

  struct SystemVolumeState {
    let clampedSystem: Double
    let roundedValue: Double
    let step: Double
    let isMuted: Bool
  }

  struct Snapshot {
    let config: Config.VolumeBuiltinConfig
    let placement: Config.BuiltinWidgetPlacement
    var style: Config.BuiltinWidgetStyle
    let text: String
    let value: Double
    let step: Double
    let isHovered: Bool
  }

  /// Creates the native volume widget from an immutable config section.
  init(config: Config.VolumeBuiltinConfig, widgetStore: WidgetStore, eventHub: EventHub) {
    self.config = config
    self.widgetStore = widgetStore
    self.eventObserver = EasyBarEventObserver(eventHub: eventHub)
  }

  // MARK: - Lifecycle

  /// Starts the volume widget.
  func start() {
    eventObserver.start(
      eventNames: appEventSubscriptions.union([
        WidgetEvent.mouseEntered.rawValue,
        WidgetEvent.mouseExited.rawValue,
        WidgetEvent.sliderPreview.rawValue,
        WidgetEvent.sliderChanged.rawValue,
      ]),
      widgetTargetIDs: [rootID, "\(rootID)_slider"]
    ) { [weak self] payload in
      guard let self, !self.handleAppEvent(payload) else { return }
      self.handleWidgetEvent(payload)
    }

    publish()
  }

  /// Stops the volume widget.
  func stop() {
    eventObserver.stop()
    cancelAutoHide()
    isHovered = false
    isAdjustingSlider = false

    clearNodes()
  }

  // MARK: - Publish

  /// Publishes the current volume widget state.
  func publish() {
    let snapshot = makeSnapshot()
    applyNodes(renderer.makeNodes(snapshot: snapshot))
  }

  /// Returns the current render snapshot.
  func makeSnapshot() -> Snapshot {
    let placement = config.placement
    var style = config.style
    let volumeState = currentSystemVolumeState(config: config)

    style.icon = resolvedIcon(
      for: volumeState.clampedSystem,
      muted: volumeState.isMuted,
      config: config
    )

    let text =
      config.showPercentage && isHovered
      ? "\(Int((volumeState.clampedSystem * 100.0).rounded()))%"
      : ""

    return Snapshot(
      config: config,
      placement: placement,
      style: style,
      text: text,
      value: volumeState.roundedValue,
      step: volumeState.step,
      isHovered: isHovered
    )
  }
}
