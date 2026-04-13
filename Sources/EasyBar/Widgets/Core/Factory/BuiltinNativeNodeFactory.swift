import Foundation

enum BuiltinNativeNodeFactory {

  // MARK: - Public Builders

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

  /// Builds one root sparkline node.
  static func makeSparklineNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    text: String,
    values: [Double],
    lineWidth: Double,
    color: String?
  ) -> WidgetNodeState {
    var node = makeRootNode(
      id: rootID,
      kind: .sparkline,
      placement: placement,
      style: style,
      icon: style.icon,
      text: text,
      color: color
    )

    node.values = values
    node.lineWidth = lineWidth
    return node
  }

  /// Builds one root spaces node.
  static func makeSpacesNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .spaces,
      placement: placement,
      style: style,
      icon: "",
      text: "",
      color: style.textColorHex
    )
  }

  /// Builds one native group root node.
  static func makeGroupNode(
    id: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    var node = makeRootNode(
      id: id,
      kind: .group,
      placement: placement,
      style: style,
      icon: "",
      text: "",
      color: style.textColorHex
    )
    // Native groups are layout containers; letting them own hover surfaces
    // interferes with hover-driven children such as tooltip widgets.
    node.receivesMouseHover = false
    node.receivesMouseClick = false
    node.receivesMouseScroll = false
    return node
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

  /// Builds one root popup node.
  static func makePopupRootNode(
    rootID: String,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle
  ) -> WidgetNodeState {
    makeRootNode(
      id: rootID,
      kind: .popup,
      placement: placement,
      style: style
    )
  }

  /// Builds one child column node.
  static func makeColumnNode(
    rootID: String,
    parentID: String,
    columnID: String,
    position: WidgetPosition,
    order: Int,
    spacing: Double?
  ) -> WidgetNodeState {
    makeChildNode(
      id: columnID,
      root: rootID,
      kind: .column,
      parent: parentID,
      position: position,
      order: order,
      spacing: spacing
    )
  }

  /// Builds one popup anchor row attached to the popup root.
  static func makePopupAnchorRowNode(
    rootID: String,
    anchorID: String,
    position: WidgetPosition,
    spacing: Double? = 4
  ) -> WidgetNodeState {
    makeChildNode(
      id: anchorID,
      root: rootID,
      kind: .row,
      parent: rootID,
      position: position,
      order: 0,
      visible: true,
      role: .popupAnchor,
      paddingX: 0,
      paddingY: 0,
      spacing: spacing,
      opacity: 1
    )
  }

  /// Builds one popup content column attached to the popup root.
  static func makePopupContentColumnNode(
    rootID: String,
    contentID: String,
    position: WidgetPosition,
    order: Int = 0,
    visible: Bool = true,
    paddingX: Double? = 0,
    paddingY: Double? = 0,
    spacing: Double? = 4,
    backgroundColor: String? = nil,
    borderColor: String? = nil,
    borderWidth: Double? = nil,
    cornerRadius: Double? = nil,
    opacity: Double? = 1
  ) -> WidgetNodeState {
    makeChildNode(
      id: contentID,
      root: rootID,
      kind: .column,
      parent: rootID,
      position: position,
      order: order,
      visible: visible,
      role: .popupContent,
      paddingX: paddingX,
      paddingY: paddingY,
      spacing: spacing,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      opacity: opacity
    )
  }

  /// Builds one simple spacer item.
  static func makeSpacerNode(
    rootID: String,
    spacerID: String,
    parentID: String?,
    position: WidgetPosition,
    order: Int,
    visible: Bool = false,
    paddingX: Double? = 0,
    paddingY: Double? = 0,
    opacity: Double? = 1
  ) -> WidgetNodeState {
    makeNode(
      id: spacerID,
      root: rootID,
      kind: .item,
      parent: parentID,
      position: position,
      order: order,
      icon: "",
      text: "",
      color: nil,
      visible: visible,
      paddingX: paddingX,
      paddingY: paddingY,
      opacity: opacity
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
    symbolName: String? = nil,
    symbolSecondaryColor: String? = nil,
    symbolOverlayName: String? = nil,
    symbolOverlayColor: String? = nil,
    symbolOverlayBackdropColor: String? = nil,
    symbolOverlayScale: Double? = nil,
    symbolOverlayBackdropScale: Double? = nil,
    symbolOverlayOffsetX: Double? = nil,
    symbolOverlayOffsetY: Double? = nil,
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
      symbolName: symbolName,
      symbolSecondaryColor: symbolSecondaryColor,
      symbolOverlayName: symbolOverlayName,
      symbolOverlayColor: symbolOverlayColor,
      symbolOverlayBackdropColor: symbolOverlayBackdropColor,
      symbolOverlayScale: symbolOverlayScale,
      symbolOverlayBackdropScale: symbolOverlayBackdropScale,
      symbolOverlayOffsetX: symbolOverlayOffsetX,
      symbolOverlayOffsetY: symbolOverlayOffsetY,
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

  // MARK: - Internal Builders

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
    role: WidgetNodeRole? = nil,
    imagePath: String? = nil,
    imageSize: Double? = nil,
    imageCornerRadius: Double? = nil,
    symbolName: String? = nil,
    symbolSecondaryColor: String? = nil,
    symbolOverlayName: String? = nil,
    symbolOverlayColor: String? = nil,
    symbolOverlayBackdropColor: String? = nil,
    symbolOverlayScale: Double? = nil,
    symbolOverlayBackdropScale: Double? = nil,
    symbolOverlayOffsetX: Double? = nil,
    symbolOverlayOffsetY: Double? = nil,
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
      role: role,
      imagePath: imagePath,
      imageSize: imageSize,
      imageCornerRadius: imageCornerRadius,
      symbolName: symbolName,
      symbolSecondaryColor: symbolSecondaryColor,
      symbolOverlayName: symbolOverlayName,
      symbolOverlayColor: symbolOverlayColor,
      symbolOverlayBackdropColor: symbolOverlayBackdropColor,
      symbolOverlayScale: symbolOverlayScale,
      symbolOverlayBackdropScale: symbolOverlayBackdropScale,
      symbolOverlayOffsetX: symbolOverlayOffsetX,
      symbolOverlayOffsetY: symbolOverlayOffsetY,
      fontSize: fontSize,
      iconFontSize: iconFontSize,
      labelFontSize: labelFontSize,
      value: value,
      min: min,
      max: max,
      step: step,
      paddingX: paddingX,
      paddingY: paddingY,
      marginX: marginX,
      marginY: marginY,
      spacing: spacing,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      opacity: opacity
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
    role: WidgetNodeRole? = nil,
    imagePath: String? = nil,
    imageSize: Double? = nil,
    imageCornerRadius: Double? = nil,
    symbolName: String? = nil,
    symbolSecondaryColor: String? = nil,
    symbolOverlayName: String? = nil,
    symbolOverlayColor: String? = nil,
    symbolOverlayBackdropColor: String? = nil,
    symbolOverlayScale: Double? = nil,
    symbolOverlayBackdropScale: Double? = nil,
    symbolOverlayOffsetX: Double? = nil,
    symbolOverlayOffsetY: Double? = nil,
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
      role: role,
      receivesMouseHover: nil,
      receivesMouseClick: nil,
      receivesMouseScroll: nil,
      imagePath: imagePath,
      imageSize: imageSize,
      imageCornerRadius: imageCornerRadius,
      symbolName: symbolName,
      symbolSecondaryColor: symbolSecondaryColor,
      symbolOverlayName: symbolOverlayName,
      symbolOverlayColor: symbolOverlayColor,
      symbolOverlayBackdropColor: symbolOverlayBackdropColor,
      symbolOverlayScale: symbolOverlayScale,
      symbolOverlayBackdropScale: symbolOverlayBackdropScale,
      symbolOverlayOffsetX: symbolOverlayOffsetX,
      symbolOverlayOffsetY: symbolOverlayOffsetY,
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
      marginLeft: nil,
      marginRight: nil,
      marginTop: nil,
      marginBottom: nil,
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
