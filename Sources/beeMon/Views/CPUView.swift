import SwiftUI

// MARK: - CPU Core Class Detection

enum CoreClass: String {
    case performance = "P"
    case efficiency  = "E"
    case unknown     = "?"

    var label: String { rawValue }
    var fullLabel: String {
        switch self {
        case .performance: return "Performance"
        case .efficiency:  return "Efficiency"
        case .unknown:     return "Core"
        }
    }
    var color: Color {
        switch self {
        case .performance: return DS.cpuColor
        case .efficiency:  return Color(red: 0.4, green: 0.85, blue: 0.5)
        case .unknown:     return DS.textSecondary
        }
    }
}

/// Detects core class via IOKit CPU topology (Apple Silicon only).
/// Returns an array of CoreClass, one per logical core, in order.
func detectCoreClasses(coreCount: Int) -> [CoreClass] {
    // Try IOKit registry for Apple Silicon topology
    var classes: [CoreClass] = []

    let matching = IOServiceMatching("IOPlatformDevice")
    var iter: io_iterator_t = 0
    if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
        var service: io_object_t = IOIteratorNext(iter)
        while service != 0 {
            // Look for cpu-clusters or die-topology property
            if let clusterData = IORegistryEntryCreateCFProperty(
                service, "cpu-clusters" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [[String: Any]] {
                for cluster in clusterData {
                    let count = (cluster["core-count"] as? Int) ?? 1
                    let type  = (cluster["type"] as? String) ?? ""
                    let cls: CoreClass = type.lowercased().contains("e") ? .efficiency : .performance
                    classes += Array(repeating: cls, count: count)
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }
        IOObjectRelease(iter)
    }

    if classes.count == coreCount { return classes }

    // Fallback: use sysctl hw.perflevel0.logicalcpu and hw.perflevel1.logicalcpu
    var perfCount: Int32 = 0
    var effCount: Int32  = 0
    var size = MemoryLayout<Int32>.size
    sysctlbyname("hw.perflevel0.logicalcpu", &perfCount, &size, nil, 0)
    size = MemoryLayout<Int32>.size
    sysctlbyname("hw.perflevel1.logicalcpu", &effCount, &size, nil, 0)

    if perfCount > 0 || effCount > 0 {
        let p = Array(repeating: CoreClass.performance, count: Int(perfCount))
        let e = Array(repeating: CoreClass.efficiency,  count: Int(effCount))
        let combined = p + e
        if combined.count == coreCount { return combined }
    }

    // Final fallback: all unknown
    return Array(repeating: .unknown, count: coreCount)
}

// MARK: - CPU Section

struct CPUView: View {
    @ObservedObject var monitor: SystemMonitor
    var showWindowPicker: Bool = false
    @State private var zoomedCore: Int? = nil
    @State private var timeWindow: TimeWindow = .twoMin

    private var coreClasses: [CoreClass] {
        detectCoreClasses(coreCount: monitor.coreCount)
    }

    private var coreColors: [Color] {
        coreClasses.map { cls in
            switch cls {
            case .performance: return DS.cpuColor
            case .efficiency:  return Color(red: 0.35, green: 0.88, blue: 0.52)
            case .unknown:
                let palette: [Color] = [
                    DS.cpuColor,
                    Color(red: 0.4, green: 0.85, blue: 1.0),
                    Color(red: 0.2, green: 0.6,  blue: 1.0),
                ]
                return palette[0]
            }
        }
    }

    private var windowedHistory: [CPUSample] {
        Array(monitor.cpuHistory.suffix(timeWindow.rawValue))
    }
    private var latestCPU: CPUSample? { monitor.cpuHistory.last }
    private var cpuPercents: [Double]  { windowedHistory.map(\.totalPercent) }

    var body: some View {
        MetricCard(glowColor: DS.cpuColor) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    SectionHeader("CPU", subtitle: "\(monitor.coreCount) cores", color: DS.cpuColor)
                    Spacer()
                    if showWindowPicker {
                        TimeWindowPicker(window: $timeWindow)
                    }
                    if let latest = latestCPU {
                        Text(String(format: "%.1f%%", latest.totalPercent))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.cpuColor)
                            .contentTransition(.numericText())
                            .padding(.leading, 8)
                    }
                }

                // Core class legend (only if mixed)
                let classes = coreClasses
                let hasP = classes.contains(.performance)
                let hasE = classes.contains(.efficiency)
                if hasP && hasE {
                    HStack(spacing: 12) {
                        coreClassBadge(.performance)
                        coreClassBadge(.efficiency)
                        Spacer()
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
                        Text(timeWindow.label)
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
                                        coreClass: coreIdx < classes.count ? classes[coreIdx] : .unknown,
                                        history: windowedHistory,
                                        color: coreColors[coreIdx],
                                        onTap: { zoomedCore = coreIdx }
                                    )
                                } else {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
        // Zoom overlay
        .overlay {
            if let idx = zoomedCore {
                CoreZoomOverlay(
                    index: idx,
                    coreClass: idx < coreClasses.count ? coreClasses[idx] : .unknown,
                    history: monitor.cpuHistory,
                    color: coreColors[idx],
                    onClose: { zoomedCore = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: zoomedCore)
    }

    private func coreClassBadge(_ cls: CoreClass) -> some View {
        HStack(spacing: 4) {
            Circle().fill(cls.color).frame(width: 5, height: 5)
                .shadow(color: cls.color.opacity(0.8), radius: 3)
            Text(cls.fullLabel + " Core")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(cls.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(cls.color.opacity(0.1))
                .overlay(Capsule().stroke(cls.color.opacity(0.25), lineWidth: 0.5))
        )
    }
}

// MARK: - Per-Core Cell

struct CoreCell: View {
    let index: Int
    let coreClass: CoreClass
    let history: [CPUSample]
    let color: Color
    let onTap: () -> Void

    @State private var isHovered = false

    private var values: [Double] {
        history.compactMap {
            index < $0.corePercents.count ? $0.corePercents[index] : nil
        }
    }
    private var current: Double { values.last ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text("C\(index)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.textMuted)
                // Core class badge
                Text(coreClass.label)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(coreClass.color)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(coreClass.color.opacity(0.15))
                    )
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
                    RoundedRectangle(cornerRadius: 2).fill(DS.border)
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
                .fill(isHovered ? DS.surfaceHover : DS.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isHovered ? DS.borderBright : DS.border, lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .cursor(.pointingHand)
    }
}

// MARK: - Core Zoom Overlay

struct CoreZoomOverlay: View {
    let index: Int
    let coreClass: CoreClass
    let history: [CPUSample]
    let color: Color
    let onClose: () -> Void

    private var values: [Double] {
        history.compactMap {
            index < $0.corePercents.count ? $0.corePercents[index] : nil
        }
    }
    private var current: Double { values.last ?? 0 }
    private var avg: Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    private var peak: Double { values.max() ?? 0 }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Core \(index)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.textPrimary)
                            // Class pill
                            Text(coreClass.fullLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(coreClass.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(coreClass.color.opacity(0.15))
                                        .overlay(Capsule().stroke(coreClass.color.opacity(0.35), lineWidth: 0.5))
                                )
                        }
                        Text("2-minute rolling window  ·  1s samples")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textMuted)
                    }

                    Spacer()

                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DS.textMuted)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                // Big sparkline
                SparklineChart(
                    values: values,
                    maxValue: 100,
                    color: color,
                    showGradient: true,
                    lineWidth: 2.5
                )
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DS.bg)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.border))
                )

                // Stats row
                HStack(spacing: 0) {
                    zoomStat(label: "Now", value: String(format: "%.1f%%", current), color: color)
                    Divider().background(DS.border).frame(height: 32).padding(.horizontal, 16)
                    zoomStat(label: "Avg (2m)", value: String(format: "%.1f%%", avg), color: DS.textSecondary)
                    Divider().background(DS.border).frame(height: 32).padding(.horizontal, 16)
                    zoomStat(label: "Peak (2m)", value: String(format: "%.1f%%", peak), color: DS.netOutColor)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DS.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DS.borderBright, lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.15), radius: 30)
            )
            .padding(40)
        }
    }

    private func zoomStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cursor helper

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
