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

    let layout = try parseSpacesLayout(from: layoutTable, fallback: builtinSpaces.layout)
    let text = try parseSpacesText(from: textTable, fallback: builtinSpaces.text)
    let icons = try parseSpacesIcons(from: iconsTable, fallback: builtinSpaces.icons)
    let colors = try parseSpacesColors(from: colorsTable, fallback: builtinSpaces.colors)

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

extension Config {
  /// Parses the spaces layout block.
  fileprivate func parseSpacesLayout(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Layout
  ) throws -> SpacesBuiltinConfig.Layout {
    SpacesBuiltinConfig.Layout(
      spacing: try optionalNumber(table["spacing"], path: "builtins.spaces.layout.spacing")
        ?? fallback.spacing,
      hideEmpty: try optionalBool(table["hide_empty"], path: "builtins.spaces.layout.hide_empty")
        ?? fallback.hideEmpty,
      paddingX: try optionalNumber(table["padding_x"], path: "builtins.spaces.layout.padding_x")
        ?? fallback.paddingX,
      paddingY: try optionalNumber(table["padding_y"], path: "builtins.spaces.layout.padding_y")
        ?? fallback.paddingY,
      marginX: try optionalNumber(table["margin_x"], path: "builtins.spaces.layout.margin_x")
        ?? fallback.marginX,
      marginY: try optionalNumber(table["margin_y"], path: "builtins.spaces.layout.margin_y")
        ?? fallback.marginY,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.spaces.layout.corner_radius"
      ) ?? fallback.cornerRadius,
      focusedCornerRadius: try optionalNumber(
        table["focused_corner_radius"],
        path: "builtins.spaces.layout.focused_corner_radius"
      ) ?? fallback.focusedCornerRadius,
      focusedScale: try optionalNumber(
        table["focused_scale"],
        path: "builtins.spaces.layout.focused_scale"
      ) ?? fallback.focusedScale,
      inactiveOpacity: try optionalNumber(
        table["inactive_opacity"],
        path: "builtins.spaces.layout.inactive_opacity"
      ) ?? fallback.inactiveOpacity,
      maxIcons: try optionalInt(table["max_icons"], path: "builtins.spaces.layout.max_icons")
        ?? fallback.maxIcons,
      showLabel: try optionalBool(table["show_label"], path: "builtins.spaces.layout.show_label")
        ?? fallback.showLabel,
      showIcons: try optionalBool(table["show_icons"], path: "builtins.spaces.layout.show_icons")
        ?? fallback.showIcons,
      showOnlyFocusedLabel: try optionalBool(
        table["show_only_focused_label"],
        path: "builtins.spaces.layout.show_only_focused_label"
      ) ?? fallback.showOnlyFocusedLabel,
      collapseInactive: try optionalBool(
        table["collapse_inactive"],
        path: "builtins.spaces.layout.collapse_inactive"
      ) ?? fallback.collapseInactive,
      collapsedPaddingX: try optionalNumber(
        table["collapsed_padding_x"],
        path: "builtins.spaces.layout.collapsed_padding_x"
      ) ?? fallback.collapsedPaddingX,
      collapsedPaddingY: try optionalNumber(
        table["collapsed_padding_y"],
        path: "builtins.spaces.layout.collapsed_padding_y"
      ) ?? fallback.collapsedPaddingY,
      clickToFocusSpace: try optionalBool(
        table["click_to_focus_space"],
        path: "builtins.spaces.layout.click_to_focus_space"
      ) ?? fallback.clickToFocusSpace,
      clickToFocusApp: try optionalBool(
        table["click_to_focus_app"],
        path: "builtins.spaces.layout.click_to_focus_app"
      ) ?? fallback.clickToFocusApp
    )
  }

  /// Parses the spaces text block.
  fileprivate func parseSpacesText(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Text
  ) throws -> SpacesBuiltinConfig.Text {
    SpacesBuiltinConfig.Text(
      size: try optionalNumber(table["size"], path: "builtins.spaces.text.size")
        ?? fallback.size,
      weight: try optionalString(table["weight"], path: "builtins.spaces.text.weight")
        ?? fallback.weight,
      focusedColorHex: try optionalString(
        table["focused_color"],
        path: "builtins.spaces.text.focused_color"
      ) ?? fallback.focusedColorHex,
      inactiveColorHex: try optionalString(
        table["inactive_color"],
        path: "builtins.spaces.text.inactive_color"
      ) ?? fallback.inactiveColorHex
    )
  }

  /// Parses the spaces icons block.
  fileprivate func parseSpacesIcons(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Icons
  ) throws -> SpacesBuiltinConfig.Icons {
    SpacesBuiltinConfig.Icons(
      size: try optionalNumber(table["size"], path: "builtins.spaces.icons.size")
        ?? fallback.size,
      spacing: try optionalNumber(table["spacing"], path: "builtins.spaces.icons.spacing")
        ?? fallback.spacing,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.spaces.icons.corner_radius"
      ) ?? fallback.cornerRadius,
      focusedAppSize: try optionalNumber(
        table["focused_app_size"],
        path: "builtins.spaces.icons.focused_app_size"
      ) ?? fallback.focusedAppSize,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.spaces.icons.border_width"
      ) ?? fallback.borderWidth,
      focusedAppBorderWidth: try optionalNumber(
        table["focused_app_border_width"],
        path: "builtins.spaces.icons.focused_app_border_width"
      ) ?? fallback.focusedAppBorderWidth
    )
  }

  /// Parses the spaces colors block.
  fileprivate func parseSpacesColors(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Colors
  ) throws -> SpacesBuiltinConfig.Colors {
    SpacesBuiltinConfig.Colors(
      activeBackgroundHex: try optionalString(
        table["active_background"],
        path: "builtins.spaces.colors.active_background"
      ) ?? fallback.activeBackgroundHex,
      inactiveBackgroundHex: try optionalString(
        table["inactive_background"],
        path: "builtins.spaces.colors.inactive_background"
      ) ?? fallback.inactiveBackgroundHex,
      activeBorderHex: try optionalString(
        table["active_border"],
        path: "builtins.spaces.colors.active_border"
      ) ?? fallback.activeBorderHex,
      inactiveBorderHex: try optionalString(
        table["inactive_border"],
        path: "builtins.spaces.colors.inactive_border"
      ) ?? fallback.inactiveBorderHex,
      focusedAppBorderHex: try optionalString(
        table["focused_app_border"],
        path: "builtins.spaces.colors.focused_app_border"
      ) ?? fallback.focusedAppBorderHex
    )
  }
}
