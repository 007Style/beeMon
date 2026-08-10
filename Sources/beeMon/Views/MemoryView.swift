import SwiftUI

// MARK: - Memory tooltip definitions

private struct MemMetric {
    let label: String
    let tooltip: String
    let color: Color
    let value: (MemorySample) -> UInt64
}

private let memMetrics: [MemMetric] = [
    .init(
        label: "App Memory",
        tooltip: "Memory actively used by running apps — anonymous pages allocated by user-space processes that are not file-backed. This is the clearest signal of app-driven pressure.",
        color: Color(red: 0.56, green: 0.42, blue: 1.0),
        value: { $0.appBytes }
    ),
    .init(
        label: "Wired Memory",
        tooltip: "Memory that the kernel and drivers have locked into RAM and cannot be paged out or compressed. It is always resident regardless of memory pressure.",
        color: Color(red: 0.36, green: 0.72, blue: 1.0),
        value: { $0.wiredBytes }
    ),
    .init(
        label: "Compressed",
        tooltip: "Pages that macOS has compressed in-place to free up physical RAM. The compressor lets the system store more data in RAM before resorting to swap.",
        color: Color(red: 1.0, green: 0.60, blue: 0.20),
        value: { $0.compressedBytes }
    ),
    .init(
        label: "Cached Files",
        tooltip: "File-backed pages kept in RAM after being read from disk. macOS evicts these first under pressure — they count as 'available' memory in Activity Monitor.",
        color: Color(red: 0.28, green: 0.90, blue: 0.60),
        value: { $0.cachedBytes }
    ),
    .init(
        label: "Swap Used",
        tooltip: "Data that did not fit in RAM (even after compression) and was written to the swap file on disk. High swap usage signals genuine memory pressure.",
        color: Color(red: 1.0, green: 0.35, blue: 0.35),
        value: { $0.swapUsedBytes }
    ),
]

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
                            Text("\(formatBytes(Double(mem.usedBytes))) used  /  \(formatBytes(Double(mem.totalBytes))) physical")
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

                // Segmented pressure bar
                if let mem = latestMem {
                    segmentedBar(mem: mem)
                }

                Divider().background(DS.border)

                // Metric rows
                if let mem = latestMem {
                    VStack(spacing: 6) {
                        ForEach(memMetrics, id: \.label) { metric in
                            MemoryMetricRow(
                                label: metric.label,
                                tooltip: metric.tooltip,
                                color: metric.color,
                                value: metric.value(mem),
                                total: mem.totalBytes
                            )
                        }

                        // Physical memory (total) — no bar, just informational
                        Divider().background(DS.border).padding(.vertical, 2)

                        HStack {
                            TooltipLabel(
                                label: "Physical Memory",
                                tooltip: "Total RAM installed in this Mac. Set at manufacture — not a dynamic value.",
                                color: DS.textMuted
                            )
                            Spacer()
                            Text(formatBytes(Double(mem.totalBytes)))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.textSecondary)
                        }

                        if mem.swapTotalBytes > 0 {
                            HStack {
                                TooltipLabel(
                                    label: "Swap Size",
                                    tooltip: "Total size of the swap file on disk. macOS grows this dynamically up to a limit determined by available storage.",
                                    color: DS.textMuted
                                )
                                Spacer()
                                Text(formatBytes(Double(mem.swapTotalBytes)))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DS.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Segmented bar

    private func segmentedBar(mem: MemorySample) -> some View {
        let total = Double(mem.totalBytes)
        let segments: [(Double, Color)] = [
            (Double(mem.appBytes),        Color(red: 0.56, green: 0.42, blue: 1.0)),
            (Double(mem.wiredBytes),      Color(red: 0.36, green: 0.72, blue: 1.0)),
            (Double(mem.compressedBytes), Color(red: 1.0,  green: 0.60, blue: 0.20)),
        ]

        return GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<segments.count, id: \.self) { i in
                    let (bytes, color) = segments[i]
                    let fraction = total > 0 ? min(bytes / total, 1) : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(fraction))
                }
                Spacer(minLength: 0)
            }
            .background(DS.bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.4), value: mem.appBytes)
    }
}

// MARK: - Memory Metric Row

struct MemoryMetricRow: View {
    let label: String
    let tooltip: String
    let color: Color
    let value: UInt64
    let total: UInt64

    private var fraction: Double { total > 0 ? Double(value) / Double(total) : 0 }

    var body: some View {
        HStack(spacing: 8) {
            TooltipLabel(label: label, tooltip: tooltip, color: color)

            // Mini bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(DS.bg).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(fraction), height: 4)
                        .animation(.linear(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 4)

            Text(formatBytes(Double(value)))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 66, alignment: .trailing)
                .contentTransition(.numericText())

            Text(String(format: "%.1f%%", fraction * 100))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DS.textMuted)
                .frame(width: 36, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Tooltip Label (click ⓘ to expand/collapse)

struct TooltipLabel: View {
    let label: String
    let tooltip: String
    let color: Color

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label row with clickable ⓘ
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.textSecondary)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(expanded ? color : DS.textMuted)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 110, alignment: .leading)

            // Inline expandable description
            if expanded {
                Text(tooltip)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(maxWidth: 260, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(red: 0.10, green: 0.10, blue: 0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(color.opacity(0.35), lineWidth: 0.5)
                            )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
