import Foundation
import Darwin
import IOKit
import IOKit.ps

// MARK: - Data Models

struct CPUSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let totalPercent: Double
    let corePercents: [Double]
}

struct MemorySample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let usedBytes: UInt64
    let totalBytes: UInt64
    var usedPercent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0 }
}

struct NetworkSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let interfaces: [String: InterfaceStats]
}

struct InterfaceStats {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let rateIn: Double   // bytes/sec
    let rateOut: Double  // bytes/sec
}

// MARK: - Rolling Buffer

class RollingBuffer<T> {
    private var buffer: [T] = []
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    func append(_ value: T) {
        buffer.append(value)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    var values: [T] { buffer }
    var count: Int { buffer.count }
}

// MARK: - CPU Ticks (Darwin)

private struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 { user + system + idle + nice }
    var active: UInt64 { user + system + nice }
}

// MARK: - SystemMonitor

@MainActor
class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    // Published rolling windows (120 samples = 2 min at 1 Hz)
    @Published var cpuHistory: [CPUSample] = []
    @Published var memHistory: [MemorySample] = []
    @Published var netHistory: [NetworkSample] = []
    @Published var coreCount: Int = 1

    private let windowSize = 120
    private let cpuBuffer = RollingBuffer<CPUSample>(capacity: 120)
    private let memBuffer = RollingBuffer<MemorySample>(capacity: 120)
    private let netBuffer = RollingBuffer<NetworkSample>(capacity: 120)

    private var timer: Timer?
    private var prevCoreTicks: [CPUTicks] = []
    private var prevNetCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var prevNetTime: Date = .init()

    private init() {
        coreCount = ProcessInfo.processInfo.processorCount
        sample() // immediate first sample
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()

        cpuHistory = cpuBuffer.values
        memHistory = memBuffer.values
        netHistory = netBuffer.values
    }

    // MARK: CPU

    private func sampleCPU() {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else { return }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let coreN = Int(numCPUs)
        var currentTicks: [CPUTicks] = []

        for i in 0..<coreN {
            let base = Int(CPU_STATE_MAX) * i
            let user   = UInt64(info[base + Int(CPU_STATE_USER)])
            let system = UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            let idle   = UInt64(info[base + Int(CPU_STATE_IDLE)])
            let nice   = UInt64(info[base + Int(CPU_STATE_NICE)])
            currentTicks.append(CPUTicks(user: user, system: system, idle: idle, nice: nice))
        }

        var corePercents: [Double] = Array(repeating: 0, count: coreN)

        if prevCoreTicks.count == coreN {
            for i in 0..<coreN {
                let prev = prevCoreTicks[i]
                let curr = currentTicks[i]
                let totalDelta = Int64(curr.total) - Int64(prev.total)
                let activeDelta = Int64(curr.active) - Int64(prev.active)
                if totalDelta > 0 {
                    corePercents[i] = min(100, max(0, Double(activeDelta) / Double(totalDelta) * 100))
                }
            }
        }

        prevCoreTicks = currentTicks

        let totalPercent = corePercents.isEmpty ? 0 : corePercents.reduce(0, +) / Double(corePercents.count)
        let sample = CPUSample(timestamp: Date(), totalPercent: totalPercent, corePercents: corePercents)
        cpuBuffer.append(sample)
        coreCount = coreN
    }

    // MARK: Memory

    private func sampleMemory() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_page_size)
        let totalBytes = UInt64(ProcessInfo.processInfo.physicalMemory)
        let freePages = UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)
        let freeBytes = freePages * pageSize
        let usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0

        let sample = MemorySample(timestamp: Date(), usedBytes: usedBytes, totalBytes: totalBytes)
        memBuffer.append(sample)
    }

    // MARK: Network

    private func sampleNetwork() {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return }
        defer { freeifaddrs(ifaddrs) }

        var counters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var ptr = ifaddrs

        while let ifa = ptr {
            let name = String(cString: ifa.pointee.ifa_name)
            if let data = ifa.pointee.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                let bytesIn = UInt64(stats.ifi_ibytes)
                let bytesOut = UInt64(stats.ifi_obytes)

                if let existing = counters[name] {
                    counters[name] = (
                        bytesIn: max(existing.bytesIn, bytesIn),
                        bytesOut: max(existing.bytesOut, bytesOut)
                    )
                } else {
                    counters[name] = (bytesIn: bytesIn, bytesOut: bytesOut)
                }
            }
            ptr = ifa.pointee.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(prevNetTime)
        let dt = elapsed > 0 ? elapsed : 1.0

        var interfaces: [String: InterfaceStats] = [:]
        let relevantPrefixes = ["en", "eth", "utun", "bridge", "awdl", "llw"]

        for (name, curr) in counters {
            guard relevantPrefixes.contains(where: { name.hasPrefix($0) }) else { continue }

            let rateIn: Double
            let rateOut: Double

            if let prev = prevNetCounters[name] {
                let inDelta = curr.bytesIn >= prev.bytesIn ? curr.bytesIn - prev.bytesIn : 0
                let outDelta = curr.bytesOut >= prev.bytesOut ? curr.bytesOut - prev.bytesOut : 0
                rateIn = Double(inDelta) / dt
                rateOut = Double(outDelta) / dt
            } else {
                rateIn = 0
                rateOut = 0
            }

            interfaces[name] = InterfaceStats(
                bytesIn: curr.bytesIn,
                bytesOut: curr.bytesOut,
                rateIn: rateIn,
                rateOut: rateOut
            )
        }

        prevNetCounters = counters
        prevNetTime = now

        let sample = NetworkSample(timestamp: Date(), interfaces: interfaces)
        netBuffer.append(sample)
    }
}
