import Foundation

enum BuiltinNativeNodeFactory {

  /// Builds one simple root item node.
  static func makeItemNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    text: String
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .item,
      placement: placement,
      style: style,
      icon: style.icon,
      text: text,
      color: style.textColorHex
    )
  }

  /// Builds one simple root slider node.
  static func makeSliderNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    text: String,
    value: Double,
    min: Double,
    max: Double,
    step: Double
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .slider,
      placement: placement,
      style: style,
      icon: style.icon,
      text: text,
      color: style.textColorHex,
      value: value,
      min: min,
      max: max,
      step: step
    )
  }

  /// Builds one root row container node.
  static func makeRowContainerNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .row,
      placement: placement,
      style: style
    )
  }

  /// Builds one root column container node.
  static func makeColumnContainerNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .column,
      placement: placement,
      style: style
    )
  }

  /// Builds one child item node.
  static func makeChildItemNode(
    rootID: String,
    parentID: String,
    childID: String,
    position: WidgetPosition,
    order: Int,
    icon: String = "",
    text: String = "",
    color: String? = nil,
    visible: Bool = true,
    imagePath: String? = nil,
    imageSize: Double? = nil,
    imageCornerRadius: Double? = nil,
    fontSize: Double? = nil,
    iconFontSize: Double? = nil,
    labelFontSize: Double? = nil,
    spacing: Double? = 4
  ) -> WidgetNodeState {
    makeChildNode(
      id: childID,
      root: rootID,
      kind: .item,
      parent: parentID,
      position: position,
      order: order,
      icon: icon,
      text: text,
      color: color,
      visible: visible,
      imagePath: imagePath,
      imageSize: imageSize,
      imageCornerRadius: imageCornerRadius,
      fontSize: fontSize,
      iconFontSize: iconFontSize,
      labelFontSize: labelFontSize,
      spacing: spacing
    )
  }

  /// Builds one child slider node.
  static func makeChildSliderNode(
    rootID: String,
    parentID: String,
    childID: String,
    position: WidgetPosition,
    order: Int,
    value: Double,
    min: Double,
    max: Double,
    step: Double,
    color: String? = nil,
    visible: Bool = true
  ) -> WidgetNodeState {
    makeChildNode(
      id: childID,
      root: rootID,
      kind: .slider,
      parent: parentID,
      position: position,
      order: order,
      color: color,
      visible: visible,
      value: value,
      min: min,
      max: max,
      step: step
    )
  }

  /// Builds one root node with the shared built-in style defaults.
  private static func makeRootNode(
    id: String,
    kind: WidgetNodeKind,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    icon: String = "",
    text: String = "",
    color: String? = nil,
    value: Double? = nil,
    min: Double? = nil,
    max: Double? = nil,
    step: Double? = nil
  ) -> WidgetNodeState {
    makeNode(
      id: id,
      root: id,
      kind: kind,
      parent: placement.groupID,
      position: placement.position,
      order: placement.order,
      icon: icon,
      text: text,
      color: color,
      visible: true,
      imagePath: nil,
      imageSize: nil,
      imageCornerRadius: nil,
      fontSize: nil,
      iconFontSize: nil,
      labelFontSize: nil,
      value: value,
      min: min,
      max: max,
      step: step,
      paddingX: style.paddingX,
      paddingY: style.paddingY,
      marginX: style.marginX,
      marginY: style.marginY,
      spacing: style.spacing,
      backgroundColor: style.backgroundColorHex,
      borderColor: style.borderColorHex,
      borderWidth: style.borderWidth,
      cornerRadius: style.cornerRadius,
      opacity: style.opacity
    )
  }

  /// Builds one child node with the shared child defaults.
  private static func makeChildNode(
    id: String,
    root: String,
    kind: WidgetNodeKind,
    parent: String,
    position: WidgetPosition,
    order: Int,
    icon: String = "",
    text: String = "",
    color: String? = nil,
    visible: Bool = true,
    imagePath: String? = nil,
    imageSize: Double? = nil,
    imageCornerRadius: Double? = nil,
    fontSize: Double? = nil,
    iconFontSize: Double? = nil,
    labelFontSize: Double? = nil,
    value: Double? = nil,
    min: Double? = nil,
    max: Double? = nil,
    step: Double? = nil,
    spacing: Double? = 4
  ) -> WidgetNodeState {
    makeNode(
      id: id,
      root: root,
      kind: kind,
      parent: parent,
      position: position,
      order: order,
      icon: icon,
      text: text,
      color: color,
      visible: visible,
      imagePath: imagePath,
      imageSize: imageSize,
      imageCornerRadius: imageCornerRadius,
      fontSize: fontSize,
      iconFontSize: iconFontSize,
      labelFontSize: labelFontSize,
      value: value,
      min: min,
      max: max,
      step: step,
      spacing: spacing
    )
  }

  /// Builds one node with the shared built-in defaults applied.
  private static func makeNode(
    id: String,
    root: String,
    kind: WidgetNodeKind,
    parent: String?,
    position: WidgetPosition,
    order: Int,
    icon: String = "",
    text: String = "",
    color: String? = nil,
    visible: Bool = true,
    imagePath: String? = nil,
    imageSize: Double? = nil,
    imageCornerRadius: Double? = nil,
    fontSize: Double? = nil,
    iconFontSize: Double? = nil,
    labelFontSize: Double? = nil,
    value: Double? = nil,
    min: Double? = nil,
    max: Double? = nil,
    step: Double? = nil,
    paddingX: Double? = 0,
    paddingY: Double? = 0,
    marginX: Double? = nil,
    marginY: Double? = nil,
    spacing: Double? = 4,
    backgroundColor: String? = nil,
    borderColor: String? = nil,
    borderWidth: Double? = nil,
    cornerRadius: Double? = nil,
    opacity: Double? = 1
  ) -> WidgetNodeState {
    WidgetNodeState(
      id: id,
      root: root,
      kind: kind,
      parent: parent,
      position: position,
      order: order,
      icon: icon,
      text: text,
      color: color,
      iconColor: nil,
      labelColor: nil,
      visible: visible,
      role: nil,
      receivesMouseHover: nil,
      receivesMouseClick: nil,
      receivesMouseScroll: nil,
      imagePath: imagePath,
      imageSize: imageSize,
      imageCornerRadius: imageCornerRadius,
      fontSize: fontSize,
      iconFontSize: iconFontSize,
      labelFontSize: labelFontSize,
      value: value,
      min: min,
      max: max,
      step: step,
      values: nil,
      lineWidth: nil,
      paddingX: paddingX,
      paddingY: paddingY,
      paddingLeft: nil,
      paddingRight: nil,
      paddingTop: nil,
      paddingBottom: nil,
      marginX: marginX,
      marginY: marginY,
      spacing: spacing,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      opacity: opacity,
      width: nil,
      height: nil,
      yOffset: nil
    )
  }
}
