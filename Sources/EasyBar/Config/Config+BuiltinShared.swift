import Foundation
import TOMLKit

extension Config {

    /// Shared placement block for built-in widgets.
    struct BuiltinWidgetPlacement {
        var enabled: Bool
        var position: WidgetPosition
        var order: Int
        var group: String? = nil

        /// Returns the configured native group parent when present.
        var groupID: String? {
            guard let group, !group.isEmpty else { return nil }
            return Config.shared.builtinGroups.contains { $0.id == group } ? group : nil
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
        try parseVolumeBuiltin(from: builtins)
        try parseWiFiBuiltin(from: builtins)
        try parseDateBuiltin(from: builtins)
        try parseTimeBuiltin(from: builtins)
        try parseCalendarBuiltin(from: builtins)
    }
}
