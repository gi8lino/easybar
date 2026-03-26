import Foundation
import TOMLKit

extension Config {

    /// Shared placement block for built-in widgets.
    struct BuiltinWidgetPlacement {
        var enabled: Bool
        var position: WidgetPosition
        var order: Int
        var parent: String? = nil
    }

    /// Shared style block for built-in widgets.
    struct BuiltinWidgetStyle {
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

    /// Parses all built-in widget sections.
    func parseBuiltins(from toml: TOMLTable) throws {
        guard let builtins = toml["builtins"]?.table else { return }

        try parseCPUBuiltin(from: builtins)
        try parseBatteryBuiltin(from: builtins)
        try parseSpacesBuiltin(from: builtins)
        try parseFrontAppBuiltin(from: builtins)
        try parseVolumeBuiltin(from: builtins)
        try parseWiFiBuiltin(from: builtins)
        try parseDateBuiltin(from: builtins)
        try parseTimeBuiltin(from: builtins)
        try parseCalendarBuiltin(from: builtins)
    }
}
