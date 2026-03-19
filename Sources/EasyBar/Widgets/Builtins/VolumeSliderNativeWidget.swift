import Foundation
import CoreAudio

final class VolumeSliderNativeWidget: NativeWidget {

    let rootID = "builtin_volume"

    private let eventObserver = EasyBarEventObserver()
    private var isHovered = false
    private var autoHideWorkItem: DispatchWorkItem?

    /// Starts the volume widget.
    func start() {
        VolumeEvents.shared.subscribeVolume()

        eventObserver.start { [weak self] payload in
            guard let self else { return }

            if let event = payload.appEvent {
                switch event {
                case .volumeChange, .muteChange:
                    if Config.shared.builtinVolume.expandToSliderOnHover {
                        self.isHovered = true
                        self.scheduleAutoHide()
                    }

                    self.publish()

                default:
                    break
                }

                return
            }

            guard let event = payload.widgetEvent else {
                return
            }

            switch event {
            case .mouseEntered:
                guard payload.widgetID == self.rootID else { return }

                self.isHovered = true
                self.cancelAutoHide()
                self.publish()

            case .mouseExited:
                guard payload.widgetID == self.rootID else { return }

                self.isHovered = false
                self.cancelAutoHide()
                self.publish()

            case .sliderPreview:
                guard payload.widgetID == self.rootID,
                      let value = payload.value else {
                    return
                }

                let config = Config.shared.builtinVolume
                let span = max(config.maxValue - config.minValue, 0.0001)
                let normalized = (value - config.minValue) / span

                if config.expandToSliderOnHover {
                    self.isHovered = true
                    self.cancelAutoHide()
                }

                self.setSystemVolume(normalized)
                self.publish()

            case .sliderChanged:
                guard payload.widgetID == self.rootID,
                      let value = payload.value else {
                    return
                }

                let config = Config.shared.builtinVolume
                let span = max(config.maxValue - config.minValue, 0.0001)
                let normalized = (value - config.minValue) / span

                self.setSystemVolume(normalized)

                if config.expandToSliderOnHover {
                    self.isHovered = true
                    self.scheduleAutoHide()
                }

                self.publish()

            default:
                break
            }
        }

        publish()
    }

    /// Stops the volume widget.
    func stop() {
        eventObserver.stop()

        cancelAutoHide()
        isHovered = false
        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the current volume widget state.
    private func publish() {
        let config = Config.shared.builtinVolume
        let placement = config.placement
        var style = config.style

        let systemVolume = readSystemVolume()
        let isMuted = readMutedState()
        let clampedSystem = min(max(systemVolume, 0), 1)

        let sliderValue = config.minValue + clampedSystem * (config.maxValue - config.minValue)
        let step = max(config.step, 0.0001)
        let roundedValue = (sliderValue / step).rounded() * step

        style.icon = resolvedIcon(for: clampedSystem, muted: isMuted, config: config)

        let text = (config.showPercentage && isHovered)
            ? "\(Int((clampedSystem * 100.0).rounded()))%"
            : ""

        let nodes: [WidgetNodeState]

        if config.expandToSliderOnHover {
            nodes = makeExpandableNodes(
                placement: placement,
                style: style,
                text: text,
                value: roundedValue,
                min: config.minValue,
                max: config.maxValue,
                step: step
            )
        } else {
            nodes = [
                BuiltinNativeNodeFactory.makeSliderNode(
                    rootID: rootID,
                    placement: placement,
                    style: style,
                    text: text,
                    value: roundedValue,
                    min: config.minValue,
                    max: config.maxValue,
                    step: step
                )
            ]
        }

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
    }

    /// Builds the expandable hover layout.
    private func makeExpandableNodes(
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        text: String,
        value: Double,
        min: Double,
        max: Double,
        step: Double
    ) -> [WidgetNodeState] {
        var nodes: [WidgetNodeState] = [
            BuiltinNativeNodeFactory.makeRowContainerNode(
                rootID: rootID,
                placement: placement,
                style: style
            )
        ]

        if !style.icon.isEmpty {
            nodes.append(
                BuiltinNativeNodeFactory.makeChildItemNode(
                    rootID: rootID,
                    parentID: rootID,
                    childID: "\(rootID)_icon",
                    position: placement.position,
                    order: 0,
                    icon: style.icon,
                    color: style.textColorHex
                )
            )
        }

        nodes.append(
            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_label",
                position: placement.position,
                order: 1,
                text: text,
                color: style.textColorHex,
                visible: isHovered && !text.isEmpty
            )
        )

        nodes.append(
            BuiltinNativeNodeFactory.makeChildSliderNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_slider",
                position: placement.position,
                order: 2,
                value: value,
                min: min,
                max: max,
                step: step,
                color: style.textColorHex,
                visible: isHovered
            )
        )

        return nodes
    }

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
    private func resolvedIcon(for value: Double, muted: Bool, config: Config.VolumeBuiltinConfig) -> String {
        if muted {
            return config.mutedIcon
        }

        if value < 0.5 {
            return config.lowIcon
        }

        return config.highIcon
    }

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
