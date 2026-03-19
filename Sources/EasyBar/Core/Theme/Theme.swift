import SwiftUI

/// Global runtime theme helpers.
///
/// These values are derived from config where applicable, or provide
/// one fixed fallback when a widget/node does not specify its own color.
enum Theme {

    static var barBackground: Color {
        Color(hex: Config.shared.barBackgroundHex)
    }

    static var barBorder: Color {
        Color(hex: Config.shared.barBorderHex)
    }

    /// Fallback text color for views and nodes that do not provide one.
    static var defaultTextColor: Color {
        Color.white
    }

    /// Border color for the focused app icon inside the spaces widget.
    static var spaceFocusedAppBorder: Color {
        Color(hex: Config.shared.spaceFocusedAppBorderHex)
    }

    static var spaceActiveBackground: Color {
        Color(hex: Config.shared.spaceActiveBackgroundHex)
    }

    static var spaceInactiveBackground: Color {
        Color(hex: Config.shared.spaceInactiveBackgroundHex)
    }

    static var spaceActiveBorder: Color {
        Color(hex: Config.shared.spaceActiveBorderHex)
    }

    static var spaceInactiveBorder: Color {
        Color(hex: Config.shared.spaceInactiveBorderHex)
    }

    static var spaceFocusedText: Color {
        Color(hex: Config.shared.spaceFocusedTextHex)
    }

    static var spaceInactiveText: Color {
        Color(hex: Config.shared.spaceInactiveTextHex)
    }
}
