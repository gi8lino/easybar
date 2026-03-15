import Foundation
import CoreAudio

final class VolumeSliderNativeWidget: NativeWidget {

    let rootID = "builtin_volume"

    private var eventObserver: NSObjectProtocol?

    func start() {
        VolumeEvents.shared.subscribeVolume()

        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let payload = notification.object as? [String: String],
                  let event = payload["event"] else {
                return
            }

            switch event {
            case "volume_change":
                self.publish()

            case "slider.preview", "slider.changed":
                guard payload["widget"] == self.rootID,
                      let rawValue = payload["value"],
                      let value = Double(rawValue) else {
                    return
                }

                let config = Config.shared.builtinVolume
                let span = max(config.maxValue - config.minValue, 0.0001)
                let normalized = (value - config.minValue) / span

                self.setSystemVolume(normalized)
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

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let config = Config.shared.builtinVolume
        let systemVolume = readSystemVolume()
        let clampedSystem = min(max(systemVolume, 0), 1)

        let sliderValue = config.minValue + clampedSystem * (config.maxValue - config.minValue)
        let roundedValue = (sliderValue / max(config.step, 0.0001)).rounded() * max(config.step, 0.0001)

        var style = config.style
        style.icon = resolvedIcon(for: clampedSystem, config: config)

        let text = config.showPercentage
            ? "\(Int((clampedSystem * 100.0).rounded()))%"
            : ""

        let node = BuiltinWidgetNodeFactory.makeSliderNode(
            rootID: rootID,
            style: style,
            text: text,
            value: roundedValue,
            min: config.minValue,
            max: config.maxValue,
            step: max(config.step, 0.0001)
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    private func resolvedIcon(for value: Double, config: Config.VolumeBuiltinConfig) -> String {
        if value <= 0.001 {
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
