import Foundation
import TOMLKit

extension Config {

  /// Battery color mode.
  enum BuiltinBatteryColorMode: String {
    case dynamic
    case fixed
  }

  /// Battery percentage display mode.
  enum BuiltinBatteryDisplayMode: String {
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
        textColorHex: "#ffffff",
        backgroundColorHex: "#00000000",
        borderColorHex: "#00000000",
        borderWidth: 0,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 0,
        spacing: 10,
        opacity: 1
      ),
      content: .init(
        unavailableText: "n/a",
        iconSize: 18,
        colorMode: .dynamic,
        fixedColorHex: "#8aadf4",
        displayMode: .expand,
        colors: .init(
          highColorHex: "#8bd5ca",
          mediumColorHex: "#eed49f",
          lowColorHex: "#f5a97f",
          criticalColorHex: "#ed8796"
        )
      ),
      popup: .init(
        textColorHex: "#ffffff",
        backgroundColorHex: "#111111",
        borderColorHex: "#444444",
        borderWidth: 1,
        cornerRadius: 8,
        paddingX: 8,
        paddingY: 6,
        marginX: 0,
        marginY: 8
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
      colorMode: normalizedBatteryColorMode(
        try optionalString(
          table["color_mode"],
          path: "builtins.battery.content.color_mode"
        ) ?? fallback.colorMode.rawValue
      ),
      fixedColorHex: try optionalString(
        table["fixed_color"],
        path: "builtins.battery.content.fixed_color"
      ) ?? fallback.fixedColorHex,
      displayMode: normalizedBatteryDisplayMode(
        try optionalString(
          table["display_mode"],
          path: "builtins.battery.content.display_mode"
        ) ?? fallback.displayMode.rawValue
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
      ) ?? fallback.criticalColorHex
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
