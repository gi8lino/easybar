import Foundation
import TOMLKit

extension Config {

  /// Built-in CPU widget config.
  struct CPUBuiltinConfig {
    struct Content {
      var label: String
      var historySize: Int
      var lineWidth: Double
      var colorHex: String?
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

    var label: String {
      get { content.label }
      set { content.label = newValue }
    }

    var historySize: Int {
      get { content.historySize }
      set { content.historySize = newValue }
    }

    var lineWidth: Double {
      get { content.lineWidth }
      set { content.lineWidth = newValue }
    }

    var colorHex: String? {
      get { content.colorHex }
      set { content.colorHex = newValue }
    }

    static let `default` = CPUBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 10
      ),
      style: .init(
        icon: "󰍛 ",
        textColorHex: "",
        backgroundColorHex: "",
        borderColorHex: "",
        borderWidth: 0,
        cornerRadius: 0,
        marginX: 0,
        marginY: 0,
        paddingX: 8,
        paddingY: 4,
        spacing: 6,
        opacity: 1
      ),
      content: .init(
        label: "CPU",
        historySize: 10,
        lineWidth: 1.8,
        colorHex: "#a6da95"
      )
    )
  }

  /// Parses the built-in CPU widget.
  func parseCPUBuiltin(from builtins: TOMLTable) throws {
    guard let cpu = builtins["cpu"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: cpu,
      path: "builtins.cpu",
      fallback: builtinCPU.placement
    )

    let styleTable = cpu["style"]?.table ?? TOMLTable()
    let contentTable = cpu["content"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.cpu.style",
      fallback: builtinCPU.style
    )

    let content = CPUBuiltinConfig.Content(
      label: try optionalString(
        contentTable["label"],
        path: "builtins.cpu.content.label"
      ) ?? builtinCPU.label,
      historySize: max(
        2,
        try optionalInt(
          contentTable["history_size"],
          path: "builtins.cpu.content.history_size"
        ) ?? builtinCPU.historySize
      ),
      lineWidth: try optionalNumber(
        contentTable["line_width"],
        path: "builtins.cpu.content.line_width"
      ) ?? builtinCPU.lineWidth,
      colorHex: try optionalString(
        contentTable["color"],
        path: "builtins.cpu.content.color"
      ) ?? builtinCPU.colorHex
    )

    builtinCPU = CPUBuiltinConfig(
      placement: placement,
      style: style,
      content: content
    )
  }
}
