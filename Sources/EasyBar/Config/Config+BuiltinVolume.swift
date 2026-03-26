import Foundation
import TOMLKit

extension Config {

  /// Built-in volume widget config.
  struct VolumeBuiltinConfig {
    struct Content {
      var mutedIcon: String
      var lowIcon: String
      var highIcon: String
      var showPercentage: Bool
      var minValue: Double
      var maxValue: Double
      var step: Double
    }

    struct Slider {
      var expandToSliderOnHover: Bool
      var width: Double
    }

    var placement: BuiltinWidgetPlacement
    var style: BuiltinWidgetStyle
    var content: Content
    var slider: Slider

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

    var mutedIcon: String {
      get { content.mutedIcon }
      set { content.mutedIcon = newValue }
    }

    var lowIcon: String {
      get { content.lowIcon }
      set { content.lowIcon = newValue }
    }

    var highIcon: String {
      get { content.highIcon }
      set { content.highIcon = newValue }
    }

    var showPercentage: Bool {
      get { content.showPercentage }
      set { content.showPercentage = newValue }
    }

    var minValue: Double {
      get { content.minValue }
      set { content.minValue = newValue }
    }

    var maxValue: Double {
      get { content.maxValue }
      set { content.maxValue = newValue }
    }

    var step: Double {
      get { content.step }
      set { content.step = newValue }
    }

    var expandToSliderOnHover: Bool {
      get { slider.expandToSliderOnHover }
      set { slider.expandToSliderOnHover = newValue }
    }

    var sliderWidth: Double {
      get { slider.width }
      set { slider.width = newValue }
    }

    static let `default` = VolumeBuiltinConfig(
      placement: .init(
        enabled: false,
        position: .right,
        order: 20
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
        spacing: 8,
        opacity: 1
      ),
      content: .init(
        mutedIcon: "🔇",
        lowIcon: "🔉",
        highIcon: "🔊",
        showPercentage: true,
        minValue: 0,
        maxValue: 100,
        step: 1
      ),
      slider: .init(
        expandToSliderOnHover: true,
        width: 80
      )
    )
  }

  /// Parses the built-in volume widget.
  func parseVolumeBuiltin(from builtins: TOMLTable) throws {
    guard let volume = builtins["volume"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: volume,
      path: "builtins.volume",
      fallback: builtinVolume.placement
    )

    let styleTable = volume["style"]?.table ?? TOMLTable()
    let contentTable = volume["content"]?.table ?? TOMLTable()
    let sliderTable = volume["slider"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.volume.style",
      fallback: builtinVolume.style
    )

    let content = VolumeBuiltinConfig.Content(
      mutedIcon: try optionalString(
        contentTable["muted_icon"],
        path: "builtins.volume.content.muted_icon"
      ) ?? builtinVolume.mutedIcon,
      lowIcon: try optionalString(
        contentTable["low_icon"],
        path: "builtins.volume.content.low_icon"
      ) ?? builtinVolume.lowIcon,
      highIcon: try optionalString(
        contentTable["high_icon"],
        path: "builtins.volume.content.high_icon"
      ) ?? builtinVolume.highIcon,
      showPercentage: try optionalBool(
        contentTable["show_percentage"],
        path: "builtins.volume.content.show_percentage"
      ) ?? builtinVolume.showPercentage,
      minValue: try optionalNumber(
        contentTable["min"],
        path: "builtins.volume.content.min"
      ) ?? builtinVolume.minValue,
      maxValue: try optionalNumber(
        contentTable["max"],
        path: "builtins.volume.content.max"
      ) ?? builtinVolume.maxValue,
      step: try optionalNumber(
        contentTable["step"],
        path: "builtins.volume.content.step"
      ) ?? builtinVolume.step
    )

    let slider = VolumeBuiltinConfig.Slider(
      expandToSliderOnHover: try optionalBool(
        sliderTable["expand_to_slider_on_hover"],
        path: "builtins.volume.slider.expand_to_slider_on_hover"
      ) ?? builtinVolume.expandToSliderOnHover,
      width: try optionalNumber(
        sliderTable["width"],
        path: "builtins.volume.slider.width"
      ) ?? builtinVolume.sliderWidth
    )

    builtinVolume = VolumeBuiltinConfig(
      placement: placement,
      style: style,
      content: content,
      slider: slider
    )
  }
}
