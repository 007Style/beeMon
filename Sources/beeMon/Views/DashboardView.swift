import SwiftUI

// MARK: - Main Dashboard Window

struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitor = .shared

    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case cpu      = "CPU"
        case memory   = "Memory"
        case network  = "Network"

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .cpu:      return "cpu"
            case .memory:   return "memorychip"
            case .network:  return "network"
            }
        }
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                titleBar

                // Tab bar
                tabBar

                Divider()
                    .background(DS.border)

                // Overview is a fixed layout that fills exactly the remaining space.
                // All other tabs scroll freely.
                if selectedTab == .overview {
                    overviewGrid
                        .padding(DS.spacing)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        content
                            .padding(DS.spacing)
                    }
                }
            }
        }
        .frame(width: 720, height: 780)
        .preferredColorScheme(.dark)
    }

    // MARK: Title Bar

    private var titleBar: some View {
        HStack(spacing: 10) {
            // Bee icon + name
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DS.cpuColor.opacity(0.3), DS.memColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Text("🐝")
                        .font(.system(size: 16))
                }

                Text("beeMon")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }

            Spacer()

            // Live stats in title bar
            if let cpu = monitor.cpuHistory.last, let mem = monitor.memHistory.last {
                HStack(spacing: 16) {
                    liveStat(
                        label: "CPU",
                        value: String(format: "%.1f%%", cpu.totalPercent),
                        color: DS.cpuColor
                    )
                    liveStat(
                        label: "MEM",
                        value: String(format: "%.1f%%", mem.usedPercent),
                        color: DS.memColor
                    )
                    if let iface = monitor.netHistory.last?.interfaces.values.first {
                        liveStat(
                            label: "NET",
                            value: "↓\(formatBytes(iface.rateIn, perSecond: true))",
                            color: DS.netInColor
                        )
                    }
                }
            }

            // Mini CPU sparkline in title bar
            if monitor.cpuHistory.count > 1 {
                SparklineChart(
                    values: monitor.cpuHistory.map(\.totalPercent),
                    maxValue: 100,
                    color: DS.cpuColor,
                    showGradient: true,
                    lineWidth: 1.5
                )
                .frame(width: 80, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            DS.surface.overlay(
                LinearGradient(
                    colors: [DS.cpuColor.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
    }

    private func liveStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DS.textMuted)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? DS.cpuColor : DS.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == tab {
                                DS.cpuColor
                                    .frame(height: 2)
                                    .clipShape(Capsule())
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()

            // Pulse indicator
            HStack(spacing: 5) {
                PulseIndicator()
                Text("Live · 1s")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(.trailing, 16)
        }
        .background(DS.surface)
    }

    // MARK: Content (tabs other than overview)

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview:
            EmptyView() // handled separately above
        case .cpu:
            CPUView(monitor: monitor, showWindowPicker: true)
        case .memory:
            MemoryView(monitor: monitor, showWindowPicker: true)
        case .network:
            NetworkView(monitor: monitor, showWindowPicker: true)
        }
    }

    // MARK: Overview — fixed layout, fills remaining height, no scroll

    private var overviewGrid: some View {
        GeometryReader { geo in
            VStack(spacing: DS.spacing) {
                // Top row: CPU + Memory side by side — takes natural height
                HStack(alignment: .top, spacing: DS.spacing) {
                    CPUView(monitor: monitor)
                        .frame(maxWidth: .infinity)
                    MemoryView(monitor: monitor)
                        .frame(maxWidth: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Network fills the remainder — capped at max 2 rows on overview
                NetworkView(monitor: monitor, activeOnly: true, overviewMaxInterfaces: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

// MARK: - Pulse Indicator

struct PulseIndicator: View {
    @State private var scale = 1.0
    @State private var opacity = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.netInColor.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .opacity(opacity)
            Circle()
                .fill(DS.netInColor)
                .frame(width: 5, height: 5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                scale = 2.0
                opacity = 0
            }
        }
    }
}
