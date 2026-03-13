import Foundation
import SwiftUI
import TOMLKit

/// Global EasyBar configuration loaded from ~/.config/easybar/config.toml
final class Config {

    static let shared = Config()

    var barHeight: CGFloat = 36
    var barPadding: CGFloat = 10

    var spaceSpacing: CGFloat = 8
    var hideEmptySpaces: Bool = true
    var spacePaddingX: CGFloat = 10
    var spacePaddingY: CGFloat = 6
    var spaceCornerRadius: CGFloat = 8
    var spaceFocusedScale: CGFloat = 1.0
    var spaceInactiveOpacity: Double = 0.85
    var maxIconsPerSpace: Int = 4
    var showSpaceNumber: Bool = true
    var showSpaceIcons: Bool = true
    var showOnlyFocusedLabel: Bool = false
    var collapseInactiveSpaces: Bool = false
    var collapsedSpacePaddingX: CGFloat = 6
    var collapsedSpacePaddingY: CGFloat = 4

    var spaceTextSize: CGFloat = 12
    var spaceTextWeight: String = "semibold"
    var spaceFocusedTextHex: String = "#ffffff"
    var spaceInactiveTextHex: String = "#d0d0d0"

    var iconSize: CGFloat = 14
    var iconSpacing: CGFloat = 4
    var iconCornerRadius: CGFloat = 3
    var focusedIconSize: CGFloat = 18
    var iconBorderWidth: CGFloat = 1
    var focusedIconBorderWidth: CGFloat = 1

    var barBackgroundHex: String = "#111111"
    var barBorderHex: String = "#222222"
    var textColorHex: String = "#ffffff"
    var spaceActiveBackgroundHex: String = "#2b2b2b"
    var spaceInactiveBackgroundHex: String = "#1a1a1a"
    var spaceActiveBorderHex: String = "#444444"
    var spaceInactiveBorderHex: String = "#00000000"
    var focusedAppBorderHex: String = "#ff3b30"

    var luaPath: String = "/usr/bin/lua"

    private init() {
        load()
    }

    /// Reloads configuration from disk.
    func reload() {
        Logger.info("reloading configuration")
        load()
    }

    /// Loads configuration from disk.
    private func load() {

        let configPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/config.toml")

        guard
            let data = try? Data(contentsOf: configPath),
            let text = String(data: data, encoding: .utf8)
        else {
            Logger.info("using default configuration")
            return
        }

        do {
            let toml = try TOMLTable(string: text)

            if let bar = toml["bar"]?.table {
                barHeight = CGFloat(bar["height"]?.int ?? Int(barHeight))
                barPadding = CGFloat(bar["padding"]?.int ?? Int(barPadding))
            }

            if let spaces = toml["spaces"]?.table {
                spaceSpacing = CGFloat(spaces["spacing"]?.int ?? Int(spaceSpacing))
                hideEmptySpaces = spaces["hide_empty"]?.bool ?? hideEmptySpaces
                spacePaddingX = CGFloat(spaces["padding_x"]?.int ?? Int(spacePaddingX))
                spacePaddingY = CGFloat(spaces["padding_y"]?.int ?? Int(spacePaddingY))
                spaceCornerRadius = CGFloat(spaces["corner_radius"]?.int ?? Int(spaceCornerRadius))

                if let focusedScale = spaces["focused_scale"]?.double {
                    spaceFocusedScale = CGFloat(focusedScale)
                } else {
                    spaceFocusedScale = 1.0
                }

                spaceInactiveOpacity = spaces["inactive_opacity"]?.double ?? spaceInactiveOpacity
                maxIconsPerSpace = spaces["max_icons"]?.int ?? maxIconsPerSpace
                showSpaceNumber = spaces["show_number"]?.bool ?? showSpaceNumber
                showSpaceIcons = spaces["show_icons"]?.bool ?? showSpaceIcons
                showOnlyFocusedLabel = spaces["show_only_focused_label"]?.bool ?? showOnlyFocusedLabel
                collapseInactiveSpaces = spaces["collapse_inactive"]?.bool ?? collapseInactiveSpaces
                collapsedSpacePaddingX = CGFloat(spaces["collapsed_padding_x"]?.int ?? Int(collapsedSpacePaddingX))
                collapsedSpacePaddingY = CGFloat(spaces["collapsed_padding_y"]?.int ?? Int(collapsedSpacePaddingY))
            }

            if let spaceText = toml["space_text"]?.table {
                spaceTextSize = CGFloat(spaceText["size"]?.int ?? Int(spaceTextSize))
                spaceTextWeight = spaceText["weight"]?.string ?? spaceTextWeight
                spaceFocusedTextHex = spaceText["focused_color"]?.string ?? spaceFocusedTextHex
                spaceInactiveTextHex = spaceText["inactive_color"]?.string ?? spaceInactiveTextHex
            }

            if let icons = toml["icons"]?.table {
                iconSize = CGFloat(icons["size"]?.int ?? Int(iconSize))
                iconSpacing = CGFloat(icons["spacing"]?.int ?? Int(iconSpacing))
                iconCornerRadius = CGFloat(icons["corner_radius"]?.int ?? Int(iconCornerRadius))
                focusedIconSize = CGFloat(icons["focused_size"]?.int ?? Int(focusedIconSize))
                iconBorderWidth = CGFloat(icons["border_width"]?.int ?? Int(iconBorderWidth))
                focusedIconBorderWidth = CGFloat(icons["focused_border_width"]?.int ?? Int(focusedIconBorderWidth))
            }

            if let colors = toml["colors"]?.table {
                barBackgroundHex = colors["bar_background"]?.string ?? barBackgroundHex
                barBorderHex = colors["bar_border"]?.string ?? barBorderHex
                textColorHex = colors["text_color"]?.string ?? textColorHex
                spaceActiveBackgroundHex = colors["space_active_background"]?.string ?? spaceActiveBackgroundHex
                spaceInactiveBackgroundHex = colors["space_inactive_background"]?.string ?? spaceInactiveBackgroundHex
                spaceActiveBorderHex = colors["space_active_border"]?.string ?? spaceActiveBorderHex
                spaceInactiveBorderHex = colors["space_inactive_border"]?.string ?? spaceInactiveBorderHex
                focusedAppBorderHex = colors["focused_app_border"]?.string ?? focusedAppBorderHex
            }

            if let lua = toml["lua"]?.table {
                luaPath = lua["path"]?.string ?? luaPath
            }

        } catch {
            Logger.info("config parse error: \(error)")
        }
    }

    /// Returns the configured font weight for space labels.
    var resolvedSpaceTextWeight: Font.Weight {
        switch spaceTextWeight.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .semibold
        }
    }
}
