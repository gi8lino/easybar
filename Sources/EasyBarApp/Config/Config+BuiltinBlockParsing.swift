import Foundation

extension Config {
  /// Parses one shared built-in placement block.
  func parseBuiltinPlacement(
    reader: ConfigReader,
    fallback: BuiltinWidgetPlacement,
    allowGroupReference: Bool = true
  ) throws -> BuiltinWidgetPlacement {
    let rawGroup = try reader.optionalString("group", fallback: fallback.group)

    return BuiltinWidgetPlacement(
      enabled: try reader.bool("enabled", fallback: fallback.enabled),
      position: try reader.widgetPosition("position", fallback: fallback.position),
      order: try reader.int("order", fallback: fallback.order),
      group: try validatedBuiltinGroupReference(
        rawGroup,
        path: reader.path(for: "group"),
        allowGroupReference: allowGroupReference
      )
    )
  }

  /// Parses one shared built-in widget style block.
  func parseBuiltinStyle(
    reader: ConfigReader,
    fallback: BuiltinWidgetStyle
  ) throws -> BuiltinWidgetStyle {
    BuiltinWidgetStyle(
      icon: try reader.string("icon", fallback: fallback.icon),
      textColorHex: try reader.optionalString("text_color", fallback: fallback.textColorHex),
      backgroundColorHex: try reader.optionalString(
        "background_color",
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try reader.optionalString("border_color", fallback: fallback.borderColorHex),
      borderWidth: try reader.double("border_width", fallback: fallback.borderWidth),
      cornerRadius: try reader.double("corner_radius", fallback: fallback.cornerRadius),
      marginX: try reader.double("margin_x", fallback: fallback.marginX),
      marginY: try reader.double("margin_y", fallback: fallback.marginY),
      paddingX: try reader.double("padding_x", fallback: fallback.paddingX),
      paddingY: try reader.double("padding_y", fallback: fallback.paddingY),
      spacing: try reader.double("spacing", fallback: fallback.spacing),
      opacity: try reader.double("opacity", fallback: fallback.opacity)
    )
  }

  /// Parses one shared tooltip-style popup block.
  func parseBuiltinPopupStyle(
    reader: ConfigReader,
    fallback: BuiltinPopupStyle
  ) throws -> BuiltinPopupStyle {
    BuiltinPopupStyle(
      textColorHex: try reader.optionalString("text_color", fallback: fallback.textColorHex),
      backgroundColorHex: try reader.string(
        "background_color", fallback: fallback.backgroundColorHex),
      borderColorHex: try reader.string("border_color", fallback: fallback.borderColorHex),
      borderWidth: try reader.double("border_width", fallback: fallback.borderWidth),
      cornerRadius: try reader.double("corner_radius", fallback: fallback.cornerRadius),
      paddingX: try reader.double("padding_x", fallback: fallback.paddingX),
      paddingY: try reader.double("padding_y", fallback: fallback.paddingY),
      marginX: try reader.double("margin_x", fallback: fallback.marginX),
      marginY: try reader.double("margin_y", fallback: fallback.marginY)
    )
  }
}
