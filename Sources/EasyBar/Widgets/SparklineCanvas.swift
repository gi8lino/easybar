import SwiftUI

struct SparklineCanvas: View {

    let values: [Double]
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let span = max(maxValue - minValue, 0.0001)

            var path = Path()

            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * size.width
                let normalized = (value - minValue) / span
                let y = size.height - CGFloat(normalized) * size.height

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .drawingGroup()
    }
}
