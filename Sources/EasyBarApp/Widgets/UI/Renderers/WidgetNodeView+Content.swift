import AppKit
import SwiftUI

// MARK: - Node Content

extension WidgetNodeView {
  var itemContent: some View {
    HStack(spacing: itemSpacing) {
      imageView
      symbolView
      iconText
      labelText
    }
  }

  var sliderView: some View {
    HStack(spacing: stackSpacing) {
      iconText
      labelText

      SliderWidgetView(
        rootWidgetID: node.root,
        targetWidgetID: node.id,
        minValue: minValue,
        maxValue: maxValue,
        step: stepValue,
        value: currentValue,
        tint: nodeColor,
        width: nodeWidth
      )
    }
  }

  var progressSliderView: some View {
    HStack(spacing: stackSpacing) {
      iconText
      labelText

      ProgressSliderWidgetView(
        rootWidgetID: node.root,
        targetWidgetID: node.id,
        minValue: minValue,
        maxValue: maxValue,
        step: stepValue,
        value: currentValue,
        tint: nodeColor,
        width: nodeWidth
      )
    }
  }

  var progressView: some View {
    HStack(spacing: stackSpacing) {
      iconText
      labelText

      ProgressBarCanvas(
        value: currentValue,
        minValue: minValue,
        maxValue: maxValue,
        tint: nodeColor
      )
      .frame(width: progressWidth, height: progressHeight)
    }
  }

  var sparklineView: some View {
    HStack(spacing: stackSpacing) {
      iconText
      labelText

      SparklineCanvas(
        values: node.values ?? [],
        tint: nodeColor,
        lineWidth: sparklineLineWidth
      )
      .frame(width: sparklineWidth, height: sparklineHeight)
    }
  }
}

// MARK: - Image And Text

extension WidgetNodeView {
  var hasImage: Bool {
    guard let imagePath = node.imagePath else { return false }
    return !imagePath.isEmpty
  }

  var hasIcon: Bool {
    return !node.icon.isEmpty
  }

  var hasSymbol: Bool {
    guard let symbolName = node.symbolName else { return false }
    return !symbolName.isEmpty
  }

  var hasSymbolSecondaryColor: Bool {
    guard let secondaryColor = node.symbolSecondaryColor else { return false }
    return !secondaryColor.isEmpty
  }

  var hasLabel: Bool {
    return !node.text.isEmpty
  }

  var hasCustomSymbolFill: Bool {
    guard let fraction = node.symbolFillFraction else { return false }
    return fraction >= 0
  }

  var iconResolvedColor: Color {
    return color(node.iconColor ?? node.color)
  }

  var labelResolvedColor: Color {
    return color(node.labelColor ?? node.color)
  }

  var iconResolvedFont: Font? {
    return fontValue(size: node.iconFontSize ?? node.fontSize)
  }

  var labelResolvedFont: Font? {
    return fontValue(size: node.labelFontSize ?? node.fontSize)
  }

  var iconOffset: CGSize {
    CGSize(
      width: CGFloat(node.iconOffsetX ?? 0),
      height: CGFloat(node.iconOffsetY ?? 0)
    )
  }

  var symbolResolvedFont: Font {
    return .system(size: symbolResolvedFontSize, weight: .regular)
  }

  var symbolResolvedFontSize: CGFloat {
    return WidgetRenderMetrics.positive(node.iconFontSize ?? node.fontSize, fallback: 18)
  }

  var symbolOverlayResolvedFont: Font {
    let baseSize = symbolResolvedFontSize
    let scale = WidgetRenderMetrics.positive(node.symbolOverlayScale, fallback: 0.58)
    return .system(size: baseSize * scale, weight: .semibold)
  }

  var symbolOverlayBackdropResolvedFont: Font {
    let baseSize = symbolResolvedFontSize
    let scale = WidgetRenderMetrics.positive(
      node.symbolOverlayBackdropScale ?? node.symbolOverlayScale,
      fallback: 0.58
    )
    return .system(size: baseSize * scale, weight: .semibold)
  }

  var symbolOverlayOutlineDistance: CGFloat {
    max(
      0.35,
      (symbolOverlayBackdropResolvedFontSize - symbolOverlayResolvedFontSize) * 0.35
    )
  }

  var symbolOverlayResolvedFontSize: CGFloat {
    let baseSize = symbolResolvedFontSize
    let scale = WidgetRenderMetrics.positive(node.symbolOverlayScale, fallback: 0.58)
    return baseSize * scale
  }

  var symbolOverlayBackdropResolvedFontSize: CGFloat {
    let baseSize = symbolResolvedFontSize
    let scale = WidgetRenderMetrics.positive(
      node.symbolOverlayBackdropScale ?? node.symbolOverlayScale,
      fallback: 0.58
    )
    return baseSize * scale
  }

  var symbolOverlayOffset: CGSize {
    CGSize(
      width: CGFloat(node.symbolOverlayOffsetX ?? 0),
      height: CGFloat(node.symbolOverlayOffsetY ?? 0)
    )
  }

  var symbolCanvasSize: CGSize {
    let base = symbolResolvedFontSize
    let widthFactor = WidgetRenderMetrics.nonnegative(node.symbolCanvasWidthFactor, fallback: 1)
    let heightFactor = WidgetRenderMetrics.nonnegative(node.symbolCanvasHeightFactor, fallback: 1)
    return CGSize(width: base * widthFactor, height: base * heightFactor)
  }

  var symbolFillFractionClamped: CGFloat {
    return WidgetRenderMetrics.unitInterval(node.symbolFillFraction)
  }

  var symbolFillWidth: CGFloat {
    let widthFactor = WidgetRenderMetrics.nonnegative(node.symbolFillWidthFactor, fallback: 0)
    let maxWidth = symbolCanvasSize.width * widthFactor
    guard maxWidth > 0 else { return 0 }

    let fraction = symbolFillFractionClamped
    if fraction <= 0 {
      return 0
    }

    let rawWidth = maxWidth * fraction
    let minimumFactor = WidgetRenderMetrics.unitInterval(
      node.symbolFillMinimumVisibleWidthFactor
    )
    let minimumVisibleWidth = maxWidth * minimumFactor
    return Swift.min(maxWidth, Swift.max(rawWidth, minimumVisibleWidth))
  }

  var symbolFillHeight: CGFloat {
    let factor = WidgetRenderMetrics.nonnegative(node.symbolFillHeightFactor, fallback: 0)
    return symbolCanvasSize.height * factor
  }

  var symbolFillOffset: CGSize {
    CGSize(
      width: symbolCanvasSize.width * WidgetRenderMetrics.finite(node.symbolFillOffsetXFactor),
      height: symbolCanvasSize.height * WidgetRenderMetrics.finite(node.symbolFillOffsetYFactor)
    )
  }

  var symbolFillCornerRadius: CGFloat {
    let factor = WidgetRenderMetrics.nonnegative(node.symbolFillCornerRadiusFactor, fallback: 0)
    return symbolResolvedFontSize * factor
  }

  var imageView: some View {
    return renderedImageView()
      .offset(iconOffset)
  }

  @ViewBuilder
  var symbolView: some View {
    if hasSymbol, let symbolName = node.symbolName {
      ZStack {
        if hasCustomSymbolFill {
          customFilledSymbolView(name: symbolName)
        } else {
          baseSymbolView(name: symbolName)
        }

        if let overlayName = node.symbolOverlayName, !overlayName.isEmpty {
          overlaySymbolView(name: overlayName)
        }
      }
      .offset(iconOffset)
    }
  }

  /// Builds the base SF Symbol view.
  @ViewBuilder
  func baseSymbolView(name: String) -> some View {
    if hasSymbolSecondaryColor {
      Image(systemName: name)
        .symbolRenderingMode(.palette)
        .font(symbolResolvedFont)
        .foregroundStyle(
          iconResolvedColor,
          color(node.symbolSecondaryColor)
        )
    } else {
      Image(systemName: name)
        .symbolRenderingMode(.hierarchical)
        .font(symbolResolvedFont)
        .foregroundStyle(iconResolvedColor)
    }
  }

  /// Builds an SF Symbol with a custom filled battery interior.
  @ViewBuilder
  func customFilledSymbolView(name: String) -> some View {
    ZStack {
      Color.clear
        .frame(width: symbolCanvasSize.width, height: symbolCanvasSize.height)
        .overlay(alignment: .leading) {
          RoundedRectangle(cornerRadius: symbolFillCornerRadius)
            .fill(iconResolvedColor)
            .frame(width: symbolFillWidth, height: symbolFillHeight)
            .offset(symbolFillOffset)
        }

      if hasSymbolSecondaryColor {
        Image(systemName: name)
          .symbolRenderingMode(.palette)
          .font(symbolResolvedFont)
          .foregroundStyle(
            Color.clear,
            color(node.symbolSecondaryColor)
          )
      } else {
        Image(systemName: name)
          .symbolRenderingMode(.hierarchical)
          .font(symbolResolvedFont)
          .foregroundStyle(iconResolvedColor.opacity(0.18))
      }

      Image(systemName: name)
        .symbolRenderingMode(.monochrome)
        .font(symbolResolvedFont)
        .foregroundStyle(color(node.symbolSecondaryColor))
    }
    .frame(width: symbolCanvasSize.width, height: symbolCanvasSize.height)
  }

  /// Builds the optional overlay symbol for a custom symbol view.
  @ViewBuilder
  func overlaySymbolView(name: String) -> some View {
    let overlay = Image(systemName: name)
      .symbolRenderingMode(.monochrome)
      .font(symbolOverlayResolvedFont)
      .foregroundStyle(color(node.symbolOverlayColor))
      .offset(symbolOverlayOffset)

    if let backdropColor = node.symbolOverlayBackdropColor, !backdropColor.isEmpty {
      let outline = color(backdropColor)
      let d = symbolOverlayOutlineDistance

      overlay
        .shadow(color: outline, radius: 0, x: d, y: 0)
        .shadow(color: outline, radius: 0, x: -d, y: 0)
        .shadow(color: outline, radius: 0, x: 0, y: d)
        .shadow(color: outline, radius: 0, x: 0, y: -d)
        .shadow(color: outline, radius: 0, x: d * 0.8, y: d * 0.8)
        .shadow(color: outline, radius: 0, x: -d * 0.8, y: d * 0.8)
        .shadow(color: outline, radius: 0, x: d * 0.8, y: -d * 0.8)
        .shadow(color: outline, radius: 0, x: -d * 0.8, y: -d * 0.8)
    } else {
      overlay
    }
  }

  @ViewBuilder
  var iconText: some View {
    if hasIcon && !hasSymbol {
      Text(iconDisplayString)
        .font(iconResolvedFont)
        .foregroundStyle(iconResolvedColor)
        .fixedSize()
        .offset(iconOffset)
    }
  }

  /// Returns the icon string to render for the current node.
  ///
  /// Some Nerd Font and private-use glyphs have visual overhangs that SwiftUI
  /// measures too tightly when rendered as a bare `Text`. For icon-only items,
  /// six-per-em spaces widen the text run enough to avoid clipping without
  /// requiring widget authors to add fake spaces to their icon strings.
  private var iconDisplayString: String {
    guard !hasLabel else { return node.icon }
    return "\u{2006}\(node.icon)\u{2006}"
  }

  @ViewBuilder
  var labelText: some View {
    if hasLabel {
      Text(node.text)
        .font(labelResolvedFont)
        .foregroundStyle(labelResolvedColor)
    }
  }

  /// Returns a templated image when custom image tinting is enabled.
  func tintedImage(from image: NSImage, isCustomImage: Bool) -> NSImage? {
    guard isCustomImage,
      let tint = node.iconColor ?? node.color,
      !tint.isEmpty
    else {
      return nil
    }

    let templated = image.copy() as? NSImage ?? image
    templated.isTemplate = true
    return templated
  }

  var imageSize: CGFloat {
    return WidgetRenderMetrics.nonnegative(node.imageSize, fallback: 14)
  }

  var imageCornerRadius: CGFloat {
    return WidgetRenderMetrics.nonnegative(node.imageCornerRadius, fallback: 4)
  }

  /// Builds the rendered image view for one node.
  @ViewBuilder
  func renderedImageView() -> some View {
    if hasImage, let imagePath = node.imagePath {
      Group {
        if let loadedImage = imageLoader.image(for: imagePath) {
          if let tintedImage = tintedImage(
            from: loadedImage.image,
            isCustomImage: loadedImage.isCustomImage
          ) {
            imageBaseView(image: tintedImage, renderingMode: .template)
              .foregroundStyle(iconResolvedColor)
              .frame(width: imageSize, height: imageSize)
              .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
          } else {
            imageBaseView(image: loadedImage.image, renderingMode: .original)
              .frame(width: imageSize, height: imageSize)
              .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
          }
        }
      }
      .task(id: imagePath) {
        await imageLoader.load(path: imagePath)
      }
    }
  }

  /// Builds the shared image view with the requested rendering mode.
  func imageBaseView(
    image: NSImage,
    renderingMode: Image.TemplateRenderingMode
  ) -> some View {
    Image(nsImage: image)
      .renderingMode(renderingMode)
      .resizable()
      .interpolation(.high)
      .scaledToFit()
  }
}
