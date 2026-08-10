import SwiftUI

// MARK: - Network Section

struct NetworkView: View {
    @ObservedObject var monitor: SystemMonitor

    private var interfaces: [String] {
        let names = (monitor.netHistory.last?.interfaces.keys).map(Array.init) ?? []
        return names.sorted()
    }

    var body: some View {
        MetricCard(glowColor: DS.netInColor) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Network", subtitle: "\(interfaces.count) interfaces", color: DS.netInColor)

                if interfaces.isEmpty {
                    Text("No active interfaces")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(interfaces, id: \.self) { iface in
                            InterfaceRow(
                                name: iface,
                                history: monitor.netHistory
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Per-Interface Row

struct InterfaceRow: View {
    let name: String
    let history: [NetworkSample]

    private var rateInHistory: [Double] {
        history.compactMap { $0.interfaces[name]?.rateIn }
    }
    private var rateOutHistory: [Double] {
        history.compactMap { $0.interfaces[name]?.rateOut }
    }
    private var currentStats: InterfaceStats? {
        history.last?.interfaces[name]
    }
    private var maxRate: Double {
        let allRates = rateInHistory + rateOutHistory
        return max(allRates.max() ?? 1024, 1024)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Interface name badge
                Text(name)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DS.bg)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(DS.borderBright, lineWidth: 0.5))
                    )

                Spacer()

                if let stats = currentStats {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.netInColor)
                            Text(formatBytes(stats.rateIn, perSecond: true))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.netInColor)
                                .contentTransition(.numericText())
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.netOutColor)
                            Text(formatBytes(stats.rateOut, perSecond: true))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.netOutColor)
                                .contentTransition(.numericText())
                        }
                    }
                }
            }

            // Dual sparkline
            ZStack {
                if !rateInHistory.isEmpty {
                    SparklineChart(
                        values: rateInHistory,
                        maxValue: maxRate,
                        color: DS.netInColor,
                        showGradient: true,
                        lineWidth: 1.5
                    )
                }
                if !rateOutHistory.isEmpty {
                    SparklineChart(
                        values: rateOutHistory,
                        maxValue: maxRate,
                        color: DS.netOutColor,
                        showGradient: false,
                        lineWidth: 1.5
                    )
                }
            }
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DS.bg.opacity(0.6))
            )

            // Legend
            HStack(spacing: 12) {
                legendDot(color: DS.netInColor, label: "↓ In")
                legendDot(color: DS.netOutColor, label: "↑ Out")
                Spacer()
                if let stats = currentStats {
                    Text("Total: ↓\(formatBytes(Double(stats.bytesIn))) ↑\(formatBytes(Double(stats.bytesOut)))")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textMuted)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.bg)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(DS.border))
        )
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DS.textSecondary)
        }
    }
}
