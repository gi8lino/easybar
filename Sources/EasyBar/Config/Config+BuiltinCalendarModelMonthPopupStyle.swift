import Foundation

extension Config.CalendarBuiltinConfig.Month.Popup {

  struct Style {
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
  }

  struct CalendarStyle {
    var showWeekNumbers: Bool
    var showEventIndicators: Bool
    var headerTextColorHex: String
    var weekdayTextColorHex: String
    var firstWeekday: Int?
    var weekdayFormat: String
    var weekdaySymbols: [String]?
    var resolvedWeekdaySymbols: [String]
    var dayTextColorHex: String
    var outsideMonthTextColorHex: String
    var todayCellBackgroundColorHex: String
    var todayCellBorderColorHex: String
    var todayCellBorderWidth: Double
    var indicatorColorHex: String
  }

  struct SelectionStyle {
    var selectedTextColorHex: String
    var selectedBackgroundColorHex: String
    var selectionDateFormat: String
    var selectionDateSeparator: String
    var allowsRangeSelection: Bool
    var resetSelectionOnThirdTap: Bool
  }
}
