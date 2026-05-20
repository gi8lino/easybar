import Foundation

extension VolumeSliderNativeWidget {

  /// Schedules hiding the slider shortly after interaction.
  func scheduleAutoHide() {
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
  func cancelAutoHide() {
    autoHideWorkItem?.cancel()
    autoHideWorkItem = nil
  }

  /// Resolves the volume icon.
  func resolvedIcon(for value: Double, muted: Bool, config: Config.VolumeBuiltinConfig) -> String {
    if muted {
      return config.mutedIcon
    }

    if value < 0.5 {
      return config.lowIcon
    }

    return config.highIcon
  }
}
