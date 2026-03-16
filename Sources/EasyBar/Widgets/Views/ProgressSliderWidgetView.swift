import SwiftUI

struct ProgressSliderWidgetView: View {

    let rootWidgetID: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    let externalValue: Double
    let tint: Color

    @State private var value: Double
    @State private var isDragging = false

    init(
        rootWidgetID: String,
        minValue: Double,
        maxValue: Double,
        step: Double,
        value: Double,
        tint: Color
    ) {
        self.rootWidgetID = rootWidgetID
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.externalValue = value
        self.tint = tint
        _value = State(initialValue: value)
    }

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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true

                        let newValue = value(for: gesture.location.x, width: geometry.size.width)
                        value = newValue

                        EventBus.shared.emitWidgetEvent(
                            "slider.preview",
                            widgetID: rootWidgetID,
                            data: [
                                "value": String(Int(newValue.rounded()))
                            ]
                        )
                    }
                    .onEnded { gesture in
                        let newValue = value(for: gesture.location.x, width: geometry.size.width)
                        value = newValue
                        isDragging = false

                        EventBus.shared.emitWidgetEvent(
                            "slider.changed",
                            widgetID: rootWidgetID,
                            data: [
                                "value": String(Int(newValue.rounded()))
                            ]
                        )
                    }
            )
        }
        .frame(width: resolvedWidth, height: 14)
        .onChange(of: externalValue) { _, newValue in
            // Keep the slider in sync with native system updates,
            // but do not fight the user while dragging.
            if !isDragging {
                value = newValue
            }
        }
    }

    private var resolvedWidth: CGFloat {
        if rootWidgetID == "builtin_volume" {
            return CGFloat(Config.shared.builtinVolume.sliderWidth)
        }

        return 72
    }

    private var normalizedValue: CGFloat {
        let span = max(maxValue - minValue, 0.0001)
        let clamped = min(max(value, minValue), maxValue)
        return CGFloat((clamped - minValue) / span)
    }

    private func knobOffset(in width: CGFloat) -> CGFloat {
        width * normalizedValue
    }

    private func value(for x: CGFloat, width: CGFloat) -> Double {
        let clampedX = min(max(0, x), width)
        let ratio = Double(clampedX / max(width, 1))
        let rawValue = minValue + ratio * (maxValue - minValue)

        let stepped = (rawValue / step).rounded() * step
        return min(max(stepped, minValue), maxValue)
    }
}
