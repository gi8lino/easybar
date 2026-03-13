import SwiftUI

/// Global color theme
enum Theme {

    static var barBackground: Color {
        Color(hex: Config.shared.barBackgroundHex)
    }

    static var barBorder: Color {
        Color(hex: Config.shared.barBorderHex)
    }

    static var textColor: Color {
        Color(hex: Config.shared.textColorHex)
    }

    static var focusedAppBorder: Color {
        Color(hex: Config.shared.focusedAppBorderHex)
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
