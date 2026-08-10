import Foundation

// MARK: - Interface Namer
// Queries networksetup once at launch to build a device→friendlyName map.
// Falls back to a pattern table for anything not listed.
//
// NOTE: Do NOT use a static let singleton here — Process() launch inside
// dispatch_once causes a recursive lock crash on macOS.
// Instead, `shared` is set explicitly from AppDelegate before any UI renders.

final class InterfaceNamer {
    // Set by AppDelegate.applicationDidFinishLaunching before any view renders.
    static var shared: InterfaceNamer = InterfaceNamer(map: [:])

    /// device name → human-readable port name  e.g. "en0" → "Wi-Fi"
    private var map: [String: String]

    /// Designated initialiser — call this off the dispatch_once path.
    init(map: [String: String]) {
        self.map = map
    }

    /// Build the map by running networksetup. Call this once, early, from AppDelegate.
    static func build() -> InterfaceNamer {
        var map: [String: String] = [:]
        let result = shell("networksetup -listallhardwareports")
        var currentPort: String?
        for line in result.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Hardware Port:") {
                currentPort = trimmed
                    .replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Device:"), let port = currentPort {
                let device = trimmed
                    .replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                map[device] = cleanPortName(port)
                currentPort = nil
            }
        }
        return InterfaceNamer(map: map)
    }

    // MARK: Public

    func friendlyName(for device: String) -> String {
        if let name = map[device] { return name }
        return patternFallback(for: device)
    }

    /// Full label: "en0 — Wi-Fi"
    func fullLabel(for device: String) -> String {
        let friendly = friendlyName(for: device)
        return "\(device) — \(friendly)"
    }

    // MARK: Private

    /// Strips boilerplate words from port names that networksetup returns.
    private static func cleanPortName(_ raw: String) -> String {
        // "Ethernet Adapter (en4)" → "Ethernet Adapter"
        let noParens = raw.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
        return noParens.trimmingCharacters(in: .whitespaces)
    }

    /// Pattern-based fallback for interfaces networksetup doesn't list
    /// (VPN tunnels, virtual, AWDL, etc.)
    private func patternFallback(for device: String) -> String {
        switch true {
        case device.hasPrefix("utun"):   return "VPN Tunnel"
        case device.hasPrefix("ipsec"):  return "IPSec VPN"
        case device.hasPrefix("ppp"):    return "PPP / VPN"
        case device.hasPrefix("awdl"):   return "AirDrop"
        case device.hasPrefix("llw"):    return "Low-Latency WLAN"
        case device.hasPrefix("anpi"):   return "Apple NCE"
        case device.hasPrefix("bridge"): return "Thunderbolt Bridge"
        case device.hasPrefix("en"):
            // en0 is almost always Wi-Fi on modern Macs; higher numbers are adapters
            if device == "en0" { return "Wi-Fi" }
            return "Ethernet Adapter"
        case device.hasPrefix("eth"):    return "Ethernet"
        default:                         return "Network Interface"
        }
    }

    // MARK: Shell helper

    private static func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
