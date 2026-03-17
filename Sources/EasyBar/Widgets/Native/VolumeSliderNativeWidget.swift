import Foundation
import CoreAudio

final class VolumeSliderNativeWidget: NativeWidget {

    let rootID = "builtin_volume"

    private var eventObserver: NSObjectProtocol?
    private var isHovered = false
    private var autoHideWorkItem: DispatchWorkItem?

    func start() {
        VolumeEvents.shared.subscribeVolume()

        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let payload = notification.object as? [String: String],
                  let rawEvent = payload["event"] else {
                return
            }

            if let event = AppEvent(rawValue: rawEvent) {
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

            guard let event = WidgetEvent(rawValue: rawEvent) else {
                return
            }

            switch event {
            case .mouseEntered:
                guard payload["widget"] == self.rootID else { return }

                self.isHovered = true
                self.cancelAutoHide()
                self.publish()

            case .mouseExited:
                guard payload["widget"] == self.rootID else { return }

                self.isHovered = false
                self.cancelAutoHide()
                self.publish()

            case .sliderPreview:
                guard payload["widget"] == self.rootID,
                      let rawValue = payload["value"],
                      let value = Double(rawValue) else {
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
                guard payload["widget"] == self.rootID,
                      let rawValue = payload["value"],
                      let value = Double(rawValue) else {
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

    func stop() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }

        cancelAutoHide()
        isHovered = false
        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let config = Config.shared.builtinVolume
        let systemVolume = readSystemVolume()
        let isMuted = readMutedState()
        let clampedSystem = min(max(systemVolume, 0), 1)

        let sliderValue = config.minValue + clampedSystem * (config.maxValue - config.minValue)
        let step = max(config.step, 0.0001)
        let roundedValue = (sliderValue / step).rounded() * step

        var style = config.style
        style.icon = resolvedIcon(for: clampedSystem, muted: isMuted, config: config)

        let text = (config.showPercentage && isHovered)
            ? "\(Int((clampedSystem * 100.0).rounded()))%"
            : ""

        let nodes: [WidgetNodeState]

        if config.expandToSliderOnHover {
            nodes = makeExpandableNodes(
                config: config,
                style: style,
                text: text,
                value: roundedValue,
                min: config.minValue,
                max: config.maxValue,
                step: step
            )
        } else {
            nodes = [
                BuiltinWidgetNodeFactory.makeSliderNode(
                    rootID: rootID,
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

    private func makeExpandableNodes(
        config: Config.VolumeBuiltinConfig,
        style: Config.BuiltinWidgetStyle,
        text: String,
        value: Double,
        min: Double,
        max: Double,
        step: Double
    ) -> [WidgetNodeState] {
        var nodes: [WidgetNodeState] = []

        nodes.append(
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: .row,
                parent: nil,
                position: style.position,
                order: style.order,
                icon: "",
                text: "",
                color: nil,
                visible: true,
                role: nil,
                fontSize: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: style.paddingX,
                paddingY: style.paddingY,
                spacing: style.spacing,
                backgroundColor: style.backgroundColorHex,
                borderColor: style.borderColorHex,
                borderWidth: style.borderWidth,
                cornerRadius: style.cornerRadius,
                opacity: style.opacity
            )
        )

        if !style.icon.isEmpty {
            nodes.append(
                WidgetNodeState(
                    id: "\(rootID)_icon",
                    root: rootID,
                    kind: .item,
                    parent: rootID,
                    position: style.position,
                    order: 0,
                    icon: style.icon,
                    text: "",
                    color: style.textColorHex,
                    visible: true,
                    role: nil,
                    fontSize: nil,
                    value: nil,
                    min: nil,
                    max: nil,
                    step: nil,
                    values: nil,
                    lineWidth: nil,
                    paddingX: 0,
                    paddingY: 0,
                    spacing: 4,
                    backgroundColor: nil,
                    borderColor: nil,
                    borderWidth: nil,
                    cornerRadius: nil,
                    opacity: 1
                )
            )
        }

        nodes.append(
            WidgetNodeState(
                id: "\(rootID)_label",
                root: rootID,
                kind: .item,
                parent: rootID,
                position: style.position,
                order: 1,
                icon: "",
                text: text,
                color: style.textColorHex,
                visible: isHovered && !text.isEmpty,
                role: nil,
                fontSize: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: 0,
                paddingY: 0,
                spacing: 4,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1
            )
        )

        nodes.append(
            WidgetNodeState(
                id: "\(rootID)_slider",
                root: rootID,
                kind: .slider,
                parent: rootID,
                position: style.position,
                order: 2,
                icon: "",
                text: "",
                color: style.textColorHex,
                visible: isHovered,
                role: nil,
                fontSize: nil,
                value: value,
                min: min,
                max: max,
                step: step,
                values: nil,
                lineWidth: nil,
                paddingX: 0,
                paddingY: 0,
                spacing: 4,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1
            )
        )

        return nodes
    }

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

    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }

    private func resolvedIcon(for value: Double, muted: Bool, config: Config.VolumeBuiltinConfig) -> String {
        if muted {
            return config.mutedIcon
        }

        if value < 0.5 {
            return config.lowIcon
        }

        return config.highIcon
    }

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
