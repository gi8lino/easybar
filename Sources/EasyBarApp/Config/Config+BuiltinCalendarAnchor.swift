import Foundation
import TOMLKit

extension Config {

  /// Parses the calendar anchor block.
  func parseCalendarAnchor(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try optionalString(
        table["item_format"],
        path: "builtins.calendar.anchor.item_format",
        fallback: fallback.itemFormat
      ),
      layout: try parseCalendarLayout(
        try optionalString(
          table["layout"],
          path: "builtins.calendar.anchor.layout",
          fallback: fallback.layout.rawValue
        ),
        path: "builtins.calendar.anchor.layout"
      ),
      topFormat: try optionalString(
        table["top_format"],
        path: "builtins.calendar.anchor.top_format",
        fallback: fallback.topFormat
      ),
      bottomFormat: try optionalString(
        table["bottom_format"],
        path: "builtins.calendar.anchor.bottom_format",
        fallback: fallback.bottomFormat
      ),
      lineSpacing: try optionalNumber(
        table["line_spacing"],
        path: "builtins.calendar.anchor.line_spacing",
        fallback: fallback.lineSpacing
      ),
      topTextColorHex: try optionalString(
        table["top_text_color"],
        path: "builtins.calendar.anchor.top_text_color",
        fallback: fallback.topTextColorHex
      ),
      bottomTextColorHex: try optionalString(
        table["bottom_text_color"],
        path: "builtins.calendar.anchor.bottom_text_color",
        fallback: fallback.bottomTextColorHex
      )
    )
  }
}
