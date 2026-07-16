import SwiftUI

/// Shared visual primitives for reusable calendar UI components.
enum CalendarUIPrimitives {
  /// Shared icon font family used by calendar UI text icons.
  static let iconFontFamily = "Symbols Nerd Font Mono"

  /// Returns the shared icon font used by calendar UI components.
  static func iconFont(size: CGFloat) -> Font {
    .custom(iconFontFamily, size: size)
  }
}

extension String {
  /// Returns normalized hex text for shared color checks.
  var calendarNormalizedHexColor: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
      .uppercased()
  }
}

extension Color {
  /// Creates a color from `RRGGBB` or `RRGGBBAA` hex text.
  init(calendarHex: String) {
    let hex = calendarHex.calendarNormalizedHexColor
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)

    switch hex.count {
    case 6:
      let r = Double((int >> 16) & 0xff) / 255
      let g = Double((int >> 8) & 0xff) / 255
      let b = Double(int & 0xff) / 255
      self.init(red: r, green: g, blue: b)
    case 8:
      let r = Double((int >> 24) & 0xff) / 255
      let g = Double((int >> 16) & 0xff) / 255
      let b = Double((int >> 8) & 0xff) / 255
      let a = Double(int & 0xff) / 255
      self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    default:
      self.init(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    }
  }
}
