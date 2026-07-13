import Foundation

extension Config {

  /// Built-in time widget config.
  struct TimeBuiltinConfig: @unchecked Sendable {
    /// Time format settings.
    struct Content {
      var format: String
    }

    /// Shared placement settings.
    var placement: BuiltinWidgetPlacement
    /// Shared visual style settings.
    var style: BuiltinWidgetStyle
    /// Time-specific content settings.
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

    var format: String {
      get { content.format }
      set { content.format = newValue }
    }

    /// Default time widget config.
    static let `default` = TimeBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 40
      ),
      style: .init(
        icon: "🕒",
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
        format: "HH:mm"
      )
    )
  }

  /// Parses the built-in time widget.
  func parseTimeBuiltin(from builtins: ConfigReader) throws {
    guard let time = try builtins.optionalSection("time") else { return }

    let placement = try parseBuiltinPlacement(
      reader: time,
      fallback: builtinTime.placement
    )

    let style = try parseBuiltinStyle(
      reader: try time.section("style"),
      fallback: builtinTime.style
    )

    let content = TimeBuiltinConfig.Content(
      format: try time.section("content").string("format", fallback: builtinTime.format)
    )

    builtinTime = TimeBuiltinConfig(
      placement: placement,
      style: style,
      content: content
    )
  }
}
