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

    Logger.debug("subscribed volume_change")
    Logger.debug("subscribed mute_change")
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

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      // Device changes can invalidate all per-device listeners, so rebuild them first.
      self?.refreshDeviceSubscription()
      EventBus.shared.emit(.volumeChange)
    }

    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      DispatchQueue.main,
      block
    )

    guard status == noErr else {
      Logger.debug("failed to subscribe default output device changes status=\(status)")
      return
    }

    defaultDeviceListener = block
  }

  /// Removes the default output device listener.
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

  /// Rebinds per-device listeners to the current default output device.
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

    // Re-emit current state after switching devices so widgets refresh immediately.
    EventBus.shared.emit(.volumeChange)
    EventBus.shared.emit(.muteChange, muted: lastMutedState ?? false)
  }

  /// Starts volume and mute listeners for the current output device.
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

    guard volumeStatus == noErr else {
      Logger.debug("failed to subscribe volume listener status=\(volumeStatus)")
      return
    }

    volumeListener = volumeBlock

    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      EventBus.shared.emit(.volumeChange)

      guard let self, let deviceID = self.currentDeviceID else { return }

      // Only emit mute changes when the effective state actually changed.
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

    guard muteStatus == noErr else {
      Logger.debug("mute listener unavailable on current output device status=\(muteStatus)")
      return
    }

    muteListener = muteBlock
  }

  /// Removes all listeners from the current output device.
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

  /// Returns the current default output device id.
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

  /// Returns the current mute state for one output device.
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
