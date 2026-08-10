import SwiftUI
import AppKit

// MARK: - About Window Controller

@MainActor
class AboutWindowController: NSObject {
    private var window: NSWindow?

    func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
        win.isMovableByWindowBackground = true
        win.contentView = NSHostingView(rootView: AboutView())
        win.setContentSize(NSSize(width: 480, height: 560))
        win.center()
        self.window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - About View

struct AboutView: View {
    @State private var hexPhase: Double = 0
    @State private var pulseScale: Double = 1.0
    @State private var sparkValues: [Double] = (0..<40).map { _ in Double.random(in: 10...80) }
    @State private var sparkTimer: Timer?

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()

            // Subtle hex grid background
            HexGridBackground(phase: hexPhase)
                .opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Hero ──────────────────────────────────────────
                VStack(spacing: 16) {
                    Spacer().frame(height: 32)

                    // Animated bee icon ring
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [DS.cpuColor.opacity(0.6), DS.memColor.opacity(0.4), DS.netInColor.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 90, height: 90)
                            .scaleEffect(pulseScale)
                            .opacity(2 - pulseScale) // fades as it grows
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulseScale)

                        // Inner circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DS.cpuColor.opacity(0.25),
                                        DS.memColor.opacity(0.18),
                                        Color(red: 0.12, green: 0.12, blue: 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(DS.cpuColor.opacity(0.3), lineWidth: 1)
                            )

                        Text("🐝")
                            .font(.system(size: 40))
                    }
                    .onAppear { pulseScale = 1.5 }

                    // App name
                    VStack(spacing: 4) {
                        Text("beeMon")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DS.cpuColor, DS.memColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("VERSION 1.0.0")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.textMuted)
                            .tracking(2)
                    }
                }

                Spacer().frame(height: 24)

                // ── Live mini sparkline ───────────────────────────
                SparklineChart(
                    values: sparkValues,
                    maxValue: 100,
                    color: DS.cpuColor,
                    showGradient: true,
                    lineWidth: 1.5
                )
                .frame(width: 300, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.border, lineWidth: 0.5)
                )
                .onAppear {
                    sparkTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                        Task { @MainActor in
                            sparkValues.append(Double.random(in: 5...95))
                            if sparkValues.count > 40 { sparkValues.removeFirst() }
                        }
                    }
                }
                .onDisappear { sparkTimer?.invalidate() }

                Spacer().frame(height: 28)

                // ── Feature pills ─────────────────────────────────
                featurePills

                Spacer().frame(height: 28)

                // ── Divider ───────────────────────────────────────
                Rectangle()
                    .fill(DS.border)
                    .frame(height: 1)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 24)

                // ── Credits ───────────────────────────────────────
                VStack(spacing: 8) {
                    Text("CRAFTED BY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.textMuted)
                        .tracking(2)

                    HStack(spacing: 6) {
                        Text("🧠")
                        Text("Daneyand")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.textPrimary)
                        Text("&")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textMuted)
                        Text("IBM's Bob")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DS.cpuColor, DS.memColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("🤖")
                    }

                    Text("From the minds of Daneyand & IBM's Bob")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textSecondary)
                        .italic()
                }

                Spacer().frame(height: 20)

                // ── System info footer ────────────────────────────
                HStack(spacing: 16) {
                    sysChip(icon: "cpu", label: "\(ProcessInfo.processInfo.processorCount) Cores")
                    sysChip(icon: "memorychip", label: formatBytes(Double(ProcessInfo.processInfo.physicalMemory)))
                    sysChip(icon: "apple.logo", label: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString.components(separatedBy: " ").prefix(2).joined(separator: " "))")
                }

                Spacer().frame(height: 28)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 480, height: 560)
        .preferredColorScheme(.dark)
        .onAppear {
            // Animate hex grid
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                hexPhase = 1
            }
        }
    }

    // MARK: Feature Pills

    private var featurePills: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                featurePill(icon: "cpu",         label: "CPU per-core",    color: DS.cpuColor)
                featurePill(icon: "memorychip",  label: "Memory detail",   color: DS.memColor)
            }
            HStack(spacing: 8) {
                featurePill(icon: "network",     label: "Network / iface", color: DS.netInColor)
                featurePill(icon: "chart.xyaxis.line", label: "2m & 10m graphs", color: DS.netOutColor)
            }
            HStack(spacing: 8) {
                featurePill(icon: "menubar.rectangle", label: "Menu bar sparkline", color: Color(red: 0.7, green: 0.5, blue: 1.0))
                featurePill(icon: "1.circle",    label: "1-second live",   color: DS.textSecondary)
            }
        }
        .padding(.horizontal, 48)
    }

    private func featurePill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DS.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    // MARK: System chip

    private func sysChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DS.textMuted)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DS.bg)
                .overlay(Capsule().stroke(DS.border, lineWidth: 0.5))
        )
    }
}

// MARK: - Hex Grid Background

struct HexGridBackground: View {
    var phase: Double  // 0…1, drives subtle drift

    var body: some View {
        Canvas { context, size in
            let r: CGFloat = 18          // hex radius
            let w = r * 2
            let h = r * sqrt(3)
            let cols = Int(size.width  / w) + 3
            let rows = Int(size.height / h) + 3

            // Slow drift offset
            let offsetX = CGFloat(phase) * w
            let offsetY = CGFloat(phase) * h * 0.5

            for row in -1..<rows {
                for col in -1..<cols {
                    let xBase = CGFloat(col) * w * 1.5 - offsetX
                    let yBase = CGFloat(row) * h - offsetY + (col % 2 == 0 ? 0 : h / 2)
                    let center = CGPoint(x: xBase, y: yBase)
                    var path = Path()
                    for i in 0..<6 {
                        let angle = CGFloat(i) * .pi / 3 - .pi / 6
                        let pt = CGPoint(
                            x: center.x + r * cos(angle),
                            y: center.y + r * sin(angle)
                        )
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(Color.white), lineWidth: 0.4)
                }
            }
        }
        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: phase)
    }
}
