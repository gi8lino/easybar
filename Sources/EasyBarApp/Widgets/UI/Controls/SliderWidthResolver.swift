import SwiftUI

enum SliderWidthResolver {

  /// Resolves the effective slider width for one widget.
  static func resolve(
    explicitWidth: CGFloat?,
    fallback: CGFloat
  ) -> CGFloat {
    if let explicitWidth, explicitWidth.isFinite, explicitWidth > 0 {
      return explicitWidth
    }

    if fallback.isFinite, fallback > 0 {
      return fallback
    }

    return 1
  }
}
