import Foundation
import CoreAudio

final class VolumeEvents {

    static let shared = VolumeEvents()

    private var currentDeviceID: AudioDeviceID?
    private var isSubscribed = false

    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?

    private var lastMutedState: Bool?

    private init() {}

    func subscribeVolume() {
        guard !isSubscribed else { return }

        isSubscribed = true
        installDefaultOutputDeviceListener()
        refreshDeviceSubscription()

        Logger.debug("subscribed volume_change")
        Logger.debug("subscribed mute_change")
    }

    func stopAll() {
        uninstallDeviceListeners()
        uninstallDefaultOutputDeviceListener()

        currentDeviceID = nil
        isSubscribed = false
        lastMutedState = nil
    }

    private func installDefaultOutputDeviceListener() {
        guard defaultDeviceListener == nil else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDeviceSubscription()
            EventBus.shared.emit(.volumeChange)
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )

        if status == noErr {
            defaultDeviceListener = block
        } else {
            Logger.debug("failed to subscribe default output device changes status=\(status)")
        }
    }

    private func uninstallDefaultOutputDeviceListener() {
        guard let block = defaultDeviceListener else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )

        if status != noErr {
            Logger.debug("failed to remove default output device listener status=\(status)")
        }

        defaultDeviceListener = nil
    }

    private func refreshDeviceSubscription() {
        let newDeviceID = defaultOutputDeviceID()

        guard let newDeviceID else {
            Logger.debug("no default output device found")
            return
        }

        if currentDeviceID == newDeviceID {
            return
        }

        uninstallDeviceListeners()
        currentDeviceID = newDeviceID
        lastMutedState = readMutedState(for: newDeviceID)
        installDeviceListeners()

        EventBus.shared.emit(.volumeChange)
        EventBus.shared.emit(.muteChange, muted: lastMutedState ?? false)
    }

    private func installDeviceListeners() {
        guard let deviceID = currentDeviceID else { return }

        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let volumeBlock: AudioObjectPropertyListenerBlock = { _, _ in
            EventBus.shared.emit(.volumeChange)
        }

        let volumeStatus = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volumeAddress,
            DispatchQueue.main,
            volumeBlock
        )

        if volumeStatus == noErr {
            volumeListener = volumeBlock
        } else {
            Logger.debug("failed to subscribe volume listener status=\(volumeStatus)")
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            EventBus.shared.emit(.volumeChange)

            guard let self, let deviceID = self.currentDeviceID else { return }

            let muted = self.readMutedState(for: deviceID)
            if self.lastMutedState != muted {
                self.lastMutedState = muted
                EventBus.shared.emit(.muteChange, muted: muted)
            }
        }

        let muteStatus = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &muteAddress,
            DispatchQueue.main,
            muteBlock
        )

        if muteStatus == noErr {
            muteListener = muteBlock
        } else {
            Logger.debug("mute listener unavailable on current output device status=\(muteStatus)")
        }
    }

    private func uninstallDeviceListeners() {
        guard let deviceID = currentDeviceID else { return }

        if let block = volumeListener {
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectRemovePropertyListenerBlock(
                deviceID,
                &volumeAddress,
                DispatchQueue.main,
                block
            )

            if status != noErr {
                Logger.debug("failed to remove volume listener status=\(status)")
            }

            volumeListener = nil
        }

        if let block = muteListener {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectRemovePropertyListenerBlock(
                deviceID,
                &muteAddress,
                DispatchQueue.main,
                block
            )

            if status != noErr {
                Logger.debug("failed to remove mute listener status=\(status)")
            }

            muteListener = nil
        }
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
            Logger.debug("failed to read default output device status=\(status)")
            return nil
        }

        return deviceID
    }

    private func readMutedState(for deviceID: AudioDeviceID) -> Bool {
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
}
