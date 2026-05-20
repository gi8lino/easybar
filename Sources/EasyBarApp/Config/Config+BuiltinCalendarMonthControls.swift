import Foundation
import TOMLKit

extension Config {

  /// Parses the month popup anchor block.
  func parseCalendarMonthPopupAnchor(
    from anchorTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.AnchorStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.AnchorStyle {
    CalendarBuiltinConfig.Month.Popup.AnchorStyle(
      dateFormat: try optionalString(
        anchorTable["date_format"]
          ?? anchorTable["anchor_date_format"]
          ?? rootTable["anchor_date_format"],
        path: "builtins.calendar.month.popup.anchor.date_format"
      ) ?? fallback.dateFormat,
      textColorHex: try optionalString(
        anchorTable["text_color"]
          ?? anchorTable["anchor_text_color"]
          ?? rootTable["anchor_text_color"],
        path: "builtins.calendar.month.popup.anchor.text_color"
      ) ?? fallback.textColorHex,
      showDateText: try optionalBool(
        anchorTable["show_date_text"]
          ?? anchorTable["anchor_show_date_text"]
          ?? rootTable["anchor_show_date_text"],
        path: "builtins.calendar.month.popup.anchor.show_date_text"
      ) ?? fallback.showDateText
    )
  }

  /// Parses the month popup today-button block.
  func parseCalendarMonthPopupTodayButton(
    from todayButtonTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.TodayButtonStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.TodayButtonStyle {
    CalendarBuiltinConfig.Month.Popup.TodayButtonStyle(
      title: try optionalString(
        todayButtonTable["title"] ?? rootTable["today_button_title"],
        path: "builtins.calendar.month.popup.today_button.title"
      ) ?? fallback.title,
      icon: try optionalString(
        todayButtonTable["icon"] ?? rootTable["today_button_icon"],
        path: "builtins.calendar.month.popup.today_button.icon"
      ) ?? fallback.icon,
      borderColorHex: try optionalString(
        todayButtonTable["border_color"] ?? rootTable["today_border_color"],
        path: "builtins.calendar.month.popup.today_button.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        todayButtonTable["border_width"] ?? rootTable["today_border_width"],
        path: "builtins.calendar.month.popup.today_button.border_width"
      ) ?? fallback.borderWidth
    )
  }
}
