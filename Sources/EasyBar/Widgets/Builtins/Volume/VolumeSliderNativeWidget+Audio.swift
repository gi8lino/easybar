import CoreAudio
import Foundation

extension VolumeSliderNativeWidget {

  /// Converts the slider-range value back to a normalized system volume.
  func normalizedSliderValue(_ value: Double, config: Config.VolumeBuiltinConfig) -> Double {
    let span = max(config.maxValue - config.minValue, 0.0001)
    return (value - config.minValue) / span
  }

  /// Returns the current system volume state.
  func currentSystemVolumeState(config: Config.VolumeBuiltinConfig) -> SystemVolumeState {
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

  /// Reads the current system volume.
  func readSystemVolume() -> Double {
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
  func readMutedState() -> Bool {
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
  func setSystemVolume(_ volume: Double) {
    guard let deviceID = defaultOutputDeviceID() else { return }

    let clamped = min(max(volume, 0), 1)
    let scalar = Float32(clamped)

    let wroteMain = writeSystemVolumeScalar(scalar, deviceID: deviceID, element: kAudioObjectPropertyElementMain)
    let wroteLeft = writeSystemVolumeScalar(scalar, deviceID: deviceID, element: 1)
    let wroteRight = writeSystemVolumeScalar(scalar, deviceID: deviceID, element: 2)

    if clamped > 0, wroteMain || wroteLeft || wroteRight {
      setMutedState(false, deviceID: deviceID)
    }
  }

  /// Returns the default output device.
  func defaultOutputDeviceID() -> AudioDeviceID? {
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

  /// Writes one scalar volume value to one output element.
  @discardableResult
  private func writeSystemVolumeScalar(
    _ value: Float32,
    deviceID: AudioDeviceID,
    element: AudioObjectPropertyElement
  ) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: element
    )

    guard AudioObjectHasProperty(deviceID, &address) else {
      return false
    }

    var mutableValue = value
    let status = AudioObjectSetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      UInt32(MemoryLayout<Float32>.size),
      &mutableValue
    )

    return status == noErr
  }

  /// Sets the mute state when the current device exposes a mute control.
  private func setMutedState(_ muted: Bool, deviceID: AudioDeviceID) {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    guard AudioObjectHasProperty(deviceID, &address) else {
      return
    }

    var value: UInt32 = muted ? 1 : 0
    _ = AudioObjectSetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      UInt32(MemoryLayout<UInt32>.size),
      &value
    )
  }
}
