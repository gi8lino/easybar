import AppKit
import SwiftUI

struct ProgressSliderWidgetView: View {
  let rootWidgetID: String
  let targetWidgetID: String
  let minValue: Double
  let maxValue: Double
  let step: Double
  let externalValue: Double
  let tint: Color
  let width: CGFloat?

  @State private var value: Double
  @State private var isDragging = false

  init(
    rootWidgetID: String,
    targetWidgetID: String,
    minValue: Double,
    maxValue: Double,
    step: Double,
    value: Double,
    tint: Color,
    width: CGFloat? = nil
  ) {
    self.rootWidgetID = rootWidgetID
    self.targetWidgetID = targetWidgetID
    self.minValue = minValue
    self.maxValue = maxValue
    self.step = step
    self.externalValue = value
    self.tint = tint
    self.width = width
    _value = State(initialValue: value)
  }

  /// Renders the draggable progress slider.
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.12))
          .frame(height: 8)

        Capsule()
          .fill(tint)
          .frame(width: max(0, geometry.size.width * normalizedValue), height: 8)

        Circle()
          .fill(tint)
          .frame(width: 12, height: 12)
          .offset(x: knobOffset(in: geometry.size.width) - 6)
      }
      .contentShape(Rectangle())
      .overlay {
        ProgressSliderInteractionSurface(
          onPreview: { x in
            isDragging = true

            let newValue = value(for: x, width: geometry.size.width)
            value = newValue

            Task {
              await EventHub.shared.emitWidgetEvent(
                .sliderPreview,
                widgetID: rootWidgetID,
                targetWidgetID: targetWidgetID,
                value: newValue
              )
            }
          },
          onCommit: { x in
            let newValue = value(for: x, width: geometry.size.width)
            value = newValue
            isDragging = false

            Task {
              await EventHub.shared.emitWidgetEvent(
                .sliderChanged,
                widgetID: rootWidgetID,
                targetWidgetID: targetWidgetID,
                value: newValue
              )
            }
          }
        )
      }
    }
    .frame(width: resolvedWidth, height: 14)
    .onChange(of: externalValue) { _, newValue in
      if !isDragging {
        value = newValue
      }
    }
  }

  /// Returns the resolved slider width.
  private var resolvedWidth: CGFloat {
    SliderWidthResolver.resolve(
      explicitWidth: width,
      rootWidgetID: rootWidgetID,
      fallback: 72
    )
  }

  /// Returns the current value normalized into the 0...1 range.
  private var normalizedValue: CGFloat {
    let span = max(maxValue - minValue, 0.0001)
    let clamped = min(max(value, minValue), maxValue)
    return CGFloat((clamped - minValue) / span)
  }

  /// Returns the knob offset inside the current width.
  private func knobOffset(in width: CGFloat) -> CGFloat {
    width * normalizedValue
  }

  /// Converts one drag position into a stepped value.
  private func value(for x: CGFloat, width: CGFloat) -> Double {
    let clampedX = min(max(0, x), width)
    let ratio = Double(clampedX / max(width, 1))
    let rawValue = minValue + ratio * (maxValue - minValue)

    let safeStep = max(step, 0.0001)
    let stepped = (rawValue / safeStep).rounded() * safeStep
    return min(max(stepped, minValue), maxValue)
  }
}

private struct ProgressSliderInteractionSurface: NSViewRepresentable {
  let onPreview: (CGFloat) -> Void
  let onCommit: (CGFloat) -> Void

  func makeNSView(context: Context) -> ProgressSliderInteractionNSView {
    let view = ProgressSliderInteractionNSView()
    view.onPreview = onPreview
    view.onCommit = onCommit
    return view
  }

  func updateNSView(_ nsView: ProgressSliderInteractionNSView, context: Context) {
    nsView.onPreview = onPreview
    nsView.onCommit = onCommit
  }
}

private final class ProgressSliderInteractionNSView: NSView {
  var onPreview: ((CGFloat) -> Void)?
  var onCommit: ((CGFloat) -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  override func mouseDown(with event: NSEvent) {
    emitPreview(for: event)
  }

  override func mouseDragged(with event: NSEvent) {
    emitPreview(for: event)
  }

  override func mouseUp(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    onCommit?(point.x)
  }

  private func emitPreview(for event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    onPreview?(point.x)
  }
}
