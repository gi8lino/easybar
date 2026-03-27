import Foundation
import SwiftUI
import TOMLKit

extension Config {

  /// Built-in spaces widget config.
  struct SpacesBuiltinConfig {
    struct Layout {
      var spacing: Double
      var hideEmpty: Bool
      var paddingX: Double
      var paddingY: Double
      var marginX: Double
      var marginY: Double
      var cornerRadius: Double
      var focusedCornerRadius: Double
      var focusedScale: Double
      var inactiveOpacity: Double
      var maxIcons: Int
      var showLabel: Bool
      var showIcons: Bool
      var showOnlyFocusedLabel: Bool
      var collapseInactive: Bool
      var collapsedPaddingX: Double
      var collapsedPaddingY: Double
      var clickToFocusSpace: Bool
      var clickToFocusApp: Bool
    }

    struct Text {
      var size: Double
      var weight: String
      var focusedColorHex: String
      var inactiveColorHex: String

      /// Resolved SwiftUI font weight.
      var resolvedWeight: Font.Weight {
        switch weight.lowercased() {
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

    struct Icons {
      var size: Double
      var spacing: Double
      var cornerRadius: Double
      var focusedAppSize: Double
      var borderWidth: Double
      var focusedAppBorderWidth: Double
    }

    struct Colors {
      var activeBackgroundHex: String
      var inactiveBackgroundHex: String
      var activeBorderHex: String
      var inactiveBorderHex: String
      var focusedAppBorderHex: String
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var layout: Layout
    var text: Text
    var icons: Icons
    var colors: Colors

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

    static let `default` = SpacesBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .left,
        order: 10
      ),
      style: .init(
        icon: "",
        textColorHex: "",
        backgroundColorHex: "#00000000",
        borderColorHex: "#00000000",
        borderWidth: 0,
        cornerRadius: 0,
        marginX: 0,
        marginY: 0,
        paddingX: 0,
        paddingY: 0,
        spacing: 0,
        opacity: 1
      ),
      layout: .init(
        spacing: 8,
        hideEmpty: true,
        paddingX: 12,
        paddingY: 2,
        marginX: 4,
        marginY: 4,
        cornerRadius: 8,
        focusedCornerRadius: 8,
        focusedScale: 1.0,
        inactiveOpacity: 0.85,
        maxIcons: 4,
        showLabel: true,
        showIcons: true,
        showOnlyFocusedLabel: false,
        collapseInactive: false,
        collapsedPaddingX: 6,
        collapsedPaddingY: 4,
        clickToFocusSpace: true,
        clickToFocusApp: true
      ),
      text: .init(
        size: 12,
        weight: "semibold",
        focusedColorHex: "#d0d0d0",
        inactiveColorHex: "#d0d0d0"
      ),
      icons: .init(
        size: 20,
        spacing: 4,
        cornerRadius: 3,
        focusedAppSize: 28,
        borderWidth: 1,
        focusedAppBorderWidth: 1
      ),
      colors: .init(
        activeBackgroundHex: "#2b2b2b",
        inactiveBackgroundHex: "#1a1a1a",
        activeBorderHex: "#444444",
        inactiveBorderHex: "#00000000",
        focusedAppBorderHex: "#00000000"
      )
    )
  }

  /// Parses the built-in spaces widget.
  func parseSpacesBuiltin(from builtins: TOMLTable) throws {
    guard let spaces = builtins["spaces"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: spaces,
      path: "builtins.spaces",
      fallback: builtinSpaces.placement
    )

    let layoutTable = spaces["layout"]?.table ?? TOMLTable()
    let textTable = spaces["text"]?.table ?? TOMLTable()
    let iconsTable = spaces["icons"]?.table ?? TOMLTable()
    let colorsTable = spaces["colors"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: spaces,
      path: "builtins.spaces",
      fallback: builtinSpaces.style
    )

    let layout = SpacesBuiltinConfig.Layout(
      spacing: try optionalNumber(
        layoutTable["spacing"],
        path: "builtins.spaces.layout.spacing"
      ) ?? builtinSpaces.layout.spacing,
      hideEmpty: try optionalBool(
        layoutTable["hide_empty"],
        path: "builtins.spaces.layout.hide_empty"
      ) ?? builtinSpaces.layout.hideEmpty,
      paddingX: try optionalNumber(
        layoutTable["padding_x"],
        path: "builtins.spaces.layout.padding_x"
      ) ?? builtinSpaces.layout.paddingX,
      paddingY: try optionalNumber(
        layoutTable["padding_y"],
        path: "builtins.spaces.layout.padding_y"
      ) ?? builtinSpaces.layout.paddingY,
      marginX: try optionalNumber(
        layoutTable["margin_x"],
        path: "builtins.spaces.layout.margin_x"
      ) ?? builtinSpaces.layout.marginX,
      marginY: try optionalNumber(
        layoutTable["margin_y"],
        path: "builtins.spaces.layout.margin_y"
      ) ?? builtinSpaces.layout.marginY,
      cornerRadius: try optionalNumber(
        layoutTable["corner_radius"],
        path: "builtins.spaces.layout.corner_radius"
      ) ?? builtinSpaces.layout.cornerRadius,
      focusedCornerRadius: try optionalNumber(
        layoutTable["focused_corner_radius"],
        path: "builtins.spaces.layout.focused_corner_radius"
      ) ?? builtinSpaces.layout.focusedCornerRadius,
      focusedScale: try optionalNumber(
        layoutTable["focused_scale"],
        path: "builtins.spaces.layout.focused_scale"
      ) ?? builtinSpaces.layout.focusedScale,
      inactiveOpacity: try optionalNumber(
        layoutTable["inactive_opacity"],
        path: "builtins.spaces.layout.inactive_opacity"
      ) ?? builtinSpaces.layout.inactiveOpacity,
      maxIcons: try optionalInt(
        layoutTable["max_icons"],
        path: "builtins.spaces.layout.max_icons"
      ) ?? builtinSpaces.layout.maxIcons,
      showLabel: try optionalBool(
        layoutTable["show_label"],
        path: "builtins.spaces.layout.show_label"
      ) ?? builtinSpaces.layout.showLabel,
      showIcons: try optionalBool(
        layoutTable["show_icons"],
        path: "builtins.spaces.layout.show_icons"
      ) ?? builtinSpaces.layout.showIcons,
      showOnlyFocusedLabel: try optionalBool(
        layoutTable["show_only_focused_label"],
        path: "builtins.spaces.layout.show_only_focused_label"
      ) ?? builtinSpaces.layout.showOnlyFocusedLabel,
      collapseInactive: try optionalBool(
        layoutTable["collapse_inactive"],
        path: "builtins.spaces.layout.collapse_inactive"
      ) ?? builtinSpaces.layout.collapseInactive,
      collapsedPaddingX: try optionalNumber(
        layoutTable["collapsed_padding_x"],
        path: "builtins.spaces.layout.collapsed_padding_x"
      ) ?? builtinSpaces.layout.collapsedPaddingX,
      collapsedPaddingY: try optionalNumber(
        layoutTable["collapsed_padding_y"],
        path: "builtins.spaces.layout.collapsed_padding_y"
      ) ?? builtinSpaces.layout.collapsedPaddingY,
      clickToFocusSpace: try optionalBool(
        layoutTable["click_to_focus_space"],
        path: "builtins.spaces.layout.click_to_focus_space"
      ) ?? builtinSpaces.layout.clickToFocusSpace,
      clickToFocusApp: try optionalBool(
        layoutTable["click_to_focus_app"],
        path: "builtins.spaces.layout.click_to_focus_app"
      ) ?? builtinSpaces.layout.clickToFocusApp
    )

    let text = SpacesBuiltinConfig.Text(
      size: try optionalNumber(
        textTable["size"],
        path: "builtins.spaces.text.size"
      ) ?? builtinSpaces.text.size,
      weight: try optionalString(
        textTable["weight"],
        path: "builtins.spaces.text.weight"
      ) ?? builtinSpaces.text.weight,
      focusedColorHex: try optionalString(
        textTable["focused_color"],
        path: "builtins.spaces.text.focused_color"
      ) ?? builtinSpaces.text.focusedColorHex,
      inactiveColorHex: try optionalString(
        textTable["inactive_color"],
        path: "builtins.spaces.text.inactive_color"
      ) ?? builtinSpaces.text.inactiveColorHex
    )

    let icons = SpacesBuiltinConfig.Icons(
      size: try optionalNumber(
        iconsTable["size"],
        path: "builtins.spaces.icons.size"
      ) ?? builtinSpaces.icons.size,
      spacing: try optionalNumber(
        iconsTable["spacing"],
        path: "builtins.spaces.icons.spacing"
      ) ?? builtinSpaces.icons.spacing,
      cornerRadius: try optionalNumber(
        iconsTable["corner_radius"],
        path: "builtins.spaces.icons.corner_radius"
      ) ?? builtinSpaces.icons.cornerRadius,
      focusedAppSize: try optionalNumber(
        iconsTable["focused_app_size"],
        path: "builtins.spaces.icons.focused_app_size"
      ) ?? builtinSpaces.icons.focusedAppSize,
      borderWidth: try optionalNumber(
        iconsTable["border_width"],
        path: "builtins.spaces.icons.border_width"
      ) ?? builtinSpaces.icons.borderWidth,
      focusedAppBorderWidth: try optionalNumber(
        iconsTable["focused_app_border_width"],
        path: "builtins.spaces.icons.focused_app_border_width"
      ) ?? builtinSpaces.icons.focusedAppBorderWidth
    )

    let colors = SpacesBuiltinConfig.Colors(
      activeBackgroundHex: try optionalString(
        colorsTable["active_background"],
        path: "builtins.spaces.colors.active_background"
      ) ?? builtinSpaces.colors.activeBackgroundHex,
      inactiveBackgroundHex: try optionalString(
        colorsTable["inactive_background"],
        path: "builtins.spaces.colors.inactive_background"
      ) ?? builtinSpaces.colors.inactiveBackgroundHex,
      activeBorderHex: try optionalString(
        colorsTable["active_border"],
        path: "builtins.spaces.colors.active_border"
      ) ?? builtinSpaces.colors.activeBorderHex,
      inactiveBorderHex: try optionalString(
        colorsTable["inactive_border"],
        path: "builtins.spaces.colors.inactive_border"
      ) ?? builtinSpaces.colors.inactiveBorderHex,
      focusedAppBorderHex: try optionalString(
        colorsTable["focused_app_border"],
        path: "builtins.spaces.colors.focused_app_border"
      ) ?? builtinSpaces.colors.focusedAppBorderHex
    )

    builtinSpaces = SpacesBuiltinConfig(
      placement: placement,
      style: style,
      layout: layout,
      text: text,
      icons: icons,
      colors: colors
    )
  }
}
