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

  var symbolOverlayResolvedFont: Font {
    let baseSize = CGFloat(node.iconFontSize ?? node.fontSize ?? 18)
    let scale = CGFloat(node.symbolOverlayScale ?? 0.58)
    return .system(size: baseSize * scale, weight: .semibold)
  }

  var symbolOverlayOffset: CGSize {
    CGSize(
      width: CGFloat(node.symbolOverlayOffsetX ?? 0),
      height: CGFloat(node.symbolOverlayOffsetY ?? 0)
    )
  }

  @ViewBuilder
  var imageView: some View {
    renderedImageView()
  }

  @ViewBuilder
  var symbolView: some View {
    if hasSymbol, let symbolName = node.symbolName {
      ZStack {
        if hasSymbolSecondaryColor {
          Image(systemName: symbolName)
            .symbolRenderingMode(.palette)
            .font(symbolResolvedFont)
            .foregroundStyle(
              iconResolvedColor,
              color(node.symbolSecondaryColor)
            )
        } else {
          Image(systemName: symbolName)
            .symbolRenderingMode(.hierarchical)
            .font(symbolResolvedFont)
            .foregroundStyle(iconResolvedColor)
        }

        if let overlayName = node.symbolOverlayName, !overlayName.isEmpty {
          Image(systemName: overlayName)
            .symbolRenderingMode(.monochrome)
            .font(symbolOverlayResolvedFont)
            .foregroundStyle(color(node.symbolOverlayColor))
            .offset(symbolOverlayOffset)
        }
      }
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
    if hasImage, let imagePath = node.imagePath {
      let customImage = NSImage(contentsOfFile: imagePath)
      let image = resolvedImage(imagePath: imagePath, customImage: customImage)

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
