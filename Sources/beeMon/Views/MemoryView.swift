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
    @ObservedObject var processMonitor: ProcessMonitor = .shared
    var showWindowPicker: Bool = false
    /// When true (Overview tab), hides the process table so the card stays compact.
    var isOverview: Bool = false
    @State private var timeWindow: TimeWindow = .twoMin

    private var windowedHistory: [MemorySample] {
        Array(monitor.memHistory.suffix(timeWindow.rawValue))
    }
    private var latestMem: MemorySample? { monitor.memHistory.last }
    private var memPercents: [Double] { windowedHistory.map(\.usedPercent) }

    var body: some View {
        MetricCard(glowColor: DS.memColor) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader("Memory", color: DS.memColor)
                    Spacer()
                    if showWindowPicker {
                        TimeWindowPicker(window: $timeWindow)
                            .padding(.trailing, 8)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        if let mem = latestMem {
                            Text(String(format: "%.1f%%", mem.usedPercent))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.memColor)
                                .contentTransition(.numericText())
                            Text("\(formatBytes(Double(mem.usedBytes))) used")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.textSecondary)
                                .lineLimit(1)
                            Text("\(formatBytes(Double(mem.totalBytes))) physical")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(DS.textMuted)
                                .lineLimit(1)
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
                        Text(timeWindow.label)
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

                // ── Top Processes — only shown in full Memory tab ─
                if !isOverview {
                    Divider().background(DS.border)

                    ProcessTableView(processes: processMonitor.topProcesses,
                                     totalMemBytes: latestMem?.totalBytes ?? 0)
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

// MARK: - Tooltip Label (click ⓘ → floating popover, no layout shift)

struct TooltipLabel: View {
    let label: String
    let tooltip: String
    let color: Color

    @State private var showPopover = false

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textSecondary)
            Button {
                showPopover.toggle()
            } label: {
                Image(systemName: showPopover ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(showPopover ? color : DS.textMuted)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                TooltipPopoverContent(text: tooltip, color: color)
            }
        }
        .frame(width: 110, alignment: .leading)
    }
}

// MARK: - Popover content view

private struct TooltipPopoverContent: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 280, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(red: 0.10, green: 0.10, blue: 0.15))
    }
}

// MARK: - Process Table

struct ProcessTableView: View {
    let processes: [ProcessEntry]
    let totalMemBytes: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text("TOP PROCESSES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.textMuted)
                    .tracking(1.5)
                Spacer()
                Text("Updated every 2s")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textMuted)
            }

            // Column headers
            HStack(spacing: 0) {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Memory")
                    .frame(width: 72, alignment: .trailing)
                Text("%Mem")
                    .frame(width: 52, alignment: .trailing)
                Text("%CPU")
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(DS.textMuted)
            .padding(.horizontal, 8)

            Divider().background(DS.border)

            if processes.isEmpty {
                Text("Sampling…")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(processes.enumerated()), id: \.element.id) { rank, proc in
                        ProcessRow(rank: rank + 1, proc: proc, totalMemBytes: totalMemBytes)
                    }
                }
            }
        }
    }
}

// MARK: - Process Row

struct ProcessRow: View {
    let rank: Int
    let proc: ProcessEntry
    let totalMemBytes: UInt64

    @State private var isHovered = false

    private var memPercent: Double {
        totalMemBytes > 0 ? Double(proc.memBytes) / Double(totalMemBytes) * 100 : 0
    }

    // CPU colour: green → amber → red
    private var cpuColor: Color {
        switch proc.cpuPercent {
        case ..<10:  return DS.netInColor
        case ..<50:  return DS.netOutColor
        default:     return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rank number
            Text("\(rank)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(DS.textMuted)
                .frame(width: 20, alignment: .trailing)
                .padding(.trailing, 6)

            // Process name
            Text(proc.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Memory bytes
            Text(formatBytes(Double(proc.memBytes)))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.memColor)
                .frame(width: 72, alignment: .trailing)
                .contentTransition(.numericText())

            // Memory %
            Text(String(format: "%.1f%%", memPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 52, alignment: .trailing)
                .contentTransition(.numericText())

            // CPU %
            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(cpuColor)
                .frame(width: 52, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? DS.surfaceHover : Color.clear)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
