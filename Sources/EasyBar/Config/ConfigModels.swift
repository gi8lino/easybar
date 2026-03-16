import Foundation

extension Config {

    struct BuiltinWidgetStyle {
        var enabled: Bool
        var position: String
        var order: Int

        var icon: String

        var textColorHex: String?
        var backgroundColorHex: String?
        var borderColorHex: String?

        // Runtime values.
        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var spacing: Double
        var opacity: Double
    }

    struct BatteryBuiltinConfig {
        var style: BuiltinWidgetStyle
        var chargingIcon: String
        var unavailableText: String
        var showPercentage: Bool
    }

    struct VolumeBuiltinConfig {
        var style: BuiltinWidgetStyle
        var mutedIcon: String
        var lowIcon: String
        var highIcon: String
        var showPercentage: Bool

        // Range values.
        var minValue: Double
        var maxValue: Double
        var step: Double

        var expandToSliderOnHover: Bool

        // Runtime width.
        var sliderWidth: Double
    }

    struct DateBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
    }

    struct TimeBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
    }

    struct CalendarBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
        var days: Int
        var emptyText: String

        var layout: String
        var topFormat: String
        var bottomFormat: String

        // Runtime values.
        var lineSpacing: Double

        var topTextColorHex: String?
        var bottomTextColorHex: String?

        var showBirthdays: Bool
        var birthdaysTitle: String
        var birthdaysDateFormat: String
        var birthdaysShowAge: Bool

        var popupBackgroundColorHex: String
        var popupBorderColorHex: String
        var popupBorderWidth: Double
        var popupCornerRadius: Double
        var popupPaddingX: Double
        var popupPaddingY: Double
        var popupSpacing: Double
        var popupItemIndent: Double
        var popupSectionTitleColorHex: String
        var popupItemColorHex: String
        var popupEmptyColorHex: String
    }
}
