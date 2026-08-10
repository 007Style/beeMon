import AppKit
import SwiftUI

// MARK: - Tray Controller

@MainActor
class TrayController: NSObject {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var popover: NSPopover?
    private var updateTimer: Timer?
    private var cancellable: Task<Void, Never>?

    // Sparkline state
    private var cpuValues: [Double] = Array(repeating: 0, count: 40)

    override init() {
        super.init()
        setupStatusItem()
        startUpdating()
    }

    // MARK: Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 60)

        if let button = statusItem.button {
            button.image = makeTrayImage(values: cpuValues, current: 0)
            button.imageScaling = .scaleProportionallyDown
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: Tray Image

    func makeTrayImage(values: [Double], current: Double) -> NSImage {
        let width: CGFloat = 56
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // Background pill
        let bgPath = NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
            xRadius: 3, yRadius: 3
        )
        NSColor(white: 1, alpha: 0.08).setFill()
        bgPath.fill()

        // Sparkline
        let n = values.count
        if n > 1 {
            let xStep = (width - 4) / CGFloat(n - 1)
            let chartPath = NSBezierPath()
            chartPath.lineWidth = 1.5
            chartPath.lineCapStyle = .round
            chartPath.lineJoinStyle = .round

            for (i, val) in values.enumerated() {
                let x = 2 + CGFloat(i) * xStep
                let y = 2 + CGFloat(val / 100.0) * (height - 4)
                if i == 0 { chartPath.move(to: NSPoint(x: x, y: y)) }
                else { chartPath.line(to: NSPoint(x: x, y: y)) }
            }

            NSColor(red: 0.36, green: 0.72, blue: 1.0, alpha: 1.0).setStroke()
            chartPath.stroke()
        }

        // Percent label
        let pct = String(format: "%.0f%%", current)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ]
        let str = NSAttributedString(string: pct, attributes: attrs)
        let strSize = str.size()
        str.draw(at: NSPoint(x: width - strSize.width - 1, y: 0))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: Updates

    private func startUpdating() {
        cancellable = Task {
            while !Task.isCancelled {
                updateIcon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func updateIcon() {
        let monitor = SystemMonitor.shared
        let current = monitor.cpuHistory.last?.totalPercent ?? 0

        // Keep last 40 samples for tray sparkline
        cpuValues.append(current)
        if cpuValues.count > 40 { cpuValues.removeFirst() }

        if let button = statusItem.button {
            button.image = makeTrayImage(values: cpuValues, current: current)
        }
    }

    // MARK: Click Handling

    @objc private func handleClick() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleDashboard()
        }
    }

    private func toggleDashboard() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
            return
        }

        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.isReleasedWhenClosed = false
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
            win.isMovableByWindowBackground = true
            win.contentView = NSHostingView(rootView: DashboardView())
            win.setContentSize(NSSize(width: 720, height: 700))
            win.center()

            // Unified title bar (glass look)
            win.toolbar = NSToolbar()
            win.toolbar?.showsBaselineSeparator = false

            self.window = win
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open beeMon", action: #selector(openDashboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit beeMon", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openDashboard() {
        toggleDashboard()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
