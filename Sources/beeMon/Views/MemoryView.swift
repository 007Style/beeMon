import SwiftUI

// MARK: - Memory Section

struct MemoryView: View {
    @ObservedObject var monitor: SystemMonitor

    private var latestMem: MemorySample? { monitor.memHistory.last }
    private var memPercents: [Double] { monitor.memHistory.map(\.usedPercent) }

    var body: some View {
        MetricCard(glowColor: DS.memColor) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader("Memory", color: DS.memColor)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let mem = latestMem {
                            Text(String(format: "%.1f%%", mem.usedPercent))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.memColor)
                                .contentTransition(.numericText())
                            Text("\(formatBytes(Double(mem.usedBytes))) / \(formatBytes(Double(mem.totalBytes)))")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                }

                // Sparkline
                if !memPercents.isEmpty {
                    SparklineChart(
                        values: memPercents,
                        maxValue: 100,
                        color: DS.memColor,
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

                // Pressure bar
                if let mem = latestMem {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Usage")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.textSecondary)
                            Spacer()
                            Text(formatBytes(Double(mem.usedBytes)))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.textPrimary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DS.bg)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [DS.memColor.opacity(0.7), DS.memColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * CGFloat(mem.usedPercent / 100),
                                        height: 8
                                    )
                                    .animation(.linear(duration: 0.4), value: mem.usedPercent)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("Free")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.textSecondary)
                            Spacer()
                            Text(formatBytes(Double(mem.totalBytes - mem.usedBytes)))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.textPrimary)
                        }
                    }
                }
            }
        }
    }
}
