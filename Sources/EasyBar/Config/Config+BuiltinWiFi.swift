import Foundation
import TOMLKit

extension Config {

  enum BuiltinWiFiDisplayMode: String, CaseIterable {
    case none
    case tooltip
    case expand
    case always
  }

  struct BuiltinWiFiExpand {
    var textColorHex: String
  }

  struct WiFiBuiltinConfig {
    struct Content {
      var displayMode: BuiltinWiFiDisplayMode
      var disconnectedText: String
      var deniedText: String
      var activeColorHex: String
      var inactiveColorHex: String
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var content: Content
    var expand: BuiltinWiFiExpand
    var popup: BuiltinPopupStyle

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

    var displayMode: BuiltinWiFiDisplayMode {
      get { content.displayMode }
      set { content.displayMode = newValue }
    }

    var disconnectedText: String {
      get { content.disconnectedText }
      set { content.disconnectedText = newValue }
    }

    var deniedText: String {
      get { content.deniedText }
      set { content.deniedText = newValue }
    }

    var activeColorHex: String {
      get { content.activeColorHex }
      set { content.activeColorHex = newValue }
    }

    var inactiveColorHex: String {
      get { content.inactiveColorHex }
      set { content.inactiveColorHex = newValue }
    }

    var expandTextColorHex: String {
      get { expand.textColorHex }
      set { expand.textColorHex = newValue }
    }

    static let `default` = WiFiBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 30,
        group: nil
      ),
      style: .init(
        icon: "",
        textColorHex: "#ffffff",
        backgroundColorHex: "#00000000",
        borderColorHex: "#00000000",
        borderWidth: 0,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 0,
        spacing: 6,
        opacity: 1
      ),
      content: .init(
        displayMode: .tooltip,
        disconnectedText: "disconnected",
        deniedText: "denied",
        activeColorHex: "#cdd6f4",
        inactiveColorHex: "#6c7086"
      ),
      expand: .init(
        textColorHex: "#ffffff"
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

  func parseWiFiBuiltin(from builtins: TOMLTable) throws {
    guard let wifi = builtins["wifi"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: wifi,
      path: "builtins.wifi",
      fallback: builtinWiFi.placement
    )

    let styleTable = wifi["style"]?.table ?? TOMLTable()
    let contentTable = wifi["content"]?.table ?? TOMLTable()
    let expandTable = wifi["expand"]?.table ?? TOMLTable()
    let tooltipTable = wifi["tooltip"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.wifi.style",
      fallback: builtinWiFi.style
    )

    let content = WiFiBuiltinConfig.Content(
      displayMode: try parseWiFiDisplayMode(
        try optionalString(
          contentTable["display_mode"],
          path: "builtins.wifi.content.display_mode"
        ) ?? builtinWiFi.displayMode.rawValue,
        path: "builtins.wifi.content.display_mode"
      ),
      disconnectedText: try optionalString(
        contentTable["disconnected_text"],
        path: "builtins.wifi.content.disconnected_text"
      ) ?? builtinWiFi.disconnectedText,
      deniedText: try optionalString(
        contentTable["denied_text"],
        path: "builtins.wifi.content.denied_text"
      ) ?? builtinWiFi.deniedText,
      activeColorHex: try optionalString(
        contentTable["active_color"],
        path: "builtins.wifi.content.active_color"
      ) ?? builtinWiFi.activeColorHex,
      inactiveColorHex: try optionalString(
        contentTable["inactive_color"],
        path: "builtins.wifi.content.inactive_color"
      ) ?? builtinWiFi.inactiveColorHex
    )

    let expand = try parseWiFiExpand(from: expandTable, fallback: builtinWiFi.expand)
    let popup = try parseBuiltinPopupStyle(
      from: tooltipTable,
      path: "builtins.wifi.tooltip",
      fallback: builtinWiFi.popup
    )

    builtinWiFi = WiFiBuiltinConfig(
      placement: placement,
      style: style,
      content: content,
      expand: expand,
      popup: popup
    )
  }
}

extension Config {
  fileprivate func parseWiFiExpand(
    from table: TOMLTable,
    fallback: BuiltinWiFiExpand
  ) throws -> BuiltinWiFiExpand {
    BuiltinWiFiExpand(
      textColorHex: try optionalString(
        table["text_color"],
        path: "builtins.wifi.expand.text_color"
      ) ?? fallback.textColorHex
    )
  }
}
