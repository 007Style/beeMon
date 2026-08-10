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
    /// When true (Overview tab), hides the per-core grid so the card stays compact.
    var isOverview: Bool = false
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
    private var cpuPercents: [Double]    { windowedHistory.map(\.totalPercent) }
    private var userPercents: [Double]   { windowedHistory.map(\.totalUserPercent) }
    private var systemPercents: [Double] { windowedHistory.map(\.totalSystemPercent) }
    private var idlePercents: [Double]   { windowedHistory.map(\.totalIdlePercent) }

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

                // Total CPU stacked sparkline — user / system / idle
                if !cpuPercents.isEmpty {
                    CPUBreakdownChart(
                        userValues:   userPercents,
                        systemValues: systemPercents,
                        idleValues:   idlePercents,
                        windowLabel:  timeWindow.label
                    )
                    .frame(height: 56)
                }

                Divider().background(DS.border)

                if isOverview {
                    // Overview: tiny pill-style core indicators — label + mini bar + %, click to zoom
                    let cols = 6
                    let rows = (monitor.coreCount + cols - 1) / cols
                    VStack(spacing: 3) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: 3) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let coreIdx = row * cols + col
                                    if coreIdx < monitor.coreCount {
                                        MiniCoreCell(
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
                } else {
                    // Full CPU tab: large cells with tall sparklines
                    let cols = min(monitor.coreCount, 4)
                    let rows = (monitor.coreCount + cols - 1) / cols
                    VStack(spacing: 8) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: 8) {
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

// MARK: - Mini Core Cell (overview only — very compact, click to zoom)

struct MiniCoreCell: View {
    let index: Int
    let coreClass: CoreClass
    let history: [CPUSample]
    let color: Color
    let onTap: () -> Void

    @State private var isHovered = false

    private var values: [Double] {
        history.compactMap { index < $0.corePercents.count ? $0.corePercents[index] : nil }
    }
    private var current: Double { values.last ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Label + live %
            HStack(spacing: 0) {
                Text("C\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.textMuted)
                Spacer(minLength: 2)
                Text(String(format: "%.0f%%", current))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            // Tiny sparkline
            SparklineChart(values: values, maxValue: 100, color: color,
                           showGradient: true, lineWidth: 1.0)
                .frame(height: 20)

            // Thin usage bar
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
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? DS.surfaceHover : DS.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isHovered ? color.opacity(0.5) : DS.border, lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .cursor(.pointingHand)
    }
}

// MARK: - Per-Core Cell (full CPU tab)

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
        VStack(alignment: .leading, spacing: 6) {
            // Header: label + class badge + live %
            HStack(spacing: 4) {
                Text("Core \(index)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.textSecondary)
                Text(coreClass.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(coreClass.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(coreClass.color.opacity(0.15)))
                Spacer()
                Text(String(format: "%.1f%%", current))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            // Sparkline
            SparklineChart(
                values: values,
                maxValue: 100,
                color: color,
                showGradient: true,
                lineWidth: 1.5
            )
            .frame(height: 60)

            // Usage bar — thicker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(DS.border)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.5), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(current / 100))
                        .animation(.linear(duration: 0.4), value: current)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
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

// MARK: - CPU Breakdown Chart (User / System / Idle stacked lines + legend)

struct CPUBreakdownChart: View {
    let userValues:   [Double]
    let systemValues: [Double]
    let idleValues:   [Double]
    var windowLabel: String = ""

    // Design colours
    private let userColor:   Color = DS.cpuColor                             // sky blue
    private let systemColor: Color = Color(red: 1.0, green: 0.60, blue: 0.20) // amber
    private let idleColor:   Color = Color(red: 0.28, green: 0.90, blue: 0.60) // mint

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Idle (bottom, faintest fill)
                SparklineChart(values: idleValues,   maxValue: 100, color: idleColor,
                               showGradient: true,  lineWidth: 1.2)
                // System
                SparklineChart(values: systemValues, maxValue: 100, color: systemColor,
                               showGradient: false, lineWidth: 1.5)
                // User (top, most prominent)
                SparklineChart(values: userValues,   maxValue: 100, color: userColor,
                               showGradient: false, lineWidth: 2)
            }
            .overlay(alignment: .bottomLeading) {
                Text(windowLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DS.textMuted)
                    .padding(.bottom, 2)
            }

            // Legend
            HStack(spacing: 12) {
                cpuLegendDot(color: userColor,   label: "User")
                cpuLegendDot(color: systemColor, label: "System")
                cpuLegendDot(color: idleColor,   label: "Idle")
                Spacer()
            }
        }
    }

    private func cpuLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.6), radius: 2)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textSecondary)
        }
    }
}

// MARK: - Core Zoom Overlay

struct CoreZoomOverlay: View {
    let index: Int
    let coreClass: CoreClass
    let history: [CPUSample]
    let color: Color
    let onClose: () -> Void

    private var userValues:   [Double] { history.compactMap { index < $0.userPercents.count   ? $0.userPercents[index]   : nil } }
    private var systemValues: [Double] { history.compactMap { index < $0.systemPercents.count ? $0.systemPercents[index] : nil } }
    private var idleValues:   [Double] { history.compactMap { index < $0.idlePercents.count   ? $0.idlePercents[index]   : nil } }
    private var totalValues:  [Double] { history.compactMap { index < $0.corePercents.count   ? $0.corePercents[index]   : nil } }

    private var current: Double { totalValues.last ?? 0 }
    private var avg: Double     { totalValues.isEmpty ? 0 : totalValues.reduce(0,+) / Double(totalValues.count) }
    private var peak: Double    { totalValues.max() ?? 0 }

    private var currentUser:   Double { userValues.last   ?? 0 }
    private var currentSystem: Double { systemValues.last ?? 0 }
    private var currentIdle:   Double { idleValues.last   ?? 0 }

    private let userColor   = DS.cpuColor
    private let systemColor = Color(red: 1.0,  green: 0.60, blue: 0.20)
    private let idleColor   = Color(red: 0.28, green: 0.90, blue: 0.60)

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Core \(index)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.textPrimary)
                            Text(coreClass.fullLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(coreClass.color)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(
                                    Capsule().fill(coreClass.color.opacity(0.15))
                                        .overlay(Capsule().stroke(coreClass.color.opacity(0.35), lineWidth: 0.5))
                                )
                        }
                        Text("2-minute rolling window  ·  1s samples")
                            .font(.system(size: 11)).foregroundStyle(DS.textMuted)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(DS.textMuted)
                    }
                    .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: [])
                }

                // Stacked breakdown chart
                CPUBreakdownChart(
                    userValues:   userValues,
                    systemValues: systemValues,
                    idleValues:   idleValues
                )
                .frame(height: 160)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DS.bg)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.border))
                )

                // Stats — Now / Avg / Peak for total active
                HStack(spacing: 0) {
                    zoomStat(label: "Total Now",  value: String(format: "%.1f%%", current),   color: color)
                    statDivider()
                    zoomStat(label: "Avg (2m)",   value: String(format: "%.1f%%", avg),        color: DS.textSecondary)
                    statDivider()
                    zoomStat(label: "Peak (2m)",  value: String(format: "%.1f%%", peak),       color: DS.netOutColor)
                }
                .frame(maxWidth: .infinity)

                // Breakdown row
                HStack(spacing: 0) {
                    zoomStat(label: "User",   value: String(format: "%.1f%%", currentUser),   color: userColor)
                    statDivider()
                    zoomStat(label: "System", value: String(format: "%.1f%%", currentSystem), color: systemColor)
                    statDivider()
                    zoomStat(label: "Idle",   value: String(format: "%.1f%%", currentIdle),   color: idleColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, -8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DS.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DS.borderBright, lineWidth: 1))
                    .shadow(color: color.opacity(0.15), radius: 30)
            )
            .padding(40)
        }
    }

    private func zoomStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color).contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10)).foregroundStyle(DS.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func statDivider() -> some View {
        Divider().background(DS.border).frame(height: 32).padding(.horizontal, 12)
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
