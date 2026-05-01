import SwiftUI

/// Global runtime theme helpers.
enum Theme {

  /// Global icon font family used for Nerd Font / symbol-style icons.
  ///
  /// Change this in one place when you want to switch the app-wide icon font.
  private static let iconFontFamily = "Symbols Nerd Font Mono"

  /// Bar background color from config.
  static var barBackground: Color {
    Color(hex: Config.shared.barBackgroundHex)
  }

  /// Bar border color from config.
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

  /// Focused workspace background color.
  static var spaceActiveBackground: Color {
    Color(hex: Config.shared.builtinSpaces.colors.activeBackgroundHex)
  }

  /// Inactive workspace background color.
  static var spaceInactiveBackground: Color {
    Color(hex: Config.shared.builtinSpaces.colors.inactiveBackgroundHex)
  }

  /// Focused workspace border color.
  static var spaceActiveBorder: Color {
    Color(hex: Config.shared.builtinSpaces.colors.activeBorderHex)
  }

  /// Inactive workspace border color.
  static var spaceInactiveBorder: Color {
    Color(hex: Config.shared.builtinSpaces.colors.inactiveBorderHex)
  }

  /// Focused workspace text color.
  static var spaceFocusedText: Color {
    Color(hex: Config.shared.builtinSpaces.text.focusedColorHex)
  }

  /// Inactive workspace text color.
  static var spaceInactiveText: Color {
    Color(hex: Config.shared.builtinSpaces.text.inactiveColorHex)
  }
}
