import Foundation
import TOMLKit

extension Config {

  /// Battery color mode.
  enum BuiltinBatteryColorMode: String, CaseIterable {
    case dynamic
    case fixed
  }

  /// Battery percentage display mode.
  enum BuiltinBatteryDisplayMode: String, CaseIterable {
    case none
    case tooltip
    case expand
    case always
  }

  /// Battery severity colors.
  struct BuiltinBatteryColors {
    var highColorHex: String
    var mediumColorHex: String
    var lowColorHex: String
    var criticalColorHex: String
    var frameColorHex: String
    var chargingOverlayColorHex: String
    var externalPowerOverlayColorHex: String
    var onHoldOverlayColorHex: String
    var unavailableColorHex: String
  }

  /// Battery hover popup style used for `display_mode = "tooltip"`.
  struct BuiltinBatteryPopup {
    var textColorHex: String?
    var backgroundColorHex: String
    var borderColorHex: String
    var borderWidth: Double
    var cornerRadius: Double
    var paddingX: Double
    var paddingY: Double
    var marginX: Double
    var marginY: Double
  }

  /// Built-in battery widget config.
  struct BatteryBuiltinConfig {

    struct Content {
      var unavailableText: String
      var iconSize: Double
      var colorMode: BuiltinBatteryColorMode
      var fixedColorHex: String?
      var displayMode: BuiltinBatteryDisplayMode
      var colors: BuiltinBatteryColors
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var content: Content
    var popup: BuiltinBatteryPopup

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

    var unavailableText: String {
      get { content.unavailableText }
      set { content.unavailableText = newValue }
    }

    var iconSize: Double {
      get { content.iconSize }
      set { content.iconSize = newValue }
    }

    var colorMode: BuiltinBatteryColorMode {
      get { content.colorMode }
      set { content.colorMode = newValue }
    }

    var fixedColorHex: String? {
      get { content.fixedColorHex }
      set { content.fixedColorHex = newValue }
    }

    var displayMode: BuiltinBatteryDisplayMode {
      get { content.displayMode }
      set { content.displayMode = newValue }
    }

    var colors: BuiltinBatteryColors {
      get { content.colors }
      set { content.colors = newValue }
    }

    static let `default` = BatteryBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 20,
        group: nil
      ),
      style: .init(
        icon: "🔋",
        textColorHex: "#cdd6f4",
        backgroundColorHex: "#00000000",
        borderColorHex: "#00000000",
        borderWidth: 0,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 4,
        paddingY: 0,
        spacing: 6,
        opacity: 1
      ),
      content: .init(
        unavailableText: "n/a",
        iconSize: 18,
        colorMode: .fixed,
        fixedColorHex: "#cdd6f4",
        displayMode: .expand,
        colors: .init(
          highColorHex: "#a6e3a1",
          mediumColorHex: "#f9e2af",
          lowColorHex: "#fab387",
          criticalColorHex: "#f38ba8",
          frameColorHex: "#6c7086",
          chargingOverlayColorHex: "#FFFFFFFF",
          externalPowerOverlayColorHex: "#FFFFFFFF",
          onHoldOverlayColorHex: "#FFFFFFFF",
          unavailableColorHex: "#6c7086"
        )
      ),
      popup: .init(
        textColorHex: Config.builtinPopupDefaultTextColorHex,
        backgroundColorHex: Config.builtinPopupDefaultBackgroundColorHex,
        borderColorHex: Config.builtinPopupDefaultBorderColorHex,
        borderWidth: Config.builtinPopupDefaultBorderWidth,
        cornerRadius: Config.builtinPopupDefaultCornerRadius,
        paddingX: Config.builtinPopupDefaultPaddingX,
        paddingY: Config.builtinPopupDefaultPaddingY,
        marginX: Config.builtinPopupDefaultMarginX,
        marginY: Config.builtinPopupDefaultMarginY
      )
    )
  }

  /// Parses the built-in battery widget.
  func parseBatteryBuiltin(from builtins: TOMLTable) throws {
    guard let battery = builtins["battery"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: battery,
      path: "builtins.battery",
      fallback: builtinBattery.placement
    )

    let styleTable = battery["style"]?.table ?? TOMLTable()
    let contentTable = battery["content"]?.table ?? TOMLTable()
    let colorsTable = battery["colors"]?.table ?? TOMLTable()
    let tooltipTable = battery["tooltip"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.battery.style",
      fallback: builtinBattery.style
    )

    let content = try parseBatteryContent(
      from: contentTable,
      colorsTable: colorsTable,
      fallback: builtinBattery.content
    )
    let popup = try parseBatteryPopup(from: tooltipTable, fallback: builtinBattery.popup)

    builtinBattery = BatteryBuiltinConfig(
      placement: placement,
      style: style,
      content: content,
      popup: popup
    )
  }
}

extension Config {
  /// Parses the battery content and severity color settings.
  fileprivate func parseBatteryContent(
    from table: TOMLTable,
    colorsTable: TOMLTable,
    fallback: BatteryBuiltinConfig.Content
  ) throws -> BatteryBuiltinConfig.Content {
    BatteryBuiltinConfig.Content(
      unavailableText: try optionalString(
        table["unavailable_text"],
        path: "builtins.battery.content.unavailable_text"
      ) ?? fallback.unavailableText,
      iconSize: try optionalNumber(
        table["icon_size"],
        path: "builtins.battery.content.icon_size"
      ) ?? fallback.iconSize,
      colorMode: try parseBatteryColorMode(
        try optionalString(
          table["color_mode"],
          path: "builtins.battery.content.color_mode"
        ) ?? fallback.colorMode.rawValue,
        path: "builtins.battery.content.color_mode"
      ),
      fixedColorHex: try optionalString(
        table["fixed_color"],
        path: "builtins.battery.content.fixed_color"
      ) ?? fallback.fixedColorHex,
      displayMode: try parseBatteryDisplayMode(
        try optionalString(
          table["display_mode"],
          path: "builtins.battery.content.display_mode"
        ) ?? fallback.displayMode.rawValue,
        path: "builtins.battery.content.display_mode"
      ),
      colors: try parseBatteryColors(from: colorsTable, fallback: fallback.colors)
    )
  }

  /// Parses the battery severity color settings.
  fileprivate func parseBatteryColors(
    from table: TOMLTable,
    fallback: BuiltinBatteryColors
  ) throws -> BuiltinBatteryColors {
    BuiltinBatteryColors(
      highColorHex: try optionalString(table["high"], path: "builtins.battery.colors.high")
        ?? fallback.highColorHex,
      mediumColorHex: try optionalString(table["medium"], path: "builtins.battery.colors.medium")
        ?? fallback.mediumColorHex,
      lowColorHex: try optionalString(table["low"], path: "builtins.battery.colors.low")
        ?? fallback.lowColorHex,
      criticalColorHex: try optionalString(
        table["critical"],
        path: "builtins.battery.colors.critical"
      ) ?? fallback.criticalColorHex,
      frameColorHex: try optionalString(table["frame"], path: "builtins.battery.colors.frame")
        ?? fallback.frameColorHex,
      chargingOverlayColorHex: try optionalString(
        table["charging_overlay"],
        path: "builtins.battery.colors.charging_overlay"
      ) ?? fallback.chargingOverlayColorHex,
      externalPowerOverlayColorHex: try optionalString(
        table["external_power_overlay"],
        path: "builtins.battery.colors.external_power_overlay"
      ) ?? fallback.externalPowerOverlayColorHex,
      onHoldOverlayColorHex: try optionalString(
        table["on_hold_overlay"],
        path: "builtins.battery.colors.on_hold_overlay"
      ) ?? fallback.onHoldOverlayColorHex,
      unavailableColorHex: try optionalString(
        table["unavailable"],
        path: "builtins.battery.colors.unavailable"
      ) ?? fallback.unavailableColorHex
    )
  }

  /// Parses the battery tooltip settings.
  fileprivate func parseBatteryPopup(
    from table: TOMLTable,
    fallback: BuiltinBatteryPopup
  ) throws -> BuiltinBatteryPopup {
    BuiltinBatteryPopup(
      textColorHex: try optionalString(
        table["text_color"],
        path: "builtins.battery.tooltip.text_color"
      ) ?? fallback.textColorHex,
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.battery.tooltip.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.battery.tooltip.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.battery.tooltip.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.battery.tooltip.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.battery.tooltip.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.battery.tooltip.padding_y"
      ) ?? fallback.paddingY,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.battery.tooltip.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.battery.tooltip.margin_y"
      ) ?? fallback.marginY
    )
  }
}
