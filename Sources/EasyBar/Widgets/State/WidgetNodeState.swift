import Foundation

struct WidgetNodeState: Identifiable, Codable, Equatable {
  let id: String
  let root: String
  let kind: WidgetNodeKind
  let parent: String?
  let position: WidgetPosition
  let order: Int

  var icon: String
  var text: String
  var color: String?
  var iconColor: String?
  var labelColor: String?
  var visible: Bool

  var role: WidgetNodeRole?
  var receivesMouseHover: Bool?
  var receivesMouseDown: Bool?
  var receivesMouseUp: Bool?
  var receivesMouseClick: Bool?
  var receivesMouseScroll: Bool?

  var imagePath: String?
  var imageSize: Double?
  var imageCornerRadius: Double?
  var symbolName: String?
  var symbolSecondaryColor: String?
  var symbolOverlayName: String?
  var symbolOverlayColor: String?
  var symbolOverlayBackdropColor: String?
  var symbolOverlayScale: Double?
  var symbolOverlayBackdropScale: Double?
  var symbolOverlayOffsetX: Double?
  var symbolOverlayOffsetY: Double?

  // Custom symbol fill metadata used for exact battery-percentage rendering.
  var symbolFillFraction: Double?
  var symbolFillWidthFactor: Double?
  var symbolFillHeightFactor: Double?
  var symbolFillOffsetXFactor: Double?
  var symbolFillOffsetYFactor: Double?
  var symbolFillCornerRadiusFactor: Double?
  var symbolFillMinimumVisibleWidthFactor: Double?
  var symbolCanvasWidthFactor: Double?
  var symbolCanvasHeightFactor: Double?

  var fontSize: Double?
  var iconFontSize: Double?
  var labelFontSize: Double?

  var value: Double?
  var min: Double?
  var max: Double?
  var step: Double?
  var values: [Double]?
  var lineWidth: Double?

  var paddingX: Double?
  var paddingY: Double?
  var paddingLeft: Double?
  var paddingRight: Double?
  var paddingTop: Double?
  var paddingBottom: Double?
  var marginX: Double? = nil
  var marginY: Double? = nil
  var marginLeft: Double? = nil
  var marginRight: Double? = nil
  var marginTop: Double? = nil
  var marginBottom: Double? = nil
  var spacing: Double?

  var backgroundColor: String?
  var borderColor: String?
  var borderWidth: Double?
  var cornerRadius: Double?
  var opacity: Double?

  var width: Double?
  var height: Double?
  var yOffset: Double?

  /// Returns whether this node is attached directly to the bar.
  var isTopLevel: Bool {
    parent == nil || parent == ""
  }

  /// Returns whether this node has a non-empty parent id.
  var hasParent: Bool {
    !isTopLevel
  }

  /// Returns whether this node is the built-in calendar root.
  var isCalendarRoot: Bool {
    root == "builtin_calendar"
  }

  /// Returns whether this node is a popup anchor child.
  var isPopupAnchor: Bool {
    role == .popupAnchor
  }

  /// Returns whether this node is popup content.
  var isPopupContent: Bool {
    role == .popupContent
  }

  /// Returns whether this node should own hover interactions.
  ///
  /// By default, only simple root items own hover. Container roots such as rows and groups
  /// should not implicitly take hover ownership because that blocks child item interaction
  /// surfaces rendered above/below them.
  var isMouseHoverInteractive: Bool {
    if let receivesMouseHover {
      return receivesMouseHover
    }

    return id == root && kind == .item
  }

  /// Returns whether this node should own mouse-down interactions.
  var isMouseDownInteractive: Bool {
    receivesMouseDown == true
  }

  /// Returns whether this node should own mouse-up interactions.
  var isMouseUpInteractive: Bool {
    receivesMouseUp == true
  }

  /// Returns whether this node should own click interactions.
  ///
  /// Child items inside scripted row/group containers should be clickable by default so Lua
  /// widgets can subscribe to item-specific click events without needing extra node flags.
  var isMouseClickInteractive: Bool {
    if let receivesMouseClick {
      return receivesMouseClick
    }

    return kind == .item
  }

  /// Returns whether this node should own scroll interactions.
  var isMouseScrollInteractive: Bool {
    receivesMouseScroll == true
  }
}
