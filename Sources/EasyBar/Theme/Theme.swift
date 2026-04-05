import SwiftUI

/// Global runtime theme helpers.
enum Theme {

  /// Global icon font family used for Nerd Font / symbol-style icons.
  ///
  /// Change this in one place when you want to switch the app-wide icon font.
  private static let iconFontFamily = "Symbols Nerd Font Mono"

  static var barBackground: Color {
    Color(hex: Config.shared.barBackgroundHex)
  }

  static var barBorder: Color {
    Color(hex: Config.shared.barBorderHex)
  }

  /// Fallback text color for views and nodes without a color.
  static var defaultTextColor: Color {
    Color.white
  }

  /// Returns the shared icon font used by popups and other icon-only text.
  static func iconFont(size: CGFloat) -> Font {
    .custom(iconFontFamily, size: size)
  }

  /// Border color for the focused app icon inside spaces.
  static var spaceFocusedAppBorder: Color {
    Color(hex: Config.shared.builtinSpaces.colors.focusedAppBorderHex)
  }

  static var spaceActiveBackground: Color {
    Color(hex: Config.shared.builtinSpaces.colors.activeBackgroundHex)
  }

  static var spaceInactiveBackground: Color {
    Color(hex: Config.shared.builtinSpaces.colors.inactiveBackgroundHex)
  }

  static var spaceActiveBorder: Color {
    Color(hex: Config.shared.builtinSpaces.colors.activeBorderHex)
  }

  static var spaceInactiveBorder: Color {
    Color(hex: Config.shared.builtinSpaces.colors.inactiveBorderHex)
  }

  static var spaceFocusedText: Color {
    Color(hex: Config.shared.builtinSpaces.text.focusedColorHex)
  }

  static var spaceInactiveText: Color {
    Color(hex: Config.shared.builtinSpaces.text.inactiveColorHex)
  }
}
