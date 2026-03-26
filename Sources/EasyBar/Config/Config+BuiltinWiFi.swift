import Foundation
import TOMLKit

extension Config {

  struct WiFiBuiltinConfig {
    struct Content {
      var showSSIDOnHover: Bool
      var disconnectedText: String
      var deniedText: String
      var activeColorHex: String
      var inactiveColorHex: String
      var textColorHex: String
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var content: Content

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

    var showSSIDOnHover: Bool {
      get { content.showSSIDOnHover }
      set { content.showSSIDOnHover = newValue }
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

    var textColorHex: String {
      get { content.textColorHex }
      set { content.textColorHex = newValue }
    }

    static let `default` = WiFiBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 30
      ),
      style: .init(
        icon: "",
        textColorHex: "#ffffff",
        backgroundColorHex: "#1a1a1a",
        borderColorHex: "#333333",
        borderWidth: 1,
        cornerRadius: 8,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 4,
        spacing: 6,
        opacity: 1
      ),
      content: .init(
        showSSIDOnHover: true,
        disconnectedText: "Wi-Fi",
        deniedText: "Location",
        activeColorHex: "#ffffff",
        inactiveColorHex: "#6e738d",
        textColorHex: "#ffffff"
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

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.wifi.style",
      fallback: builtinWiFi.style
    )

    let content = WiFiBuiltinConfig.Content(
      showSSIDOnHover: try optionalBool(
        contentTable["show_ssid_on_hover"],
        path: "builtins.wifi.content.show_ssid_on_hover"
      ) ?? builtinWiFi.showSSIDOnHover,
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
      ) ?? builtinWiFi.inactiveColorHex,
      textColorHex: try optionalString(
        contentTable["text_color"],
        path: "builtins.wifi.content.text_color"
      ) ?? builtinWiFi.textColorHex
    )

    builtinWiFi = WiFiBuiltinConfig(
      placement: placement,
      style: style,
      content: content
    )
  }
}
