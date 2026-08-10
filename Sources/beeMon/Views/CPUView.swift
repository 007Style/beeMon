import SwiftUI

// MARK: - CPU Section

struct CPUView: View {
    @ObservedObject var monitor: SystemMonitor

    private var coreColors: [Color] {
        let palette: [Color] = [
            DS.cpuColor,
            Color(red: 0.4, green: 0.85, blue: 1.0),
            Color(red: 0.2, green: 0.6,  blue: 1.0),
            Color(red: 0.5, green: 0.95, blue: 0.9),
            Color(red: 0.3, green: 0.75, blue: 0.95),
            Color(red: 0.15, green: 0.55, blue: 0.9),
            Color(red: 0.45, green: 0.9,  blue: 1.0),
            Color(red: 0.25, green: 0.65, blue: 1.0),
        ]
        return (0..<monitor.coreCount).map { palette[$0 % palette.count] }
    }

    private var latestCPU: CPUSample? { monitor.cpuHistory.last }
    private var cpuPercents: [Double] { monitor.cpuHistory.map(\.totalPercent) }

    var body: some View {
        MetricCard(glowColor: DS.cpuColor) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    SectionHeader("CPU", subtitle: "\(monitor.coreCount) cores", color: DS.cpuColor)
                    Spacer()
                    if let latest = latestCPU {
                        Text(String(format: "%.1f%%", latest.totalPercent))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.cpuColor)
                            .contentTransition(.numericText())
                    }
                }

                // Total CPU sparkline
                if !cpuPercents.isEmpty {
                    SparklineChart(
                        values: cpuPercents,
                        maxValue: 100,
                        color: DS.cpuColor,
                        showGradient: true,
                        lineWidth: 2
                    )
                    .frame(height: 56)
                    .overlay(alignment: .bottomLeading) {
                        Text("2m")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                            .padding(.bottom, 2)
                    }
                }

                Divider().background(DS.border)

                // Per-core grid
                let cols = min(monitor.coreCount, 8)
                let rows = (monitor.coreCount + cols - 1) / cols

                VStack(spacing: 6) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<cols, id: \.self) { col in
                                let coreIdx = row * cols + col
                                if coreIdx < monitor.coreCount {
                                    CoreCell(
                                        index: coreIdx,
                                        history: monitor.cpuHistory,
                                        color: coreColors[coreIdx]
                                    )
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Per-Core Cell

struct CoreCell: View {
    let index: Int
    let history: [CPUSample]
    let color: Color

    private var values: [Double] {
        history.compactMap {
            index < $0.corePercents.count ? $0.corePercents[index] : nil
        }
    }

    private var current: Double { values.last ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("C\(index)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.textMuted)
                Spacer()
                Text(String(format: "%.0f%%", current))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            SparklineChart(
                values: values,
                maxValue: 100,
                color: color,
                showGradient: true,
                lineWidth: 1
            )
            .frame(height: 28)

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.border)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(current / 100))
                        .animation(.linear(duration: 0.4), value: current)
                }
            }
            .frame(height: 3)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DS.border, lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
    }
}
