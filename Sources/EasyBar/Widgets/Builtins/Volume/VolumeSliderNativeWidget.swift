import CoreAudio
import Foundation

/// Native volume widget with optional inline expansion.
@MainActor
final class VolumeSliderNativeWidget: NativeWidget {

  let rootID = "builtin_volume"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.volumeChange.rawValue,
      AppEvent.muteChange.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  let eventObserver = EasyBarEventObserver()
  var isHovered = false
  var autoHideWorkItem: DispatchWorkItem?
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

  // MARK: - Lifecycle

  /// Starts the volume widget.
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

    publish()
  }

  /// Stops the volume widget.
  func stop() {
    eventObserver.stop()
    cancelAutoHide()
    isHovered = false

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  // MARK: - Publish

  /// Publishes the current volume widget state.
  func publish() {
    let snapshot = makeSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: renderer.makeNodes(snapshot: snapshot))
  }

  /// Returns the current render snapshot.
  func makeSnapshot() -> Snapshot {
    let config = Config.shared.builtinVolume
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
