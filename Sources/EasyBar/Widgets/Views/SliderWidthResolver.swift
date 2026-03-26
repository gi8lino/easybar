import SwiftUI

enum SliderWidthResolver {

  /// Resolves the effective slider width for one widget.
  static func resolve(
    explicitWidth: CGFloat?,
    rootWidgetID: String,
    fallback: CGFloat
  ) -> CGFloat {
    if let explicitWidth {
      return explicitWidth
    }

    if rootWidgetID == "builtin_volume" {
      return CGFloat(Config.shared.builtinVolume.sliderWidth)
    }

    return fallback
  }
}
