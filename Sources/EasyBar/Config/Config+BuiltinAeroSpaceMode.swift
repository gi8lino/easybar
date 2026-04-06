import Foundation
import TOMLKit

extension Config {

  /// Built-in AeroSpace mode widget config.
  struct AeroSpaceModeBuiltinConfig {
    struct Content {
      var showIcon: Bool
      var showText: Bool

      var hTilesIcon: String
      var vTilesIcon: String
      var hAccordionIcon: String
      var vAccordionIcon: String
      var floatingIcon: String
      var unknownIcon: String

      var hTilesText: String
      var vTilesText: String
      var hAccordionText: String
      var vAccordionText: String
      var floatingText: String
      var unknownText: String
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

    var showIcon: Bool {
      get { content.showIcon }
      set { content.showIcon = newValue }
    }

    var showText: Bool {
      get { content.showText }
      set { content.showText = newValue }
    }

    var hTilesIcon: String {
      get { content.hTilesIcon }
      set { content.hTilesIcon = newValue }
    }

    var vTilesIcon: String {
      get { content.vTilesIcon }
      set { content.vTilesIcon = newValue }
    }

    var hAccordionIcon: String {
      get { content.hAccordionIcon }
      set { content.hAccordionIcon = newValue }
    }

    var vAccordionIcon: String {
      get { content.vAccordionIcon }
      set { content.vAccordionIcon = newValue }
    }

    var floatingIcon: String {
      get { content.floatingIcon }
      set { content.floatingIcon = newValue }
    }

    var unknownIcon: String {
      get { content.unknownIcon }
      set { content.unknownIcon = newValue }
    }

    var hTilesText: String {
      get { content.hTilesText }
      set { content.hTilesText = newValue }
    }

    var vTilesText: String {
      get { content.vTilesText }
      set { content.vTilesText = newValue }
    }

    var hAccordionText: String {
      get { content.hAccordionText }
      set { content.hAccordionText = newValue }
    }

    var vAccordionText: String {
      get { content.vAccordionText }
      set { content.vAccordionText = newValue }
    }

    var floatingText: String {
      get { content.floatingText }
      set { content.floatingText = newValue }
    }

    var unknownText: String {
      get { content.unknownText }
      set { content.unknownText = newValue }
    }

    static let `default` = AeroSpaceModeBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .left,
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
        showIcon: true,
        showText: false,
        hTilesIcon: "󰕴",
        vTilesIcon: "󰕳",
        hAccordionIcon: "󰖲",
        vAccordionIcon: "󰖳",
        floatingIcon: "󰹙",
        unknownIcon: "󰘎",
        hTilesText: "h_tiles",
        vTilesText: "v_tiles",
        hAccordionText: "h_accordion",
        vAccordionText: "v_accordion",
        floatingText: "floating",
        unknownText: "unknown"
      )
    )
  }

  /// Parses the built-in AeroSpace mode widget.
  func parseAeroSpaceModeBuiltin(from builtins: TOMLTable) throws {
    guard let aerospaceMode = builtins["aerospace_mode"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: aerospaceMode,
      path: "builtins.aerospace_mode",
      fallback: builtinAeroSpaceMode.placement
    )

    let styleTable = aerospaceMode["style"]?.table ?? TOMLTable()
    let contentTable = aerospaceMode["content"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.aerospace_mode.style",
      fallback: builtinAeroSpaceMode.style
    )

    let content = AeroSpaceModeBuiltinConfig.Content(
      showIcon: try optionalBool(
        contentTable["show_icon"],
        path: "builtins.aerospace_mode.content.show_icon"
      ) ?? builtinAeroSpaceMode.showIcon,
      showText: try optionalBool(
        contentTable["show_text"],
        path: "builtins.aerospace_mode.content.show_text"
      ) ?? builtinAeroSpaceMode.showText,
      hTilesIcon: try optionalString(
        contentTable["h_tiles_icon"],
        path: "builtins.aerospace_mode.content.h_tiles_icon"
      ) ?? builtinAeroSpaceMode.hTilesIcon,
      vTilesIcon: try optionalString(
        contentTable["v_tiles_icon"],
        path: "builtins.aerospace_mode.content.v_tiles_icon"
      ) ?? builtinAeroSpaceMode.vTilesIcon,
      hAccordionIcon: try optionalString(
        contentTable["h_accordion_icon"],
        path: "builtins.aerospace_mode.content.h_accordion_icon"
      ) ?? builtinAeroSpaceMode.hAccordionIcon,
      vAccordionIcon: try optionalString(
        contentTable["v_accordion_icon"],
        path: "builtins.aerospace_mode.content.v_accordion_icon"
      ) ?? builtinAeroSpaceMode.vAccordionIcon,
      floatingIcon: try optionalString(
        contentTable["floating_icon"],
        path: "builtins.aerospace_mode.content.floating_icon"
      ) ?? builtinAeroSpaceMode.floatingIcon,
      unknownIcon: try optionalString(
        contentTable["unknown_icon"],
        path: "builtins.aerospace_mode.content.unknown_icon"
      ) ?? builtinAeroSpaceMode.unknownIcon,
      hTilesText: try optionalString(
        contentTable["h_tiles_text"],
        path: "builtins.aerospace_mode.content.h_tiles_text"
      ) ?? builtinAeroSpaceMode.hTilesText,
      vTilesText: try optionalString(
        contentTable["v_tiles_text"],
        path: "builtins.aerospace_mode.content.v_tiles_text"
      ) ?? builtinAeroSpaceMode.vTilesText,
      hAccordionText: try optionalString(
        contentTable["h_accordion_text"],
        path: "builtins.aerospace_mode.content.h_accordion_text"
      ) ?? builtinAeroSpaceMode.hAccordionText,
      vAccordionText: try optionalString(
        contentTable["v_accordion_text"],
        path: "builtins.aerospace_mode.content.v_accordion_text"
      ) ?? builtinAeroSpaceMode.vAccordionText,
      floatingText: try optionalString(
        contentTable["floating_text"],
        path: "builtins.aerospace_mode.content.floating_text"
      ) ?? builtinAeroSpaceMode.floatingText,
      unknownText: try optionalString(
        contentTable["unknown_text"],
        path: "builtins.aerospace_mode.content.unknown_text"
      ) ?? builtinAeroSpaceMode.unknownText
    )

    builtinAeroSpaceMode = AeroSpaceModeBuiltinConfig(
      placement: placement,
      style: style,
      content: content
    )
  }
}
