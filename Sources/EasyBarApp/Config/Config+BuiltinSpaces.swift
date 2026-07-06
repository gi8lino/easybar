import Foundation
import SwiftUI
import TOMLKit

extension Config {

  /// Built-in spaces widget config.
  struct SpacesBuiltinConfig {
    /// Spaces layout behavior settings.
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

    /// Spaces label text settings.
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

    /// Spaces app-icon settings.
    struct Icons {
      var size: Double
      var spacing: Double
      var cornerRadius: Double
      var focusedAppSize: Double
      var borderWidth: Double
      var focusedAppBorderWidth: Double
    }

    /// Spaces color settings.
    struct Colors {
      var activeBackgroundHex: String
      var inactiveBackgroundHex: String
      var activeBorderHex: String
      var inactiveBorderHex: String
      var focusedAppBorderHex: String
    }

    /// Shared placement settings.
    var placement: BuiltinWidgetPlacement
    /// Shared visual style settings.
    var style: BuiltinWidgetStyle
    /// Layout behavior settings.
    var layout: Layout
    /// Text style settings.
    var text: Text
    /// Icon style settings.
    var icons: Icons
    /// Color settings.
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

    /// Default spaces widget config.
    static let `default` = SpacesBuiltinConfig(
      placement: .init(
        enabled: true,
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
      spacing: try optionalField(
        .number("spacing"), from: table, path: "builtins.spaces.layout", fallback: fallback.spacing),
      hideEmpty: try optionalField(
        .bool("hide_empty"), from: table, path: "builtins.spaces.layout", fallback: fallback.hideEmpty),
      paddingX: try optionalField(
        .number("padding_x"), from: table, path: "builtins.spaces.layout", fallback: fallback.paddingX),
      paddingY: try optionalField(
        .number("padding_y"), from: table, path: "builtins.spaces.layout", fallback: fallback.paddingY),
      marginX: try optionalField(
        .number("margin_x"), from: table, path: "builtins.spaces.layout", fallback: fallback.marginX),
      marginY: try optionalField(
        .number("margin_y"), from: table, path: "builtins.spaces.layout", fallback: fallback.marginY),
      cornerRadius: try optionalField(
        .number("corner_radius"), from: table, path: "builtins.spaces.layout", fallback: fallback.cornerRadius),
      focusedCornerRadius: try optionalField(
        .number("focused_corner_radius"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.focusedCornerRadius
      ),
      focusedScale: try optionalField(
        .number("focused_scale"), from: table, path: "builtins.spaces.layout", fallback: fallback.focusedScale),
      inactiveOpacity: try optionalField(
        .number("inactive_opacity"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.inactiveOpacity
      ),
      maxIcons: try optionalField(
        .int("max_icons"), from: table, path: "builtins.spaces.layout", fallback: fallback.maxIcons),
      showLabel: try optionalField(
        .bool("show_label"), from: table, path: "builtins.spaces.layout", fallback: fallback.showLabel),
      showIcons: try optionalField(
        .bool("show_icons"), from: table, path: "builtins.spaces.layout", fallback: fallback.showIcons),
      showOnlyFocusedLabel: try optionalField(
        .bool("show_only_focused_label"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.showOnlyFocusedLabel
      ),
      collapseInactive: try optionalField(
        .bool("collapse_inactive"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.collapseInactive
      ),
      collapsedPaddingX: try optionalField(
        .number("collapsed_padding_x"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.collapsedPaddingX
      ),
      collapsedPaddingY: try optionalField(
        .number("collapsed_padding_y"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.collapsedPaddingY
      ),
      clickToFocusSpace: try optionalField(
        .bool("click_to_focus_space"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.clickToFocusSpace
      ),
      clickToFocusApp: try optionalField(
        .bool("click_to_focus_app"),
        from: table,
        path: "builtins.spaces.layout",
        fallback: fallback.clickToFocusApp
      )
    )
  }

  /// Parses the spaces text block.
  fileprivate func parseSpacesText(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Text
  ) throws -> SpacesBuiltinConfig.Text {
    SpacesBuiltinConfig.Text(
      size: try optionalField(.number("size"), from: table, path: "builtins.spaces.text", fallback: fallback.size),
      weight: try validatedSpacesTextWeight(
        try optionalField(.string("weight"), from: table, path: "builtins.spaces.text", fallback: fallback.weight),
        path: "builtins.spaces.text.weight"
      ),
      focusedColorHex: try optionalField(
        .string("focused_color"),
        from: table,
        path: "builtins.spaces.text",
        fallback: fallback.focusedColorHex
      ),
      inactiveColorHex: try optionalField(
        .string("inactive_color"),
        from: table,
        path: "builtins.spaces.text",
        fallback: fallback.inactiveColorHex
      )
    )
  }

  /// Parses the spaces icons block.
  fileprivate func parseSpacesIcons(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Icons
  ) throws -> SpacesBuiltinConfig.Icons {
    SpacesBuiltinConfig.Icons(
      size: try optionalField(.number("size"), from: table, path: "builtins.spaces.icons", fallback: fallback.size),
      spacing: try optionalField(
        .number("spacing"), from: table, path: "builtins.spaces.icons", fallback: fallback.spacing),
      cornerRadius: try optionalField(
        .number("corner_radius"),
        from: table,
        path: "builtins.spaces.icons",
        fallback: fallback.cornerRadius
      ),
      focusedAppSize: try optionalField(
        .number("focused_app_size"),
        from: table,
        path: "builtins.spaces.icons",
        fallback: fallback.focusedAppSize
      ),
      borderWidth: try optionalField(
        .number("border_width"),
        from: table,
        path: "builtins.spaces.icons",
        fallback: fallback.borderWidth
      ),
      focusedAppBorderWidth: try optionalField(
        .number("focused_app_border_width"),
        from: table,
        path: "builtins.spaces.icons",
        fallback: fallback.focusedAppBorderWidth
      )
    )
  }

  /// Parses the spaces colors block.
  fileprivate func parseSpacesColors(
    from table: TOMLTable,
    fallback: SpacesBuiltinConfig.Colors
  ) throws -> SpacesBuiltinConfig.Colors {
    SpacesBuiltinConfig.Colors(
      activeBackgroundHex: try optionalField(
        .string("active_background"),
        from: table,
        path: "builtins.spaces.colors",
        fallback: fallback.activeBackgroundHex
      ),
      inactiveBackgroundHex: try optionalField(
        .string("inactive_background"),
        from: table,
        path: "builtins.spaces.colors",
        fallback: fallback.inactiveBackgroundHex
      ),
      activeBorderHex: try optionalField(
        .string("active_border"),
        from: table,
        path: "builtins.spaces.colors",
        fallback: fallback.activeBorderHex
      ),
      inactiveBorderHex: try optionalField(
        .string("inactive_border"),
        from: table,
        path: "builtins.spaces.colors",
        fallback: fallback.inactiveBorderHex
      ),
      focusedAppBorderHex: try optionalField(
        .string("focused_app_border"),
        from: table,
        path: "builtins.spaces.colors",
        fallback: fallback.focusedAppBorderHex
      )
    )
  }
}
