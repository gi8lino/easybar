import SwiftUI

enum SliderWidthResolver {

  /// Resolves the effective slider width for one widget.
  static func resolve(
    explicitWidth: CGFloat?,
    fallback: CGFloat
  ) -> CGFloat {
    if let explicitWidth {
      return explicitWidth
    }

    return fallback
  }
}
