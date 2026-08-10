import SwiftUI

// MARK: - Network Section

struct NetworkView: View {
    @ObservedObject var monitor: SystemMonitor
    /// When true only interfaces with recent activity are shown (overview mode).
    var activeOnly: Bool = false
    var showWindowPicker: Bool = false
    /// On the overview, cap how many interface rows are rendered (nil = no cap).
    var overviewMaxInterfaces: Int? = nil
    @State private var timeWindow: TimeWindow = .twoMin

    private var windowedHistory: [NetworkSample] {
        Array(monitor.netHistory.suffix(timeWindow.rawValue))
    }

    /// All interfaces that have ever transferred data (already filtered by SystemMonitor).
    private var allInterfaces: [String] {
        let names = (monitor.netHistory.last?.interfaces.keys).map(Array.init) ?? []
        return names.sorted()
    }

    /// Interfaces with any traffic in the last 2 minutes (120 samples).
    private var activeInterfaces: [String] {
        let window = Array(monitor.netHistory.suffix(120))
        return allInterfaces.filter { name in
            window.contains { sample in
                if let s = sample.interfaces[name] {
                    return s.rateIn > 0 || s.rateOut > 0
                }
                return false
            }
        }
    }

    private var displayedInterfaces: [String] {
        let base = activeOnly ? activeInterfaces : allInterfaces
        if let cap = overviewMaxInterfaces {
            return Array(base.prefix(cap))
        }
        return base
    }

    var body: some View {
        MetricCard(glowColor: DS.netInColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(
                        "Network",
                        subtitle: activeOnly
                            ? "\(activeInterfaces.count) active"
                            : "\(allInterfaces.count) interfaces",
                        color: DS.netInColor
                    )
                    if showWindowPicker {
                        TimeWindowPicker(window: $timeWindow)
                    }
                }

                if displayedInterfaces.isEmpty {
                    Text(activeOnly ? "No active traffic" : "No interfaces")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(displayedInterfaces, id: \.self) { iface in
                            InterfaceRow(
                                name: iface,
                                history: windowedHistory
                            )
                        }
                    }

                    // Overflow hint when cap is active and there are more interfaces
                    if let cap = overviewMaxInterfaces {
                        let hiddenCount = activeInterfaces.count - cap
                        if hiddenCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 9))
                                Text("+\(hiddenCount) more — see Network tab")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(DS.textMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 2)
                        }
                    }
                }

                // On the full tab, show dimmed inactive interfaces
                if !activeOnly {
                    let inactive = allInterfaces.filter { !activeInterfaces.contains($0) }
                    if !inactive.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Inactive")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.textMuted)
                                .padding(.top, 4)
                            HStack(spacing: 6) {
                                ForEach(inactive, id: \.self) { iface in
                                    HStack(spacing: 4) {
                                        Text(iface)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(DS.textMuted)
                                        Text("—")
                                            .font(.system(size: 8))
                                            .foregroundStyle(DS.textMuted.opacity(0.5))
                                        Text(InterfaceNamer.shared.friendlyName(for: iface))
                                            .font(.system(size: 9, weight: .regular))
                                            .foregroundStyle(DS.textMuted.opacity(0.7))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(DS.bg)
                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(DS.border, lineWidth: 0.5))
                                    )
                                }
                            }
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
        let friendly = InterfaceNamer.shared.friendlyName(for: name)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Interface name + friendly label badge
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.textPrimary)
                    Text("—")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textMuted)
                    Text(friendly)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.textSecondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(DS.bg)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(DS.borderBright, lineWidth: 0.5))
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
