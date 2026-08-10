import SwiftUI

// MARK: - Sparkline (filled area chart)

struct SparklineChart: View {
    let values: [Double]       // 0–100 (percent) or any range
    let maxValue: Double
    let color: Color
    let showGradient: Bool
    let lineWidth: CGFloat

    init(
        values: [Double],
        maxValue: Double = 100,
        color: Color = .accentColor,
        showGradient: Bool = true,
        lineWidth: CGFloat = 1.5
    ) {
        self.values = values
        self.maxValue = maxValue
        self.color = color
        self.showGradient = showGradient
        self.lineWidth = lineWidth
    }

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let n = values.count
            let w = size.width
            let h = size.height
            let xStep = w / CGFloat(n - 1)

            // Build path
            var linePath = Path()
            var fillPath = Path()

            for (i, val) in values.enumerated() {
                let x = CGFloat(i) * xStep
                let y = h - CGFloat(val / maxValue) * h
                if i == 0 {
                    linePath.move(to: CGPoint(x: x, y: y))
                    fillPath.move(to: CGPoint(x: x, y: h))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                } else {
                    linePath.addLine(to: CGPoint(x: x, y: y))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Close fill path
            fillPath.addLine(to: CGPoint(x: w, y: h))
            fillPath.closeSubpath()

            // Draw gradient fill
            if showGradient {
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: color.opacity(0.35), location: 0),
                            .init(color: color.opacity(0.05), location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                    )
                )
            }

            // Draw line
            context.stroke(
                linePath,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .animation(.linear(duration: 0.3), value: values.count)
    }
}

// MARK: - Mini tray sparkline (used in NSImage generation)

struct TraySparklineView: View {
    let values: [Double]
    let size: CGSize

    var body: some View {
        SparklineChart(
            values: values,
            maxValue: 100,
            color: .white,
            showGradient: true,
            lineWidth: 1.5
        )
        .frame(width: size.width, height: size.height)
        .background(Color.clear)
    }
}

// MARK: - Multi-line chart (for per-core CPU)

struct MultiSparklineChart: View {
    let seriesData: [[Double]]
    let colors: [Color]
    let maxValue: Double

    var body: some View {
        Canvas { context, size in
            guard !seriesData.isEmpty else { return }

            for (seriesIdx, values) in seriesData.enumerated() {
                guard values.count > 1 else { continue }
                let color = colors[seriesIdx % colors.count]
                let n = values.count
                let w = size.width
                let h = size.height
                let xStep = w / CGFloat(n - 1)

                var path = Path()
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * xStep
                    let y = h - CGFloat(val / maxValue) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(
                    path,
                    with: .color(color.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
