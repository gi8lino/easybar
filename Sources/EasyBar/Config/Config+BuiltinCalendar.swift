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
      var showCalendarName: Bool
      var useCalendarColors: Bool
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

    var popupShowCalendarName: Bool {
      get { popup.showCalendarName }
      set { popup.showCalendarName = newValue }
    }

    var popupUseCalendarColors: Bool {
      get { popup.useCalendarColors }
      set { popup.useCalendarColors = newValue }
    }

    static let `default` = CalendarBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 60
      ),
      style: .init(
        icon: "",
        textColorHex: "#ffffff",
        backgroundColorHex: "#1a1a1a",
        borderColorHex: "#333333",
        borderWidth: 1,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 4,
        spacing: 6,
        opacity: 1
      ),
      anchor: .init(
        itemFormat: "EEE, MMM d",
        layout: .stack,
        topFormat: "HH:mm",
        bottomFormat: "d. MMM",
        lineSpacing: 0,
        topTextColorHex: "#ffffff",
        bottomTextColorHex: "#d0d0d0"
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
        backgroundColorHex: "#111111",
        borderColorHex: "#444444",
        borderWidth: 1,
        cornerRadius: 10,
        paddingX: 10,
        paddingY: 8,
        spacing: 8,
        itemIndent: 8,
        marginX: 8,
        marginY: 8,
        showCalendarName: true,
        useCalendarColors: true,
        birthdays: .init(
          titleColorHex: "#89CFEF",
          itemColorHex: "#7285A5",
          emptyColorHex: "#c0c0c0"
        ),
        today: .init(
          titleColorHex: "#5F9EA0",
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

    let anchor = try parseCalendarAnchor(
      from: anchorTable,
      fallback: builtinCalendar.anchor
    )

    let events = try parseCalendarEvents(
      from: eventsTable,
      fallback: builtinCalendar.events
    )

    let birthdays = try parseCalendarBirthdays(
      from: birthdaysTable,
      fallback: builtinCalendar.birthdays
    )

    let popup = try parseCalendarPopup(
      from: popupTable,
      fallback: builtinCalendar.popup
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

  /// Parses the calendar anchor block.
  private func parseCalendarAnchor(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try optionalString(
        table["item_format"],
        path: "builtins.calendar.anchor.item_format"
      ) ?? fallback.itemFormat,
      layout: normalizedCalendarLayout(
        try optionalString(
          table["layout"],
          path: "builtins.calendar.anchor.layout"
        ) ?? fallback.layout.rawValue
      ),
      topFormat: try optionalString(
        table["top_format"],
        path: "builtins.calendar.anchor.top_format"
      ) ?? fallback.topFormat,
      bottomFormat: try optionalString(
        table["bottom_format"],
        path: "builtins.calendar.anchor.bottom_format"
      ) ?? fallback.bottomFormat,
      lineSpacing: try optionalNumber(
        table["line_spacing"],
        path: "builtins.calendar.anchor.line_spacing"
      ) ?? fallback.lineSpacing,
      topTextColorHex: try optionalString(
        table["top_text_color"],
        path: "builtins.calendar.anchor.top_text_color"
      ) ?? fallback.topTextColorHex,
      bottomTextColorHex: try optionalString(
        table["bottom_text_color"],
        path: "builtins.calendar.anchor.bottom_text_color"
      ) ?? fallback.bottomTextColorHex
    )
  }

  /// Parses the calendar events block.
  private func parseCalendarEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Events
  ) throws -> CalendarBuiltinConfig.Events {
    CalendarBuiltinConfig.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "builtins.calendar.events.days"
        ) ?? fallback.days
      ),
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.events.empty_text"
      ) ?? fallback.emptyText
    )
  }

  /// Parses the calendar birthdays block.
  private func parseCalendarBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      show: try optionalBool(
        table["show"],
        path: "builtins.calendar.birthdays.show"
      ) ?? fallback.show,
      title: try optionalString(
        table["title"],
        path: "builtins.calendar.birthdays.title"
      ) ?? fallback.title,
      dateFormat: try optionalString(
        table["date_format"],
        path: "builtins.calendar.birthdays.date_format"
      ) ?? fallback.dateFormat,
      showAge: try optionalBool(
        table["show_age"],
        path: "builtins.calendar.birthdays.show_age"
      ) ?? fallback.showAge
    )
  }

  /// Parses the calendar popup block.
  private func parseCalendarPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Popup
  ) throws -> CalendarBuiltinConfig.Popup {
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let todayTable = table["today"]?.table ?? TOMLTable()
    let tomorrowTable = table["tomorrow"]?.table ?? TOMLTable()
    let futureTable = table["future"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.popup.margin_y"
      ) ?? fallback.marginY,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.popup.show_calendar_name"
      ) ?? fallback.showCalendarName,
      useCalendarColors: try optionalBool(
        table["use_calendar_colors"],
        path: "builtins.calendar.popup.use_calendar_colors"
      ) ?? fallback.useCalendarColors,
      birthdays: try parseCalendarPopupSectionStyle(
        from: birthdaysTable,
        path: "builtins.calendar.popup.birthdays",
        fallback: fallback.birthdays
      ),
      today: try parseCalendarPopupSectionStyle(
        from: todayTable,
        path: "builtins.calendar.popup.today",
        fallback: fallback.today
      ),
      tomorrow: try parseCalendarPopupSectionStyle(
        from: tomorrowTable,
        path: "builtins.calendar.popup.tomorrow",
        fallback: fallback.tomorrow
      ),
      future: try parseCalendarPopupSectionStyle(
        from: futureTable,
        path: "builtins.calendar.popup.future",
        fallback: fallback.future
      )
    )
  }

  /// Parses one popup section style block.
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
