import Foundation
import SwiftUI
import TOMLKit

extension Config {

    func parsePaths(from toml: TOMLTable) {
        if let paths = toml["paths"]?.table,
           let configuredWidgetsPath = paths["widgets"]?.string,
           !configuredWidgetsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            widgetsPath = NSString(string: configuredWidgetsPath).expandingTildeInPath
        }
    }

    func parseBar(from toml: TOMLTable) {
        if let bar = toml["bar"]?.table {
            barHeight = CGFloat(bar["height"]?.int ?? Int(barHeight))
            barPadding = CGFloat(bar["padding"]?.int ?? Int(barPadding))
        }
    }

    func parseSpaces(from toml: TOMLTable) {
        if let spaces = toml["spaces"]?.table {
            spaceSpacing = CGFloat(spaces["spacing"]?.int ?? Int(spaceSpacing))
            hideEmptySpaces = spaces["hide_empty"]?.bool ?? hideEmptySpaces
            spacePaddingX = CGFloat(spaces["padding_x"]?.int ?? Int(spacePaddingX))
            spacePaddingY = CGFloat(spaces["padding_y"]?.int ?? Int(spacePaddingY))
            spaceCornerRadius = CGFloat(spaces["corner_radius"]?.int ?? Int(spaceCornerRadius))

            // Keep fractional scale supported.
            if let focusedScale = spaces["focused_scale"]?.double {
                spaceFocusedScale = CGFloat(focusedScale)
            } else if let focusedScale = spaces["focused_scale"]?.int {
                spaceFocusedScale = CGFloat(focusedScale)
            } else {
                spaceFocusedScale = 1.0
            }

            // Keep fractional opacity supported.
            if let inactiveOpacity = spaces["inactive_opacity"]?.double {
                spaceInactiveOpacity = inactiveOpacity
            } else if let inactiveOpacity = spaces["inactive_opacity"]?.int {
                spaceInactiveOpacity = Double(inactiveOpacity)
            }

            maxIconsPerSpace = spaces["max_icons"]?.int ?? maxIconsPerSpace
            showSpaceNumber = spaces["show_number"]?.bool ?? showSpaceNumber
            showSpaceIcons = spaces["show_icons"]?.bool ?? showSpaceIcons
            showOnlyFocusedLabel = spaces["show_only_focused_label"]?.bool ?? showOnlyFocusedLabel
            collapseInactiveSpaces = spaces["collapse_inactive"]?.bool ?? collapseInactiveSpaces
            collapsedSpacePaddingX = CGFloat(spaces["collapsed_padding_x"]?.int ?? Int(collapsedSpacePaddingX))
            collapsedSpacePaddingY = CGFloat(spaces["collapsed_padding_y"]?.int ?? Int(collapsedSpacePaddingY))
        }
    }

    func parseSpaceText(from toml: TOMLTable) {
        if let spaceText = toml["space_text"]?.table {
            spaceTextSize = CGFloat(spaceText["size"]?.int ?? Int(spaceTextSize))
            spaceTextWeight = spaceText["weight"]?.string ?? spaceTextWeight
            spaceFocusedTextHex = spaceText["focused_color"]?.string ?? spaceFocusedTextHex
            spaceInactiveTextHex = spaceText["inactive_color"]?.string ?? spaceInactiveTextHex
        }
    }

    func parseIcons(from toml: TOMLTable) {
        if let icons = toml["icons"]?.table {
            iconSize = CGFloat(icons["size"]?.int ?? Int(iconSize))
            iconSpacing = CGFloat(icons["spacing"]?.int ?? Int(iconSpacing))
            iconCornerRadius = CGFloat(icons["corner_radius"]?.int ?? Int(iconCornerRadius))
            focusedIconSize = CGFloat(icons["focused_size"]?.int ?? Int(focusedIconSize))
            iconBorderWidth = CGFloat(icons["border_width"]?.int ?? Int(iconBorderWidth))
            focusedIconBorderWidth = CGFloat(icons["focused_border_width"]?.int ?? Int(focusedIconBorderWidth))
        }
    }

    func parseColors(from toml: TOMLTable) {
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
    }

    func parseLua(from toml: TOMLTable) {
        if let lua = toml["lua"]?.table {
            luaPath = lua["path"]?.string ?? luaPath
        }
    }
}
