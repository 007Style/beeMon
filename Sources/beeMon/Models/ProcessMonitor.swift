import Foundation

// MARK: - Process Entry

struct ProcessEntry: Identifiable {
    let id: Int           // PID
    let name: String
    let memBytes: UInt64  // RSS in bytes
    let cpuPercent: Double
}

// MARK: - Process Monitor

@MainActor
class ProcessMonitor: ObservableObject {
    static let shared = ProcessMonitor()

    @Published var topProcesses: [ProcessEntry] = []

    private var timer: Timer?

    private init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        Task.detached(priority: .utility) {
            let result = ProcessMonitor.fetchProcesses()
            await MainActor.run { self.topProcesses = result }
        }
    }

    // nonisolated so it can be called from a detached Task without actor hopping
    private nonisolated static func fetchProcesses() -> [ProcessEntry] {
        let task = Process()
        task.launchPath = "/bin/ps"
        // cols: pid, rss (KB), %cpu, comm
        task.arguments = ["-Arco", "pid,rss,pcpu,comm"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        task.launch()
        task.waitUntilExit()

        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""

        var results: [ProcessEntry] = []

        for line in raw.components(separatedBy: "\n").dropFirst() { // skip header
            let parts = line.trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
            guard parts.count >= 4,
                  let pid   = Int(parts[0]),
                  let rssKB = UInt64(parts[1]),
                  let cpu   = Double(parts[2]) else { continue }

            let name     = parts[3...].joined(separator: " ")
            let memBytes = rssKB * 1024

            results.append(ProcessEntry(id: pid, name: name, memBytes: memBytes, cpuPercent: cpu))
        }

        return results
            .sorted { $0.memBytes > $1.memBytes }
            .prefix(20)
            .map { $0 }
    }
}
