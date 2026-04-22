import SwiftUI

extension String {

  /// Returns the hex text normalized for shared color checks.
  var normalizedHexColor: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
      .uppercased()
  }

  /// Returns whether this hex string resolves to a fully transparent color.
  var isFullyTransparentHexColor: Bool {
    normalizedHexColor.isEmpty || normalizedHexColor == "00000000"
  }
}

extension Color {

  /// Creates a color from `RRGGBB` or `RRGGBBAA` hex text.
  init(hex: String) {

    let hex = hex.normalizedHexColor

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
