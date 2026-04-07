import SwiftUI

extension Color {

  /// Creates a color from `RRGGBB` or `RRGGBBAA` hex text.
  init(hex: String) {

    var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hex = hex.replacingOccurrences(of: "#", with: "")

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
