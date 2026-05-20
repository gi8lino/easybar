import Foundation

extension VolumeSliderNativeWidget {

  /// Handles app-wide volume-related events.
  func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
    guard let event = payload.appEvent else { return false }

    guard event == .volumeChange || event == .muteChange || event == .systemWoke else {
      return false
    }

    if isAdjustingSlider && (event == .volumeChange || event == .muteChange) {
      return true
    }

    applyExternalVolumeChange()
    publish()
    return true
  }

  /// Handles widget-local hover and slider events.
  func handleWidgetEvent(_ payload: EasyBarEventPayload) {
    guard let event = payload.widgetEvent else { return }
    guard payload.widgetID == rootID || payload.widgetID == "\(rootID)_slider" else { return }

    switch event {
    case .mouseEntered:
      isHovered = true
      cancelAutoHide()
      publish()

    case .mouseExited:
      guard !isAdjustingSlider else { return }
      isHovered = false
      cancelAutoHide()
      publish()

    case .sliderPreview:
      guard let value = payload.value else { return }
      applySliderPreviewValue(value)

    case .sliderChanged:
      guard let value = payload.value else { return }
      isAdjustingSlider = false
      applySliderValue(value, shouldAutoHide: true)

    default:
      break
    }
  }

  /// Expands temporarily on external volume change when configured.
  func applyExternalVolumeChange() {
    guard Config.shared.builtinVolume.expandToSliderOnHover else { return }
    guard !isAdjustingSlider else { return }

    isHovered = true
    scheduleAutoHide()
  }

  /// Applies one slider preview value without rebuilding the widget mid-drag.
  func applySliderPreviewValue(_ value: Double) {
    let normalized = normalizedSliderValue(value, config: Config.shared.builtinVolume)

    isAdjustingSlider = true
    isHovered = true
    cancelAutoHide()
    setSystemVolume(normalized)
  }

  /// Applies one slider value back to the system volume.
  func applySliderValue(_ value: Double, shouldAutoHide: Bool) {
    let normalized = normalizedSliderValue(value, config: Config.shared.builtinVolume)

    guard Config.shared.builtinVolume.expandToSliderOnHover else {
      setSystemVolume(normalized)
      publish()
      return
    }

    isHovered = true
    isAdjustingSlider = false
    cancelAutoHide()
    setSystemVolume(normalized)

    if shouldAutoHide {
      scheduleAutoHide()
    }

    publish()
  }
}
