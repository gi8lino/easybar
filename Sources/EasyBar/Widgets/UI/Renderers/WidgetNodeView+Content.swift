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
    !node.icon.isEmpty
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
    !node.text.isEmpty
  }

  var hasCustomSymbolFill: Bool {
    guard let fraction = node.symbolFillFraction else { return false }
    return fraction >= 0
  }

  var iconResolvedColor: Color {
    color(node.iconColor ?? node.color)
  }

  var labelResolvedColor: Color {
    color(node.labelColor ?? node.color)
  }

  var iconResolvedFont: Font? {
    fontValue(size: node.iconFontSize ?? node.fontSize)
  }

  var labelResolvedFont: Font? {
    fontValue(size: node.labelFontSize ?? node.fontSize)
  }

  var symbolResolvedFont: Font {
    .system(size: CGFloat(node.iconFontSize ?? node.fontSize ?? 18), weight: .regular)
  }

  var symbolResolvedFontSize: CGFloat {
    CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
  }

  var symbolOverlayResolvedFont: Font {
    let baseSize = CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
    let scale = CGFloat(node.symbolOverlayScale ?? 0.58)
    return .system(size: baseSize * scale, weight: .semibold)
  }

  var symbolOverlayBackdropResolvedFont: Font {
    let baseSize = CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
    let scale = CGFloat(node.symbolOverlayBackdropScale ?? node.symbolOverlayScale ?? 0.58)
    return .system(size: baseSize * scale, weight: .semibold)
  }

  var symbolOverlayOutlineDistance: CGFloat {
    max(
      0.35,
      (symbolOverlayBackdropResolvedFontSize - symbolOverlayResolvedFontSize) * 0.35
    )
  }

  var symbolOverlayResolvedFontSize: CGFloat {
    let baseSize = CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
    let scale = CGFloat(node.symbolOverlayScale ?? 0.58)
    return baseSize * scale
  }

  var symbolOverlayBackdropResolvedFontSize: CGFloat {
    let baseSize = CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
    let scale = CGFloat(node.symbolOverlayBackdropScale ?? node.symbolOverlayScale ?? 0.58)
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
    let widthFactor = CGFloat(node.symbolCanvasWidthFactor ?? 1.0)
    let heightFactor = CGFloat(node.symbolCanvasHeightFactor ?? 1.0)
    return CGSize(width: base * widthFactor, height: base * heightFactor)
  }

  var symbolFillFractionClamped: CGFloat {
    guard let fraction = node.symbolFillFraction else { return 0 }
    return CGFloat(Swift.max(0, Swift.min(fraction, 1)))
  }

  var symbolFillWidth: CGFloat {
    let maxWidth = symbolCanvasSize.width * CGFloat(node.symbolFillWidthFactor ?? 0)
    guard maxWidth > 0 else { return 0 }

    let fraction = symbolFillFractionClamped
    if fraction <= 0 {
      return 0
    }

    let rawWidth = maxWidth * fraction
    let minimumVisibleWidth = maxWidth * CGFloat(node.symbolFillMinimumVisibleWidthFactor ?? 0)
    return Swift.min(maxWidth, Swift.max(rawWidth, minimumVisibleWidth))
  }

  var symbolFillHeight: CGFloat {
    symbolCanvasSize.height * CGFloat(node.symbolFillHeightFactor ?? 0)
  }

  var symbolFillOffset: CGSize {
    CGSize(
      width: symbolCanvasSize.width * CGFloat(node.symbolFillOffsetXFactor ?? 0),
      height: symbolCanvasSize.height * CGFloat(node.symbolFillOffsetYFactor ?? 0)
    )
  }

  var symbolFillCornerRadius: CGFloat {
    symbolResolvedFontSize * CGFloat(node.symbolFillCornerRadiusFactor ?? 0)
  }

  @ViewBuilder
  var imageView: some View {
    renderedImageView()
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
    }
  }

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
      Text(node.icon)
        .font(iconResolvedFont)
        .foregroundStyle(iconResolvedColor)
    }
  }

  @ViewBuilder
  var labelText: some View {
    if hasLabel {
      Text(node.text)
        .font(labelResolvedFont)
        .foregroundStyle(labelResolvedColor)
    }
  }

  func tintedImage(from image: NSImage, customImage: NSImage?) -> NSImage? {
    guard customImage != nil,
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
    CGFloat(node.imageSize ?? 14)
  }

  var imageCornerRadius: CGFloat {
    CGFloat(node.imageCornerRadius ?? 4)
  }

  func resolvedImage(imagePath: String, customImage: NSImage?) -> NSImage {
    customImage ?? NSWorkspace.shared.icon(forFile: imagePath)
  }

  @ViewBuilder
  func renderedImageView() -> some View {
    // TODO: maybe invert if
    if hasImage, let imagePath = node.imagePath {
      let customImage = NSImage(contentsOfFile: imagePath)
      let image = resolvedImage(imagePath: imagePath, customImage: customImage)

      // TODO: maybe invert if
      if let tintedImage = tintedImage(from: image, customImage: customImage) {
        imageBaseView(image: tintedImage, renderingMode: .template)
          .foregroundStyle(iconResolvedColor)
          .frame(width: imageSize, height: imageSize)
          .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
      } else {
        imageBaseView(image: image, renderingMode: .original)
          .frame(width: imageSize, height: imageSize)
          .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
      }
    }
  }

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
