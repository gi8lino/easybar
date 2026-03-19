import Foundation
import TOMLKit

extension Config {

    /// Built-in calendar widget config.
    struct CalendarBuiltinConfig {
        struct Anchor {
            var itemFormat: String
            var layout: CalendarAnchorLayout
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

        struct PopupSectionStyle {
            var titleColorHex: String
            var itemColorHex: String
            var emptyColorHex: String
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
            var marginX: Double
            var marginY: Double
            var birthdays: PopupSectionStyle
            var today: PopupSectionStyle
            var tomorrow: PopupSectionStyle
            var future: PopupSectionStyle
        }

        var placement: BuiltinWidgetPlacement
        var style: BuiltinWidgetStyle
        var anchor: Anchor
        var events: Events
        var birthdays: Birthdays
        var popup: Popup

        var enabled: Bool {
            get { placement.enabled }
            set { placement.enabled = newValue }
        }

        var position: WidgetPosition {
            get { placement.position }
            set { placement.position = newValue }
        }

        var order: Int {
            get { placement.order }
            set { placement.order = newValue }
        }

        var itemFormat: String {
            get { anchor.itemFormat }
            set { anchor.itemFormat = newValue }
        }

        var layout: CalendarAnchorLayout {
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

        var popupMarginX: Double {
            get { popup.marginX }
            set { popup.marginX = newValue }
        }

        var popupMarginY: Double {
            get { popup.marginY }
            set { popup.marginY = newValue }
        }

        static let `default` = CalendarBuiltinConfig(
            placement: .init(
                enabled: false,
                position: .right,
                order: 50
            ),
            style: .init(
                icon: "",
                textColorHex: nil,
                backgroundColorHex: nil,
                borderColorHex: nil,
                borderWidth: 0,
                cornerRadius: 0,
                paddingX: 8,
                paddingY: 4,
                spacing: 6,
                opacity: 1
            ),
            anchor: .init(
                itemFormat: "EEE, MMM d",
                layout: .item,
                topFormat: "HH:mm",
                bottomFormat: "MMMM, d",
                lineSpacing: 0,
                topTextColorHex: nil,
                bottomTextColorHex: nil
            ),
            events: .init(
                days: 3,
                emptyText: "No upcoming events"
            ),
            birthdays: .init(
                show: true,
                title: "Birthdays",
                dateFormat: "dd.MM.yyyy",
                showAge: false
            ),
            popup: .init(
                backgroundColorHex: "#1a1a1a",
                borderColorHex: "#333333",
                borderWidth: 1,
                cornerRadius: 10,
                paddingX: 10,
                paddingY: 8,
                spacing: 8,
                itemIndent: 8,
                marginX: 8,
                marginY: 8,
                birthdays: .init(
                    titleColorHex: "#f5a97f",
                    itemColorHex: "#eed49f",
                    emptyColorHex: "#c0c0c0"
                ),
                today: .init(
                    titleColorHex: "#ffffff",
                    itemColorHex: "#d0d0d0",
                    emptyColorHex: "#c0c0c0"
                ),
                tomorrow: .init(
                    titleColorHex: "#8bd5ca",
                    itemColorHex: "#cfeee8",
                    emptyColorHex: "#c0c0c0"
                ),
                future: .init(
                    titleColorHex: "#91d7e3",
                    itemColorHex: "#d0d0d0",
                    emptyColorHex: "#c0c0c0"
                )
            )
        )
    }

    /// Parses the built-in calendar widget.
    func parseCalendarBuiltin(from builtins: TOMLTable) throws {
        guard let calendar = builtins["calendar"]?.table else { return }

        let placement = try parseBuiltinPlacement(
            from: calendar,
            path: "builtins.calendar",
            fallback: builtinCalendar.placement
        )

        let styleTable = calendar["style"]?.table ?? TOMLTable()
        let anchorTable = calendar["anchor"]?.table ?? TOMLTable()
        let eventsTable = calendar["events"]?.table ?? TOMLTable()
        let birthdaysTable = calendar["birthdays"]?.table ?? TOMLTable()
        let popupTable = calendar["popup"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.calendar.style",
            fallback: builtinCalendar.style
        )

        let anchor = CalendarBuiltinConfig.Anchor(
            itemFormat: try optionalString(
                anchorTable["item_format"],
                path: "builtins.calendar.anchor.item_format"
            ) ?? builtinCalendar.itemFormat,
            layout: normalizedCalendarLayout(
                try optionalString(
                    anchorTable["layout"],
                    path: "builtins.calendar.anchor.layout"
                ) ?? builtinCalendar.layout.rawValue
            ),
            topFormat: try optionalString(
                anchorTable["top_format"],
                path: "builtins.calendar.anchor.top_format"
            ) ?? builtinCalendar.topFormat,
            bottomFormat: try optionalString(
                anchorTable["bottom_format"],
                path: "builtins.calendar.anchor.bottom_format"
            ) ?? builtinCalendar.bottomFormat,
            lineSpacing: try optionalNumber(
                anchorTable["line_spacing"],
                path: "builtins.calendar.anchor.line_spacing"
            ) ?? builtinCalendar.lineSpacing,
            topTextColorHex: try optionalString(
                anchorTable["top_text_color"],
                path: "builtins.calendar.anchor.top_text_color"
            ) ?? builtinCalendar.topTextColorHex,
            bottomTextColorHex: try optionalString(
                anchorTable["bottom_text_color"],
                path: "builtins.calendar.anchor.bottom_text_color"
            ) ?? builtinCalendar.bottomTextColorHex
        )

        let events = CalendarBuiltinConfig.Events(
            days: max(
                1,
                try optionalInt(
                    eventsTable["days"],
                    path: "builtins.calendar.events.days"
                ) ?? builtinCalendar.days
            ),
            emptyText: try optionalString(
                eventsTable["empty_text"],
                path: "builtins.calendar.events.empty_text"
            ) ?? builtinCalendar.emptyText
        )

        let birthdays = CalendarBuiltinConfig.Birthdays(
            show: try optionalBool(
                birthdaysTable["show"],
                path: "builtins.calendar.birthdays.show"
            ) ?? builtinCalendar.showBirthdays,
            title: try optionalString(
                birthdaysTable["title"],
                path: "builtins.calendar.birthdays.title"
            ) ?? builtinCalendar.birthdaysTitle,
            dateFormat: try optionalString(
                birthdaysTable["date_format"],
                path: "builtins.calendar.birthdays.date_format"
            ) ?? builtinCalendar.birthdaysDateFormat,
            showAge: try optionalBool(
                birthdaysTable["show_age"],
                path: "builtins.calendar.birthdays.show_age"
            ) ?? builtinCalendar.birthdaysShowAge
        )

        let birthdaysPopupTable = popupTable["birthdays"]?.table ?? TOMLTable()
        let todayPopupTable = popupTable["today"]?.table ?? TOMLTable()
        let tomorrowPopupTable = popupTable["tomorrow"]?.table ?? TOMLTable()
        let futurePopupTable = popupTable["future"]?.table ?? TOMLTable()

        let popup = CalendarBuiltinConfig.Popup(
            backgroundColorHex: try optionalString(
                popupTable["background_color"],
                path: "builtins.calendar.popup.background_color"
            ) ?? builtinCalendar.popupBackgroundColorHex,
            borderColorHex: try optionalString(
                popupTable["border_color"],
                path: "builtins.calendar.popup.border_color"
            ) ?? builtinCalendar.popupBorderColorHex,
            borderWidth: try optionalNumber(
                popupTable["border_width"],
                path: "builtins.calendar.popup.border_width"
            ) ?? builtinCalendar.popupBorderWidth,
            cornerRadius: try optionalNumber(
                popupTable["corner_radius"],
                path: "builtins.calendar.popup.corner_radius"
            ) ?? builtinCalendar.popupCornerRadius,
            paddingX: try optionalNumber(
                popupTable["padding_x"],
                path: "builtins.calendar.popup.padding_x"
            ) ?? builtinCalendar.popupPaddingX,
            paddingY: try optionalNumber(
                popupTable["padding_y"],
                path: "builtins.calendar.popup.padding_y"
            ) ?? builtinCalendar.popupPaddingY,
            spacing: try optionalNumber(
                popupTable["spacing"],
                path: "builtins.calendar.popup.spacing"
            ) ?? builtinCalendar.popupSpacing,
            itemIndent: try optionalNumber(
                popupTable["item_indent"],
                path: "builtins.calendar.popup.item_indent"
            ) ?? builtinCalendar.popupItemIndent,
            marginX: try optionalNumber(
                popupTable["margin_x"],
                path: "builtins.calendar.popup.margin_x"
            ) ?? builtinCalendar.popupMarginX,
            marginY: try optionalNumber(
                popupTable["margin_y"],
                path: "builtins.calendar.popup.margin_y"
            ) ?? builtinCalendar.popupMarginY,
            birthdays: try parseCalendarPopupSectionStyle(
                from: birthdaysPopupTable,
                path: "builtins.calendar.popup.birthdays",
                fallback: builtinCalendar.popup.birthdays
            ),
            today: try parseCalendarPopupSectionStyle(
                from: todayPopupTable,
                path: "builtins.calendar.popup.today",
                fallback: builtinCalendar.popup.today
            ),
            tomorrow: try parseCalendarPopupSectionStyle(
                from: tomorrowPopupTable,
                path: "builtins.calendar.popup.tomorrow",
                fallback: builtinCalendar.popup.tomorrow
            ),
            future: try parseCalendarPopupSectionStyle(
                from: futurePopupTable,
                path: "builtins.calendar.popup.future",
                fallback: builtinCalendar.popup.future
            )
        )

        builtinCalendar = CalendarBuiltinConfig(
            placement: placement,
            style: style,
            anchor: anchor,
            events: events,
            birthdays: birthdays,
            popup: popup
        )
    }

    /// Parses one calendar popup section style block.
    private func parseCalendarPopupSectionStyle(
        from table: TOMLTable,
        path: String,
        fallback: CalendarBuiltinConfig.PopupSectionStyle
    ) throws -> CalendarBuiltinConfig.PopupSectionStyle {
        CalendarBuiltinConfig.PopupSectionStyle(
            titleColorHex: try optionalString(
                table["title_color"],
                path: "\(path).title_color"
            ) ?? fallback.titleColorHex,
            itemColorHex: try optionalString(
                table["item_color"],
                path: "\(path).item_color"
            ) ?? fallback.itemColorHex,
            emptyColorHex: try optionalString(
                table["empty_color"],
                path: "\(path).empty_color"
            ) ?? fallback.emptyColorHex
        )
    }
}
