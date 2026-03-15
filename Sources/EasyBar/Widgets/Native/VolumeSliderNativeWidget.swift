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

                self.setSystemVolume(value / 100.0)
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
        let volume = readSystemVolume()
        let percentage = Int((volume * 100.0).rounded())

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: "slider",
            parent: nil,
            position: Config.shared.builtinVolumePosition,
            order: Config.shared.builtinVolumeOrder,
            icon: "🔊",
            text: "\(percentage)%",
            color: nil,
            visible: true,
            role: nil,
            value: Double(percentage),
            min: 0,
            max: 100,
            step: 1,
            values: nil,
            lineWidth: nil,
            paddingX: 8,
            paddingY: 4,
            spacing: 8,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
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
