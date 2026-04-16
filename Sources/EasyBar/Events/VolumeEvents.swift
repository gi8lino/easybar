import CoreAudio
import Foundation

final class VolumeEvents {
  static let shared = VolumeEvents()

  private var currentDeviceID: AudioDeviceID?
  private var isSubscribed = false

  private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
  private var volumeListener: AudioObjectPropertyListenerBlock?
  private var muteListener: AudioObjectPropertyListenerBlock?

  private var lastMutedState: Bool?

  private init() {}

  /// Starts observation for output-device, volume, and mute changes.
  func subscribeVolume() {
    guard !isSubscribed else { return }

    isSubscribed = true
    installDefaultOutputDeviceListener()
    refreshDeviceSubscription()

    easybarLog.debug("subscribed volume_change")
    easybarLog.debug("subscribed mute_change")
  }

  /// Stops all active audio listeners and clears cached device state.
  func stopAll() {
    uninstallDeviceListeners()
    uninstallDefaultOutputDeviceListener()

    currentDeviceID = nil
    isSubscribed = false
    lastMutedState = nil
  }

  /// Starts listening for default output device changes.
  private func installDefaultOutputDeviceListener() {
    guard defaultDeviceListener == nil else { return }

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.refreshDeviceSubscription()

      Task {
        await EventHub.shared.emit(.volumeChange)
      }
    }

    let status = addListener(
      objectID: AudioObjectID(kAudioObjectSystemObject),
      address: defaultOutputDeviceAddress(),
      block: block
    )

    guard status == noErr else {
      easybarLog.debug("failed to subscribe default output device changes status=\(status)")
      return
    }

    defaultDeviceListener = block
  }

  /// Removes the default output device listener.
  private func uninstallDefaultOutputDeviceListener() {
    guard let block = defaultDeviceListener else { return }
    defer { defaultDeviceListener = nil }

    let status = removeListener(
      objectID: AudioObjectID(kAudioObjectSystemObject),
      address: defaultOutputDeviceAddress(),
      block: block
    )

    guard status == noErr else {
      easybarLog.debug("failed to remove default output device listener status=\(status)")
      return
    }
  }

  /// Rebinds per-device listeners to the current default output device.
  private func refreshDeviceSubscription() {
    let newDeviceID = defaultOutputDeviceID()

    guard let newDeviceID else {
      easybarLog.debug("no default output device found")
      return
    }

    if currentDeviceID == newDeviceID {
      return
    }

    uninstallDeviceListeners()
    currentDeviceID = newDeviceID
    lastMutedState = readMutedState(for: newDeviceID)
    installDeviceListeners()

    Task {
      await EventHub.shared.emit(.volumeChange)
      await EventHub.shared.emit(.muteChange, muted: lastMutedState ?? false)
    }
  }

  /// Starts volume and mute listeners for the current output device.
  private func installDeviceListeners() {
    guard let deviceID = currentDeviceID else { return }

    let volumeBlock: AudioObjectPropertyListenerBlock = { _, _ in
      Task {
        await EventHub.shared.emit(.volumeChange)
      }
    }

    let volumeStatus = addListener(
      objectID: deviceID,
      address: volumeAddress(),
      block: volumeBlock
    )

    guard volumeStatus == noErr else {
      easybarLog.debug("failed to subscribe volume listener status=\(volumeStatus)")
      return
    }

    volumeListener = volumeBlock

    let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task {
        await EventHub.shared.emit(.volumeChange)
      }

      guard let self, let deviceID = self.currentDeviceID else { return }

      let muted = self.readMutedState(for: deviceID)
      if self.lastMutedState != muted {
        self.lastMutedState = muted

        Task {
          await EventHub.shared.emit(.muteChange, muted: muted)
        }
      }
    }

    let muteStatus = addListener(
      objectID: deviceID,
      address: muteAddress(),
      block: muteBlock
    )

    guard muteStatus == noErr else {
      easybarLog.debug("mute listener unavailable on current output device status=\(muteStatus)")
      return
    }

    muteListener = muteBlock
  }

  /// Removes all listeners from the current output device.
  private func uninstallDeviceListeners() {
    guard let deviceID = currentDeviceID else { return }

    if let block = volumeListener {
      defer { volumeListener = nil }

      let status = removeListener(
        objectID: deviceID,
        address: volumeAddress(),
        block: block
      )

      guard status == noErr else {
        easybarLog.debug("failed to remove volume listener status=\(status)")
        return
      }
    }

    if let block = muteListener {
      defer { muteListener = nil }

      let status = removeListener(
        objectID: deviceID,
        address: muteAddress(),
        block: block
      )

      guard status == noErr else {
        easybarLog.debug("failed to remove mute listener status=\(status)")
        return
      }
    }
  }

  /// Returns the current default output device id.
  private func defaultOutputDeviceID() -> AudioDeviceID? {
    var address = defaultOutputDeviceAddress()

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
      easybarLog.debug("failed to read default output device status=\(status)")
      return nil
    }

    return deviceID
  }

  /// Returns the current mute state for one output device.
  private func readMutedState(for deviceID: AudioDeviceID) -> Bool {
    var address = muteAddress()

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

  /// Returns the CoreAudio address for the default output device property.
  private func defaultOutputDeviceAddress() -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  /// Returns the CoreAudio address for output volume.
  private func volumeAddress() -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  /// Returns the CoreAudio address for output mute state.
  private func muteAddress() -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  /// Installs one property listener block on one audio object.
  private func addListener(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    block: @escaping AudioObjectPropertyListenerBlock
  ) -> OSStatus {
    var address = address
    return AudioObjectAddPropertyListenerBlock(
      objectID,
      &address,
      DispatchQueue.main,
      block
    )
  }

  /// Removes one property listener block from one audio object.
  private func removeListener(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    block: @escaping AudioObjectPropertyListenerBlock
  ) -> OSStatus {
    var address = address
    return AudioObjectRemovePropertyListenerBlock(
      objectID,
      &address,
      DispatchQueue.main,
      block
    )
  }
}
