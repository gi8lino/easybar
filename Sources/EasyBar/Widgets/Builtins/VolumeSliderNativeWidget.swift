import CoreAudio
import Foundation

final class VolumeSliderNativeWidget: NativeWidget {
  let rootID = "builtin_volume"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.volumeChange.rawValue,
      AppEvent.muteChange.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private var isHovered = false
  private var autoHideWorkItem: DispatchWorkItem?

  private struct SystemVolumeState {
    let clampedSystem: Double
    let roundedValue: Double
    let step: Double
    let isMuted: Bool
  }

  private struct Snapshot {
    let config: Config.VolumeBuiltinConfig
    let placement: Config.BuiltinWidgetPlacement
    var style: Config.BuiltinWidgetStyle
    let text: String
    let value: Double
    let step: Double
  }

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
}

// MARK: - Lifecycle

extension VolumeSliderNativeWidget {
  /// Stops the volume widget.
  func stop() {
    eventObserver.stop()

    cancelAutoHide()
    isHovered = false
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the current volume widget state.
  private func publish() {
    let snapshot = makeSnapshot()
    let nodes = makeNodes(snapshot: snapshot)
    WidgetStore.shared.apply(root: rootID, nodes: nodes)
  }

  /// Returns the current render snapshot.
  private func makeSnapshot() -> Snapshot {
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
      step: volumeState.step
    )
  }
}

// MARK: - Event Handling

extension VolumeSliderNativeWidget {
  private func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
    guard let event = payload.appEvent else {
      return false
    }

    guard event == .volumeChange || event == .muteChange || event == .systemWoke else {
      return false
    }

    applyExternalVolumeChange()
    publish()
    return true
  }

  private func handleWidgetEvent(_ payload: EasyBarEventPayload) {
    guard let event = payload.widgetEvent else { return }
    guard payload.widgetID == rootID else { return }

    switch event {
    case .mouseEntered:
      isHovered = true
      cancelAutoHide()
      publish()

    case .mouseExited:
      isHovered = false
      cancelAutoHide()
      publish()

    case .sliderPreview:
      guard let value = payload.value else { return }
      applySliderValue(value, shouldAutoHide: false)

    case .sliderChanged:
      guard let value = payload.value else { return }
      applySliderValue(value, shouldAutoHide: true)

    default:
      break
    }
  }

  private func applyExternalVolumeChange() {
    guard Config.shared.builtinVolume.expandToSliderOnHover else { return }

    isHovered = true
    scheduleAutoHide()
  }

  private func applySliderValue(_ value: Double, shouldAutoHide: Bool) {
    let normalized = normalizedSliderValue(value, config: Config.shared.builtinVolume)

    guard Config.shared.builtinVolume.expandToSliderOnHover else {
      setSystemVolume(normalized)
      publish()
      return
    }

    isHovered = true
    cancelAutoHide()
    setSystemVolume(normalized)

    if shouldAutoHide {
      scheduleAutoHide()
    }

    publish()
  }

  private func normalizedSliderValue(_ value: Double, config: Config.VolumeBuiltinConfig)
    -> Double
  {
    let span = max(config.maxValue - config.minValue, 0.0001)
    return (value - config.minValue) / span
  }

  /// Returns the current rendered volume state.
  private func currentSystemVolumeState(config: Config.VolumeBuiltinConfig) -> SystemVolumeState {
    let systemVolume = readSystemVolume()
    let isMuted = readMutedState()
    let clampedSystem = min(max(systemVolume, 0), 1)
    let step = max(config.step, 0.0001)
    let sliderValue = config.minValue + clampedSystem * (config.maxValue - config.minValue)
    let roundedValue = (sliderValue / step).rounded() * step

    return SystemVolumeState(
      clampedSystem: clampedSystem,
      roundedValue: roundedValue,
      step: step,
      isMuted: isMuted
    )
  }
}

// MARK: - Node Building

extension VolumeSliderNativeWidget {
  private func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    guard !snapshot.config.expandToSliderOnHover else {
      return makeExpandableNodes(snapshot: snapshot)
    }

    return [
      BuiltinNativeNodeFactory.makeSliderNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style,
        text: snapshot.text,
        value: snapshot.value,
        min: snapshot.config.minValue,
        max: snapshot.config.maxValue,
        step: snapshot.step
      )
    ]
  }

  /// Builds the expandable hover layout.
  private func makeExpandableNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    var nodes: [WidgetNodeState] = [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      )
    ]

    if !snapshot.style.icon.isEmpty {
      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: rootID,
          childID: "\(rootID)_icon",
          position: snapshot.placement.position,
          order: 0,
          icon: snapshot.style.icon,
          color: snapshot.style.textColorHex
        )
      )
    }

    nodes.append(
      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_label",
        position: snapshot.placement.position,
        order: 1,
        text: snapshot.text,
        color: snapshot.style.textColorHex,
        visible: isHovered && !snapshot.text.isEmpty
      )
    )

    nodes.append(
      BuiltinNativeNodeFactory.makeChildSliderNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_slider",
        position: snapshot.placement.position,
        order: 2,
        value: snapshot.value,
        min: snapshot.config.minValue,
        max: snapshot.config.maxValue,
        step: snapshot.step,
        color: snapshot.style.textColorHex,
        visible: isHovered
      )
    )

    return nodes
  }
}

// MARK: - Hover Behavior

extension VolumeSliderNativeWidget {
  /// Schedules hiding the slider shortly after interaction.
  private func scheduleAutoHide() {
    cancelAutoHide()

    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.isHovered = false
      self.publish()
    }

    autoHideWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
  }

  /// Cancels a pending auto-hide.
  private func cancelAutoHide() {
    autoHideWorkItem?.cancel()
    autoHideWorkItem = nil
  }

  /// Resolves the volume icon.
  private func resolvedIcon(for value: Double, muted: Bool, config: Config.VolumeBuiltinConfig)
    -> String
  {
    if muted {
      return config.mutedIcon
    }

    if value < 0.5 {
      return config.lowIcon
    }

    return config.highIcon
  }
}

// MARK: - CoreAudio Access

extension VolumeSliderNativeWidget {
  /// Reads the current system volume.
  private func readSystemVolume() -> Double {
    guard let deviceID = defaultOutputDeviceID() else {
      return 0
    }

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var value = Float32(0)
    var size = UInt32(MemoryLayout<Float32>.size)

    let status = AudioObjectGetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      &size,
      &value
    )

    guard status == noErr else {
      return 0
    }

    return Double(value)
  }

  /// Reads the current muted state.
  private func readMutedState() -> Bool {
    guard let deviceID = defaultOutputDeviceID() else {
      return false
    }

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var muted = UInt32(0)
    var size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      &size,
      &muted
    )

    guard status == noErr else {
      return false
    }

    return muted != 0
  }

  /// Sets the system volume.
  private func setSystemVolume(_ volume: Double) {
    guard let deviceID = defaultOutputDeviceID() else { return }

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var value = Float32(min(max(volume, 0), 1))

    _ = AudioObjectSetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      UInt32(MemoryLayout<Float32>.size),
      &value
    )
  }

  /// Returns the default output device.
  private func defaultOutputDeviceID() -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )

    guard status == noErr else {
      return nil
    }

    return deviceID
  }
}
