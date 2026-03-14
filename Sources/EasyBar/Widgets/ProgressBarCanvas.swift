import SwiftUI

struct ProgressBarCanvas: View {

    let value: Double
    let minValue: Double
    let maxValue: Double
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let radius = size.height / 2

            let trackPath = Path(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: radius
            )

            context.fill(trackPath, with: .color(.white.opacity(0.12)))

            let normalized = normalizedValue
            let fillWidth = max(0, min(size.width, size.width * normalized))

            let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
            let fillPath = Path(
                roundedRect: fillRect,
                cornerRadius: radius
            )

            context.fill(fillPath, with: .color(tint))
        }
        .drawingGroup()
    }

    private var normalizedValue: Double {
        let span = max(maxValue - minValue, 0.0001)
        let clamped = min(max(value, minValue), maxValue)
        return (clamped - minValue) / span
    }
}
