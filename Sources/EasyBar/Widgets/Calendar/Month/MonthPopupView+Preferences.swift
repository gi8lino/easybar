import SwiftUI

struct MonthCalendarGridFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

struct MonthCalendarDayFramePreferenceKey: PreferenceKey {
  static var defaultValue: [Date: CGRect] = [:]

  static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}
