import EasyBarShared
import Foundation
import TOMLKit

extension Config {

  /// Wi-Fi content mode.
  enum BuiltinWiFiContentMode: String, CaseIterable {
    case icon
    case field
    case details
  }

  /// Wi-Fi content visibility timing.
  enum BuiltinWiFiContentSurface: String, CaseIterable {
    case always
    case hover
  }

  /// Wi-Fi hover presentation surface.
  enum BuiltinWiFiHoverSurface: String, CaseIterable {
    case popup
    case inline
  }

  /// Wi-Fi inline text style.
  struct BuiltinWiFiInline {
    var textColorHex: String
  }

  /// Wi-Fi detail field toggles.
  struct BuiltinWiFiFields {
    var ssid: Bool
    var ipv4Address: Bool
    var ipv6Address: Bool
    var bssid: Bool
    var interfaceName: Bool
    var hardwareAddress: Bool
    var power: Bool
    var serviceActive: Bool
    var rssi: Bool
    var noise: Bool
    var snr: Bool
    var linkQuality: Bool
    var txRate: Bool
    var channel: Bool
    var channelBand: Bool
    var channelWidth: Bool
    var security: Bool
    var phyMode: Bool
    var interfaceMode: Bool
    var countryCode: Bool
    var roaming: Bool
    var ssidChangedAt: Bool
    var interfaceChangedAt: Bool
  }

  /// Built-in Wi-Fi widget config.
  struct WiFiBuiltinConfig {
    /// Wi-Fi content and color settings.
    struct Content {
      var mode: BuiltinWiFiContentMode
      var field: NetworkAgentField?
      var surface: BuiltinWiFiContentSurface
      var hoverSurface: BuiltinWiFiHoverSurface
      var disconnectedText: String
      var deniedText: String
      var activeColorHex: String
      var inactiveColorHex: String
    }

    /// Shared placement settings.
    var placement: BuiltinWidgetPlacement
    /// Shared visual style settings.
    var style: BuiltinWidgetStyle
    /// Wi-Fi-specific content settings.
    var content: Content
    /// Inline text style.
    var inline: BuiltinWiFiInline
    /// Detail field toggles.
    var fields: BuiltinWiFiFields
    /// Tooltip popup style.
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

    var mode: BuiltinWiFiContentMode {
      get { content.mode }
      set { content.mode = newValue }
    }

    var field: NetworkAgentField? {
      get { content.field }
      set { content.field = newValue }
    }

    var surface: BuiltinWiFiContentSurface {
      get { content.surface }
      set { content.surface = newValue }
    }

    var hoverSurface: BuiltinWiFiHoverSurface {
      get { content.hoverSurface }
      set { content.hoverSurface = newValue }
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

    var inlineTextColorHex: String {
      get { inline.textColorHex }
      set { inline.textColorHex = newValue }
    }

    /// Default Wi-Fi widget config.
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
        mode: .field,
        field: .ssid,
        surface: .hover,
        hoverSurface: .popup,
        disconnectedText: "disconnected",
        deniedText: "denied",
        activeColorHex: "#cdd6f4",
        inactiveColorHex: "#6c7086"
      ),
      inline: .init(
        textColorHex: "#ffffff"
      ),
      fields: .init(
        ssid: false,
        ipv4Address: false,
        ipv6Address: false,
        bssid: false,
        interfaceName: false,
        hardwareAddress: false,
        power: false,
        serviceActive: false,
        rssi: false,
        noise: false,
        snr: false,
        linkQuality: false,
        txRate: false,
        channel: false,
        channelBand: false,
        channelWidth: false,
        security: false,
        phyMode: false,
        interfaceMode: false,
        countryCode: false,
        roaming: false,
        ssidChangedAt: false,
        interfaceChangedAt: false
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

  /// Parses the built-in Wi-Fi widget.
  func parseWiFiBuiltin(from builtins: TOMLTable) throws {
    guard let wifi = builtins["wifi"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: wifi,
      path: "builtins.wifi",
      fallback: builtinWiFi.placement
    )

    let styleTable = wifi["style"]?.table ?? TOMLTable()
    let contentTable = wifi["content"]?.table ?? TOMLTable()
    let inlineTable = wifi["inline"]?.table ?? TOMLTable()
    let fieldsTable = wifi["fields"]?.table ?? TOMLTable()
    let tooltipTable = wifi["tooltip"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.wifi.style",
      fallback: builtinWiFi.style
    )

    let content = try parseWiFiContent(
      from: contentTable,
      fallback: builtinWiFi.content
    )

    let inline = try parseWiFiInline(from: inlineTable, fallback: builtinWiFi.inline)
    let fields = try parseWiFiFields(from: fieldsTable, fallback: builtinWiFi.fields)
    let popup = try parseBuiltinPopupStyle(
      from: tooltipTable,
      path: "builtins.wifi.tooltip",
      fallback: builtinWiFi.popup
    )

    builtinWiFi = WiFiBuiltinConfig(
      placement: placement,
      style: style,
      content: content,
      inline: inline,
      fields: fields,
      popup: popup
    )
  }
}

extension Config {
  /// Parses Wi-Fi content settings.
  fileprivate func parseWiFiContent(
    from table: TOMLTable,
    fallback: WiFiBuiltinConfig.Content
  ) throws -> WiFiBuiltinConfig.Content {
    WiFiBuiltinConfig.Content(
      mode: try parseWiFiContentMode(
        try optionalString(
          table["mode"],
          path: "builtins.wifi.content.mode"
        ) ?? fallback.mode.rawValue,
        path: "builtins.wifi.content.mode"
      ),
      field: try parseNetworkAgentField(
        try optionalString(
          table["field"],
          path: "builtins.wifi.content.field"
        ),
        allowedFields: NetworkAgentSnapshot.snapshotFieldSet,
        path: "builtins.wifi.content.field"
      ) ?? fallback.field,
      surface: try parseWiFiContentSurface(
        try optionalString(
          table["surface"],
          path: "builtins.wifi.content.surface"
        ) ?? fallback.surface.rawValue,
        path: "builtins.wifi.content.surface"
      ),
      hoverSurface: try parseWiFiHoverSurface(
        try optionalString(
          table["hover_surface"],
          path: "builtins.wifi.content.hover_surface"
        ) ?? fallback.hoverSurface.rawValue,
        path: "builtins.wifi.content.hover_surface"
      ),
      disconnectedText: try optionalString(
        table["disconnected_text"],
        path: "builtins.wifi.content.disconnected_text"
      ) ?? fallback.disconnectedText,
      deniedText: try optionalString(
        table["denied_text"],
        path: "builtins.wifi.content.denied_text"
      ) ?? fallback.deniedText,
      activeColorHex: try optionalString(
        table["active_color"],
        path: "builtins.wifi.content.active_color"
      ) ?? fallback.activeColorHex,
      inactiveColorHex: try optionalString(
        table["inactive_color"],
        path: "builtins.wifi.content.inactive_color"
      ) ?? fallback.inactiveColorHex
    )
  }

  /// Parses Wi-Fi inline text settings.
  fileprivate func parseWiFiInline(
    from table: TOMLTable,
    fallback: BuiltinWiFiInline
  ) throws -> BuiltinWiFiInline {
    BuiltinWiFiInline(
      textColorHex: try optionalString(
        table["text_color"],
        path: "builtins.wifi.inline.text_color"
      ) ?? fallback.textColorHex
    )
  }

  /// Parses Wi-Fi detail field toggles.
  fileprivate func parseWiFiFields(
    from table: TOMLTable,
    fallback: BuiltinWiFiFields
  ) throws -> BuiltinWiFiFields {
    BuiltinWiFiFields(
      ssid: try optionalBool(table["ssid"], path: "builtins.wifi.fields.ssid") ?? fallback.ssid,
      ipv4Address: try optionalBool(table["ipv4_address"], path: "builtins.wifi.fields.ipv4_address")
        ?? fallback.ipv4Address,
      ipv6Address: try optionalBool(table["ipv6_address"], path: "builtins.wifi.fields.ipv6_address")
        ?? fallback.ipv6Address,
      bssid: try optionalBool(table["bssid"], path: "builtins.wifi.fields.bssid") ?? fallback.bssid,
      interfaceName: try optionalBool(table["interface"], path: "builtins.wifi.fields.interface")
        ?? fallback.interfaceName,
      hardwareAddress: try optionalBool(table["hardware_address"], path: "builtins.wifi.fields.hardware_address")
        ?? fallback.hardwareAddress,
      power: try optionalBool(table["power"], path: "builtins.wifi.fields.power") ?? fallback.power,
      serviceActive: try optionalBool(table["service_active"], path: "builtins.wifi.fields.service_active")
        ?? fallback.serviceActive,
      rssi: try optionalBool(table["rssi"], path: "builtins.wifi.fields.rssi") ?? fallback.rssi,
      noise: try optionalBool(table["noise"], path: "builtins.wifi.fields.noise")
        ?? fallback.noise,
      snr: try optionalBool(table["snr"], path: "builtins.wifi.fields.snr") ?? fallback.snr,
      linkQuality: try optionalBool(table["link_quality"], path: "builtins.wifi.fields.link_quality")
        ?? fallback.linkQuality,
      txRate: try optionalBool(table["tx_rate"], path: "builtins.wifi.fields.tx_rate")
        ?? fallback.txRate,
      channel: try optionalBool(table["channel"], path: "builtins.wifi.fields.channel")
        ?? fallback.channel,
      channelBand: try optionalBool(
        table["channel_band"],
        path: "builtins.wifi.fields.channel_band"
      ) ?? fallback.channelBand,
      channelWidth: try optionalBool(
        table["channel_width"],
        path: "builtins.wifi.fields.channel_width"
      ) ?? fallback.channelWidth,
      security: try optionalBool(table["security"], path: "builtins.wifi.fields.security")
        ?? fallback.security,
      phyMode: try optionalBool(table["phy_mode"], path: "builtins.wifi.fields.phy_mode")
        ?? fallback.phyMode,
      interfaceMode: try optionalBool(
        table["interface_mode"],
        path: "builtins.wifi.fields.interface_mode"
      ) ?? fallback.interfaceMode,
      countryCode: try optionalBool(
        table["country_code"],
        path: "builtins.wifi.fields.country_code"
      ) ?? fallback.countryCode,
      roaming: try optionalBool(table["roaming"], path: "builtins.wifi.fields.roaming")
        ?? fallback.roaming,
      ssidChangedAt: try optionalBool(
        table["ssid_changed_at"],
        path: "builtins.wifi.fields.ssid_changed_at"
      ) ?? fallback.ssidChangedAt,
      interfaceChangedAt: try optionalBool(
        table["interface_changed_at"],
        path: "builtins.wifi.fields.interface_changed_at"
      ) ?? fallback.interfaceChangedAt
    )
  }
}
