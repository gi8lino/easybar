import AppKit
import SwiftUI

// MARK: - Node Content

extension WidgetNodeView {
  var itemContent: some View {
    HStack(spacing: itemSpacing) {
      imageView
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

  @ViewBuilder
  var imageView: some View {
    renderedImageView()
  }

  @ViewBuilder
  var iconText: some View {
    if hasIcon {
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
