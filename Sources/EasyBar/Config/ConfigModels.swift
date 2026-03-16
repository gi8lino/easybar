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

        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var spacing: Double
        var opacity: Double
    }

    struct CPUBuiltinConfig {
        struct Content {
            var label: String
            var historySize: Int
            var lineWidth: Double
            var colorHex: String?
        }

        var style: BuiltinWidgetStyle
        var content: Content

        var label: String {
            get { content.label }
            set { content.label = newValue }
        }

        var historySize: Int {
            get { content.historySize }
            set { content.historySize = newValue }
        }

        var lineWidth: Double {
            get { content.lineWidth }
            set { content.lineWidth = newValue }
        }

        var colorHex: String? {
            get { content.colorHex }
            set { content.colorHex = newValue }
        }
    }

    struct BatteryBuiltinConfig {
        struct Content {
            var unavailableText: String
            var showPercentage: Bool
        }

        var style: BuiltinWidgetStyle
        var content: Content

        // Compatibility accessors.
        var unavailableText: String {
            get { content.unavailableText }
            set { content.unavailableText = newValue }
        }

        var showPercentage: Bool {
            get { content.showPercentage }
            set { content.showPercentage = newValue }
        }
    }

    struct SpacesBuiltinConfig {
        struct Layout {
            var spacing: Double
            var hideEmpty: Bool
            var paddingX: Double
            var paddingY: Double
            var cornerRadius: Double
            var focusedScale: Double
            var inactiveOpacity: Double
            var maxIcons: Int
            var showNumber: Bool
            var showIcons: Bool
            var showOnlyFocusedLabel: Bool
            var collapseInactive: Bool
            var collapsedPaddingX: Double
            var collapsedPaddingY: Double
        }

        struct Text {
            var size: Double
            var weight: String
            var focusedColorHex: String
            var inactiveColorHex: String
        }

        struct Icons {
            var size: Double
            var spacing: Double
            var cornerRadius: Double
            var focusedSize: Double
            var borderWidth: Double
            var focusedBorderWidth: Double
        }

        struct Colors {
            var activeBackgroundHex: String
            var inactiveBackgroundHex: String
            var activeBorderHex: String
            var inactiveBorderHex: String
        }

        var style: BuiltinWidgetStyle
        var layout: Layout
        var text: Text
        var icons: Icons
        var colors: Colors
    }

    struct FrontAppBuiltinConfig {
        struct Content {
            var showIcon: Bool
            var showName: Bool
            var fallbackText: String
            var iconSize: Double
            var iconCornerRadius: Double
        }

        var style: BuiltinWidgetStyle
        var content: Content

        var showIcon: Bool {
            get { content.showIcon }
            set { content.showIcon = newValue }
        }

        var showName: Bool {
            get { content.showName }
            set { content.showName = newValue }
        }

        var fallbackText: String {
            get { content.fallbackText }
            set { content.fallbackText = newValue }
        }

        var iconSize: Double {
            get { content.iconSize }
            set { content.iconSize = newValue }
        }

        var iconCornerRadius: Double {
            get { content.iconCornerRadius }
            set { content.iconCornerRadius = newValue }
        }
    }

    struct VolumeBuiltinConfig {
        struct Content {
            var mutedIcon: String
            var lowIcon: String
            var highIcon: String
            var showPercentage: Bool
            var minValue: Double
            var maxValue: Double
            var step: Double
        }

        struct Slider {
            var expandToSliderOnHover: Bool
            var width: Double
        }

        var style: BuiltinWidgetStyle
        var content: Content
        var slider: Slider

        var mutedIcon: String {
            get { content.mutedIcon }
            set { content.mutedIcon = newValue }
        }

        var lowIcon: String {
            get { content.lowIcon }
            set { content.lowIcon = newValue }
        }

        var highIcon: String {
            get { content.highIcon }
            set { content.highIcon = newValue }
        }

        var showPercentage: Bool {
            get { content.showPercentage }
            set { content.showPercentage = newValue }
        }

        var minValue: Double {
            get { content.minValue }
            set { content.minValue = newValue }
        }

        var maxValue: Double {
            get { content.maxValue }
            set { content.maxValue = newValue }
        }

        var step: Double {
            get { content.step }
            set { content.step = newValue }
        }

        var expandToSliderOnHover: Bool {
            get { slider.expandToSliderOnHover }
            set { slider.expandToSliderOnHover = newValue }
        }

        var sliderWidth: Double {
            get { slider.width }
            set { slider.width = newValue }
        }
    }

    struct DateBuiltinConfig {
        struct Content {
            var format: String
        }

        var style: BuiltinWidgetStyle
        var content: Content

        var format: String {
            get { content.format }
            set { content.format = newValue }
        }
    }

    struct TimeBuiltinConfig {
        struct Content {
            var format: String
        }

        var style: BuiltinWidgetStyle
        var content: Content

        var format: String {
            get { content.format }
            set { content.format = newValue }
        }
    }

    struct CalendarBuiltinConfig {
        struct Anchor {
            var format: String
            var layout: String
            var topFormat: String
            var bottomFormat: String
            var lineSpacing: Double
            var topTextColorHex: String?
            var bottomTextColorHex: String?
        }

        struct Events {
            var days: Int
            var emptyText: String
        }

        struct Birthdays {
            var show: Bool
            var title: String
            var dateFormat: String
            var showAge: Bool
        }

        struct Popup {
            var backgroundColorHex: String
            var borderColorHex: String
            var borderWidth: Double
            var cornerRadius: Double
            var paddingX: Double
            var paddingY: Double
            var spacing: Double
            var itemIndent: Double
            var sectionTitleColorHex: String
            var itemColorHex: String
            var emptyColorHex: String
        }

        var style: BuiltinWidgetStyle
        var anchor: Anchor
        var events: Events
        var birthdays: Birthdays
        var popup: Popup

        var format: String {
            get { anchor.format }
            set { anchor.format = newValue }
        }

        var layout: String {
            get { anchor.layout }
            set { anchor.layout = newValue }
        }

        var topFormat: String {
            get { anchor.topFormat }
            set { anchor.topFormat = newValue }
        }

        var bottomFormat: String {
            get { anchor.bottomFormat }
            set { anchor.bottomFormat = newValue }
        }

        var lineSpacing: Double {
            get { anchor.lineSpacing }
            set { anchor.lineSpacing = newValue }
        }

        var topTextColorHex: String? {
            get { anchor.topTextColorHex }
            set { anchor.topTextColorHex = newValue }
        }

        var bottomTextColorHex: String? {
            get { anchor.bottomTextColorHex }
            set { anchor.bottomTextColorHex = newValue }
        }

        var days: Int {
            get { events.days }
            set { events.days = newValue }
        }

        var emptyText: String {
            get { events.emptyText }
            set { events.emptyText = newValue }
        }

        var showBirthdays: Bool {
            get { birthdays.show }
            set { birthdays.show = newValue }
        }

        var birthdaysTitle: String {
            get { birthdays.title }
            set { birthdays.title = newValue }
        }

        var birthdaysDateFormat: String {
            get { birthdays.dateFormat }
            set { birthdays.dateFormat = newValue }
        }

        var birthdaysShowAge: Bool {
            get { birthdays.showAge }
            set { birthdays.showAge = newValue }
        }

        var popupBackgroundColorHex: String {
            get { popup.backgroundColorHex }
            set { popup.backgroundColorHex = newValue }
        }

        var popupBorderColorHex: String {
            get { popup.borderColorHex }
            set { popup.borderColorHex = newValue }
        }

        var popupBorderWidth: Double {
            get { popup.borderWidth }
            set { popup.borderWidth = newValue }
        }

        var popupCornerRadius: Double {
            get { popup.cornerRadius }
            set { popup.cornerRadius = newValue }
        }

        var popupPaddingX: Double {
            get { popup.paddingX }
            set { popup.paddingX = newValue }
        }

        var popupPaddingY: Double {
            get { popup.paddingY }
            set { popup.paddingY = newValue }
        }

        var popupSpacing: Double {
            get { popup.spacing }
            set { popup.spacing = newValue }
        }

        var popupItemIndent: Double {
            get { popup.itemIndent }
            set { popup.itemIndent = newValue }
        }

        var popupSectionTitleColorHex: String {
            get { popup.sectionTitleColorHex }
            set { popup.sectionTitleColorHex = newValue }
        }

        var popupItemColorHex: String {
            get { popup.itemColorHex }
            set { popup.itemColorHex = newValue }
        }

        var popupEmptyColorHex: String {
            get { popup.emptyColorHex }
            set { popup.emptyColorHex = newValue }
        }
    }
}
