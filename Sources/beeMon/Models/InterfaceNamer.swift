import Foundation

// MARK: - Interface Namer
// Queries networksetup once at launch to build a device→friendlyName map.
// Falls back to a pattern table for anything not listed.

final class InterfaceNamer {
    static let shared = InterfaceNamer()

    /// device name → human-readable port name  e.g. "en0" → "Wi-Fi"
    private var map: [String: String] = [:]

    private init() {
        buildMap()
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

    private func buildMap() {
        let result = shell("networksetup -listallhardwareports")
        // Output blocks look like:
        //   Hardware Port: Wi-Fi
        //   Device: en0
        //   Ethernet Address: ...
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
    }

    /// Strips boilerplate words from port names that networksetup returns.
    private func cleanPortName(_ raw: String) -> String {
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

    private func shell(_ command: String) -> String {
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
