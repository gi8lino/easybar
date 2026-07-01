import EasyBarShared
import Foundation
import TOMLKit

extension Config {

  /// Wi-Fi content mode.
  enum BuiltinWiFiContentMode: String, CaseIterable {
    case icon
    case inline
    case details
  }

  /// Wi-Fi content visibility timing.
  enum BuiltinWiFiContentSurface: String, CaseIterable {
    case always
    case hover
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

    /// Returns whether at least one detail field is enabled.
    var hasEnabledField: Bool {
      Config.builtinWiFiFieldMetadata.contains { self[keyPath: $0.keyPath] }
    }
  }

  struct BuiltinWiFiFieldMetadata {
    let configKey: String
    let keyPath: WritableKeyPath<BuiltinWiFiFields, Bool>
    let agentField: NetworkAgentField
    let displayLabel: String
  }

  static let builtinWiFiFieldMetadata: [BuiltinWiFiFieldMetadata] = [
    .init(configKey: "ssid", keyPath: \.ssid, agentField: .ssid, displayLabel: "SSID"),
    .init(
      configKey: "ipv4_address",
      keyPath: \.ipv4Address,
      agentField: .ipv4Address,
      displayLabel: "IPv4 Address"
    ),
    .init(
      configKey: "ipv6_address",
      keyPath: \.ipv6Address,
      agentField: .ipv6Address,
      displayLabel: "IPv6 Address"
    ),
    .init(configKey: "rssi", keyPath: \.rssi, agentField: .rssi, displayLabel: "Signal"),
    .init(
      configKey: "link_quality",
      keyPath: \.linkQuality,
      agentField: .linkQuality,
      displayLabel: "Link Quality"
    ),
    .init(configKey: "tx_rate", keyPath: \.txRate, agentField: .txRate, displayLabel: "Rate"),
    .init(configKey: "channel", keyPath: \.channel, agentField: .channel, displayLabel: "Channel"),
    .init(
      configKey: "channel_band",
      keyPath: \.channelBand,
      agentField: .channelBand,
      displayLabel: "Band"
    ),
    .init(
      configKey: "channel_width",
      keyPath: \.channelWidth,
      agentField: .channelWidth,
      displayLabel: "Width"
    ),
    .init(configKey: "security", keyPath: \.security, agentField: .security, displayLabel: "Security"),
    .init(configKey: "phy_mode", keyPath: \.phyMode, agentField: .phyMode, displayLabel: "PHY"),
    .init(
      configKey: "interface",
      keyPath: \.interfaceName,
      agentField: .interfaceName,
      displayLabel: "Interface"
    ),
    .init(
      configKey: "interface_mode",
      keyPath: \.interfaceMode,
      agentField: .interfaceMode,
      displayLabel: "Mode"
    ),
    .init(configKey: "bssid", keyPath: \.bssid, agentField: .bssid, displayLabel: "BSSID"),
    .init(
      configKey: "hardware_address",
      keyPath: \.hardwareAddress,
      agentField: .hardwareAddress,
      displayLabel: "MAC"
    ),
    .init(configKey: "power", keyPath: \.power, agentField: .power, displayLabel: "Power"),
    .init(
      configKey: "service_active",
      keyPath: \.serviceActive,
      agentField: .serviceActive,
      displayLabel: "Service"
    ),
    .init(configKey: "noise", keyPath: \.noise, agentField: .noise, displayLabel: "Noise"),
    .init(configKey: "snr", keyPath: \.snr, agentField: .snr, displayLabel: "SNR"),
    .init(
      configKey: "country_code",
      keyPath: \.countryCode,
      agentField: .countryCode,
      displayLabel: "Country"
    ),
    .init(configKey: "roaming", keyPath: \.roaming, agentField: .roaming, displayLabel: "Roaming"),
    .init(
      configKey: "ssid_changed_at",
      keyPath: \.ssidChangedAt,
      agentField: .ssidChangedAt,
      displayLabel: "SSID Changed"
    ),
    .init(
      configKey: "interface_changed_at",
      keyPath: \.interfaceChangedAt,
      agentField: .interfaceChangedAt,
      displayLabel: "Interface Changed"
    ),
  ]

  /// Built-in Wi-Fi widget config.
  struct WiFiBuiltinConfig {
    /// Wi-Fi content and color settings.
    struct Content {
      var mode: BuiltinWiFiContentMode
      var surface: BuiltinWiFiContentSurface
      var inlineSeparator: String
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
    /// Popup style for Wi-Fi details mode.
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

    var surface: BuiltinWiFiContentSurface {
      get { content.surface }
      set { content.surface = newValue }
    }

    var inlineSeparator: String {
      get { content.inlineSeparator }
      set { content.inlineSeparator = newValue }
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
        mode: .icon,
        surface: .hover,
        inlineSeparator: " | ",
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
    let popupTable = wifi["popup"]?.table ?? TOMLTable()

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
      from: popupTable,
      path: "builtins.wifi.popup",
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
      surface: try parseWiFiContentSurface(
        try optionalString(
          table["surface"],
          path: "builtins.wifi.content.surface"
        ) ?? fallback.surface.rawValue,
        path: "builtins.wifi.content.surface"
      ),
      inlineSeparator: try optionalString(
        table["inline_separator"],
        path: "builtins.wifi.content.inline_separator"
      ) ?? fallback.inlineSeparator,
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

  /// Parses Wi-Fi field toggles.
  fileprivate func parseWiFiFields(
    from table: TOMLTable,
    fallback: BuiltinWiFiFields
  ) throws -> BuiltinWiFiFields {
    var fields = fallback

    for metadata in Self.builtinWiFiFieldMetadata {
      fields[keyPath: metadata.keyPath] =
        try optionalBool(
          table[metadata.configKey],
          path: "builtins.wifi.fields.\(metadata.configKey)"
        ) ?? fields[keyPath: metadata.keyPath]
    }

    return fields
  }
}
