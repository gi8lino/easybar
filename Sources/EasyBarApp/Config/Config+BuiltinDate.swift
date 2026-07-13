import Foundation

extension Config {

  /// Built-in date widget config.
  struct DateBuiltinConfig: @unchecked Sendable {
    /// Date format settings.
    struct Content {
      var format: String
    }

    /// Shared placement settings.
    var placement: BuiltinWidgetPlacement
    /// Shared visual style settings.
    var style: BuiltinWidgetStyle
    /// Date-specific content settings.
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

    /// Default date widget config.
    static let `default` = DateBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 50
      ),
      style: .init(
        icon: "📅",
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
        format: "yyyy-MM-dd"
      )
    )
  }

  /// Parses the built-in date widget.
  func parseDateBuiltin(from builtins: ConfigReader) throws {
    guard let date = try builtins.optionalSection("date") else { return }

    let placement = try parseBuiltinPlacement(
      reader: date,
      fallback: builtinDate.placement
    )

    let style = try parseBuiltinStyle(
      reader: try date.section("style"),
      fallback: builtinDate.style
    )

    let content = DateBuiltinConfig.Content(
      format: try date.section("content").string("format", fallback: builtinDate.format)
    )

    builtinDate = DateBuiltinConfig(
      placement: placement,
      style: style,
      content: content
    )
  }
}
