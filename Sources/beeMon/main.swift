import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var trayController: TrayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pure menu-bar app — no dock icon, no main window at launch
        NSApp.setActivationPolicy(.accessory)

        // Build interface name map BEFORE any SwiftUI view renders.
        // Must NOT be a dispatch_once / static-let path — see InterfaceNamer.swift.
        InterfaceNamer.shared = InterfaceNamer.build()

        trayController = TrayController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Entry Point

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
