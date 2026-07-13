import SwiftUI

struct MonthCalendarGridFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect { .zero }

  /// Handles reduce.
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
    return
  }
}

struct MonthCalendarDayFramePreferenceKey: PreferenceKey {
  static var defaultValue: [Date: CGRect] { [:] }

  /// Handles reduce.
  static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}
