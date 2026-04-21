import Foundation
import TOMLKit

extension Config {
  static let builtinPopupDefaultTextColorHex = "#cdd6f4"
  static let builtinPopupDefaultBackgroundColorHex = "#111111"
  static let builtinPopupDefaultBorderColorHex = "#444444"
  static let builtinPopupDefaultBorderWidth = 1.0
  static let builtinPopupDefaultCornerRadius = 8.0
  static let builtinPopupDefaultPaddingX = 8.0
  static let builtinPopupDefaultPaddingY = 6.0
  static let builtinPopupDefaultMarginX = 0.0
  static let builtinPopupDefaultMarginY = 8.0

  /// Shared placement block for built-in widgets.
  struct BuiltinWidgetPlacement {
    var enabled: Bool
    var position: WidgetPosition
    var order: Int
    var group: String? = nil

    /// Returns the configured native group parent when present.
    var groupID: String? {
      guard let group else { return nil }

      let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }

      return trimmed
    }
  }

  /// Shared style block for built-in widgets.
  struct BuiltinWidgetStyle {
    var icon: String
    var textColorHex: String?
    var backgroundColorHex: String?
    var borderColorHex: String?
    var borderWidth: Double
    var cornerRadius: Double
    var marginX: Double
    var marginY: Double
    var paddingX: Double
    var paddingY: Double
    var spacing: Double
    var opacity: Double
  }

  /// Parses all built-in widget sections.
  func parseBuiltins(from toml: TOMLTable) throws {
    guard let builtins = toml["builtins"]?.table else { return }

    try parseBuiltinGroups(from: builtins)
    try parseCPUBuiltin(from: builtins)
    try parseBatteryBuiltin(from: builtins)
    try parseSpacesBuiltin(from: builtins)
    try parseFrontAppBuiltin(from: builtins)
    try parseAeroSpaceModeBuiltin(from: builtins)
    try parseVolumeBuiltin(from: builtins)
    try parseWiFiBuiltin(from: builtins)
    try parseDateBuiltin(from: builtins)
    try parseTimeBuiltin(from: builtins)
    try parseCalendarBuiltin(from: builtins)
  }
}
