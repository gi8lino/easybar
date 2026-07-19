import EasyBarConfigParsing
import Foundation

extension InboxGroupMode: TOMLStringDecodable {}
extension InboxSortMode: TOMLStringDecodable {}

extension Config {
  struct InboxBuiltinConfig: @unchecked Sendable {
    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var iconColorHex: String?
    var unreadCountColorHex: String?
    var groupBy: InboxGroupMode
    var sortBy: InboxSortMode
    var sortDescending: Bool
    var showUnreadCount: Bool
    var useInactiveStyleWhenRead: Bool
    var showWhenEmpty: Bool
    var showSourceActions: Bool
    var popupWidth: Int
    var popupMaxHeight: Int
    var inactiveIcon: String
    var inactiveColorHex: String?
    var popupBackgroundColorHex: String?
    var popupBorderColorHex: String?
    var popupTitleColorHex: String?
    var popupTextColorHex: String?
    var popupMutedColorHex: String?
    var popupItemBackgroundColorHex: String?
    var popupActionColorHex: String?
    var infoColorHex: String?
    var successColorHex: String?
    var warningColorHex: String?
    var errorColorHex: String?
    var maxItems: Int

    var enabled: Bool { placement.enabled }

    static let `default` = InboxBuiltinConfig(
      placement: .init(enabled: true, position: .right, order: 5),
      style: .init(
        icon: "󰂚",
        textColorHex: "theme.text_secondary",
        backgroundColorHex: "theme.transparent",
        borderColorHex: "theme.transparent",
        borderWidth: 0,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 7,
        paddingY: 3,
        spacing: 4,
        opacity: 1
      ),
      iconColorHex: "theme.text_secondary",
      unreadCountColorHex: "theme.accent",
      groupBy: .source,
      sortBy: .timestamp,
      sortDescending: true,
      showUnreadCount: true,
      useInactiveStyleWhenRead: true,
      showWhenEmpty: true,
      showSourceActions: true,
      popupWidth: 360,
      popupMaxHeight: 440,
      inactiveIcon: "󰂜",
      inactiveColorHex: "theme.muted",
      popupBackgroundColorHex: "theme.background",
      popupBorderColorHex: "theme.border_strong",
      popupTitleColorHex: "theme.text",
      popupTextColorHex: "theme.text_secondary",
      popupMutedColorHex: "theme.muted",
      popupItemBackgroundColorHex: "theme.surface",
      popupActionColorHex: "theme.accent",
      infoColorHex: "theme.accent",
      successColorHex: "theme.success",
      warningColorHex: "theme.warning",
      errorColorHex: "theme.error",
      maxItems: 100
    )
  }

  func parseInboxBuiltin(from builtins: ConfigReader) throws {
    guard let inbox = try builtins.optionalSection("inbox") else { return }
    let placement = try parseBuiltinPlacement(reader: inbox, fallback: builtinInbox.placement)
    let styleReader = try inbox.section("style")
    let style = try parseBuiltinStyle(reader: styleReader, fallback: builtinInbox.style)
    let content = try inbox.section("content")
    let colors = try inbox.optionalSection("colors")

    builtinInbox = InboxBuiltinConfig(
      placement: placement,
      style: style,
      iconColorHex: try styleReader.optionalColor("icon_color", fallback: style.textColorHex),
      unreadCountColorHex: try styleReader.optionalColor(
        "unread_count_color", fallback: builtinInbox.unreadCountColorHex),
      groupBy: try content.enum("group_by", fallback: builtinInbox.groupBy),
      sortBy: try content.enum("sort_by", fallback: builtinInbox.sortBy),
      sortDescending: try content.bool("sort_descending", fallback: builtinInbox.sortDescending),
      showUnreadCount: try content.bool("show_unread_count", fallback: builtinInbox.showUnreadCount),
      useInactiveStyleWhenRead: try content.bool(
        "use_inactive_style_when_read", fallback: builtinInbox.useInactiveStyleWhenRead),
      showWhenEmpty: try content.bool("show_when_empty", fallback: builtinInbox.showWhenEmpty),
      showSourceActions: try content.bool(
        "show_source_actions", fallback: builtinInbox.showSourceActions),
      popupWidth: try content.int(
        "popup_width", fallback: builtinInbox.popupWidth, minimum: 240, maximum: 800),
      popupMaxHeight: try content.int(
        "popup_max_height", fallback: builtinInbox.popupMaxHeight, minimum: 120, maximum: 1000),
      inactiveIcon: try content.string("inactive_icon", fallback: builtinInbox.inactiveIcon),
      inactiveColorHex: try content.optionalColor(
        "inactive_color", fallback: builtinInbox.inactiveColorHex),
      popupBackgroundColorHex: try colors?.optionalColor(
        "background", fallback: builtinInbox.popupBackgroundColorHex) ?? builtinInbox.popupBackgroundColorHex,
      popupBorderColorHex: try colors?.optionalColor("border", fallback: builtinInbox.popupBorderColorHex)
        ?? builtinInbox.popupBorderColorHex,
      popupTitleColorHex: try colors?.optionalColor("title", fallback: builtinInbox.popupTitleColorHex)
        ?? builtinInbox.popupTitleColorHex,
      popupTextColorHex: try colors?.optionalColor("text", fallback: builtinInbox.popupTextColorHex)
        ?? builtinInbox.popupTextColorHex,
      popupMutedColorHex: try colors?.optionalColor("muted", fallback: builtinInbox.popupMutedColorHex)
        ?? builtinInbox.popupMutedColorHex,
      popupItemBackgroundColorHex: try colors?.optionalColor(
        "item_background", fallback: builtinInbox.popupItemBackgroundColorHex)
        ?? builtinInbox.popupItemBackgroundColorHex,
      popupActionColorHex: try colors?.optionalColor("action", fallback: builtinInbox.popupActionColorHex)
        ?? builtinInbox.popupActionColorHex,
      infoColorHex: try colors?.optionalColor("info", fallback: builtinInbox.infoColorHex)
        ?? builtinInbox.infoColorHex,
      successColorHex: try colors?.optionalColor("success", fallback: builtinInbox.successColorHex)
        ?? builtinInbox.successColorHex,
      warningColorHex: try colors?.optionalColor("warning", fallback: builtinInbox.warningColorHex)
        ?? builtinInbox.warningColorHex,
      errorColorHex: try colors?.optionalColor("error", fallback: builtinInbox.errorColorHex)
        ?? builtinInbox.errorColorHex,
      maxItems: try content.int("max_items", fallback: builtinInbox.maxItems, minimum: 1, maximum: 1000)
    )
  }
}
