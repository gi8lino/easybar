import SwiftUI

struct SparklineCanvas: View {

    let values: [Double]
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            guard let path = makePath(size: size) else { return }

            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .drawingGroup()
    }

    /// Builds the sparkline path for the current values.
    private func makePath(size: CGSize) -> Path? {
        guard values.count >= 2 else { return nil }

        var path = Path()

        for (index, point) in points(size: size).enumerated() {
            if index == 0 {
                path.move(to: point)
                continue
            }

            path.addLine(to: point)
        }

        return path
    }

    /// Returns the normalized sparkline points for the current values.
    private func points(size: CGSize) -> [CGPoint] {
        let bounds = valueBounds
        let maxIndex = CGFloat(max(values.count - 1, 1))

        return values.enumerated().map { index, value in
            let x = CGFloat(index) / maxIndex * size.width
            let y = size.height - CGFloat(normalizedValue(value, bounds: bounds)) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    /// Returns the min/max bounds used to normalize sparkline values.
    private var valueBounds: (min: Double, span: Double) {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        return (minValue, max(maxValue - minValue, 0.0001))
    }

    /// Returns the normalized 0...1 value for one sample.
    private func normalizedValue(_ value: Double, bounds: (min: Double, span: Double)) -> Double {
        (value - bounds.min) / bounds.span
    }
}
