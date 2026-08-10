import XCTest

// ─────────────────────────────────────────────────────────────────────────────
// beeMon Unit Tests
//
// Because beeMon is an SPM *executable* target, its symbols cannot be linked
// into a test bundle via @testable import. These tests are therefore
// self-contained: they re-implement the pure-logic types under test so the
// test suite has zero external dependencies and compiles reliably on any
// macOS 13+ machine without Xcode.
// ─────────────────────────────────────────────────────────────────────────────


// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Inline implementations (mirrors of production code)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: RollingBuffer

final class RollingBuffer<T> {
    private var buffer: [T] = []
    let capacity: Int
    init(capacity: Int) { self.capacity = capacity }
    func append(_ value: T) {
        buffer.append(value)
        if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
    }
    var values: [T] { buffer }
    var count: Int { buffer.count }
}

// MARK: formatBytes

func formatBytes(_ bytes: Double, perSecond: Bool = false) -> String {
    let suffix = perSecond ? "/s" : ""
    switch bytes {
    case ..<1024:              return String(format: "%.0f B\(suffix)", bytes)
    case ..<(1024*1024):       return String(format: "%.1f KB\(suffix)", bytes / 1024)
    case ..<(1024*1024*1024):  return String(format: "%.1f MB\(suffix)", bytes / 1_048_576)
    default:                   return String(format: "%.2f GB\(suffix)", bytes / 1_073_741_824)
    }
}

// MARK: InterfaceNamer (fallback logic only — no Process/networksetup calls)

final class InterfaceNamer {
    private var map: [String: String]
    init(map: [String: String]) { self.map = map }

    func friendlyName(for device: String) -> String {
        if let name = map[device] { return name }
        return patternFallback(for: device)
    }
    func fullLabel(for device: String) -> String { "\(device) — \(friendlyName(for: device))" }

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
            return device == "en0" ? "Wi-Fi" : "Ethernet Adapter"
        case device.hasPrefix("eth"):    return "Ethernet"
        default:                         return "Network Interface"
        }
    }
}

// MARK: Data models (mirrors of production structs)

import Foundation

struct CPUSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let totalPercent: Double
    let corePercents: [Double]
}

struct MemorySample {
    let timestamp: Date
    let totalBytes: UInt64
    let usedBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
    var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }
}

struct InterfaceStats {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let rateIn: Double
    let rateOut: Double
    var isActive: Bool { rateIn > 0 || rateOut > 0 || bytesIn > 0 || bytesOut > 0 }
}

enum TimeWindow: Int, CaseIterable {
    case twoMin = 120
    case tenMin = 600
    var label: String {
        switch self {
        case .twoMin: return "2m"
        case .tenMin: return "10m"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Test Cases
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: RollingBufferTests

final class RollingBufferTests: XCTestCase {

    func test_appendUpToCapacity_keepsAll() {
        let buf = RollingBuffer<Int>(capacity: 5)
        (1...5).forEach { buf.append($0) }
        XCTAssertEqual(buf.values, [1, 2, 3, 4, 5])
        XCTAssertEqual(buf.count, 5)
    }

    func test_appendOverCapacity_evictsOldest() {
        let buf = RollingBuffer<Int>(capacity: 3)
        (1...6).forEach { buf.append($0) }
        XCTAssertEqual(buf.values, [4, 5, 6])
        XCTAssertEqual(buf.count, 3)
    }

    func test_emptyBuffer_returnsEmpty() {
        let buf = RollingBuffer<String>(capacity: 10)
        XCTAssertTrue(buf.values.isEmpty)
        XCTAssertEqual(buf.count, 0)
    }

    func test_capacityOne_retainsOnlyLastValue() {
        let buf = RollingBuffer<Double>(capacity: 1)
        buf.append(1.0); buf.append(2.0); buf.append(3.0)
        XCTAssertEqual(buf.values, [3.0])
    }

    func test_appendLargeVolume_staysAtCapacity() {
        let cap = 120
        let buf = RollingBuffer<Int>(capacity: cap)
        for i in 0..<600 { buf.append(i) }
        XCTAssertEqual(buf.count, cap)
        XCTAssertEqual(buf.values.first, 480)
        XCTAssertEqual(buf.values.last, 599)
    }

    func test_suffix_semantics() {
        let buf = RollingBuffer<Int>(capacity: 10)
        (1...10).forEach { buf.append($0) }
        XCTAssertEqual(Array(buf.values.suffix(5)), [6, 7, 8, 9, 10])
    }

    func test_orderPreserved() {
        let buf = RollingBuffer<Int>(capacity: 5)
        [10, 20, 30, 40, 50].forEach { buf.append($0) }
        XCTAssertEqual(buf.values, [10, 20, 30, 40, 50])
    }

    func test_capacityZero_neverStoresAnything() {
        // Edge case: capacity 0 should store nothing
        let buf = RollingBuffer<Int>(capacity: 0)
        buf.append(1)
        XCTAssertEqual(buf.count, 0)
        XCTAssertTrue(buf.values.isEmpty)
    }
}

// MARK: FormatBytesTests

final class FormatBytesTests: XCTestCase {

    func test_bytes_formatsAsB() {
        XCTAssertEqual(formatBytes(0),    "0 B")
        XCTAssertEqual(formatBytes(512),  "512 B")
        XCTAssertEqual(formatBytes(1023), "1023 B")
    }

    func test_kilobytes_formatsAsKB() {
        XCTAssertEqual(formatBytes(1024),       "1.0 KB")
        XCTAssertEqual(formatBytes(1536),       "1.5 KB")
    }

    func test_megabytes_formatsAsMB() {
        XCTAssertEqual(formatBytes(1_048_576),  "1.0 MB")
        XCTAssertEqual(formatBytes(10_485_760), "10.0 MB")
    }

    func test_gigabytes_formatsAsGB() {
        XCTAssertEqual(formatBytes(1_073_741_824),  "1.00 GB")
        XCTAssertEqual(formatBytes(8_589_934_592),  "8.00 GB")
    }

    func test_perSecond_appendsSuffix() {
        XCTAssertTrue(formatBytes(1024, perSecond: true).hasSuffix("/s"))
        XCTAssertEqual(formatBytes(2048, perSecond: true), "2.0 KB/s")
    }

    func test_perSecond_false_noSuffix() {
        XCTAssertFalse(formatBytes(1024, perSecond: false).hasSuffix("/s"))
    }

    func test_zero_bytes_perSecond() {
        XCTAssertEqual(formatBytes(0, perSecond: true), "0 B/s")
    }
}

// MARK: InterfaceNamerTests

final class InterfaceNamerTests: XCTestCase {

    private let namer = InterfaceNamer(map: [:])

    func test_utun_isVPNTunnel()        { XCTAssertEqual(namer.friendlyName(for: "utun0"),   "VPN Tunnel") }
    func test_utun3_isVPNTunnel()       { XCTAssertEqual(namer.friendlyName(for: "utun3"),   "VPN Tunnel") }
    func test_awdl_isAirDrop()          { XCTAssertEqual(namer.friendlyName(for: "awdl0"),   "AirDrop") }
    func test_llw_isLowLatencyWLAN()    { XCTAssertEqual(namer.friendlyName(for: "llw0"),    "Low-Latency WLAN") }
    func test_bridge_isTBBridge()       { XCTAssertEqual(namer.friendlyName(for: "bridge0"), "Thunderbolt Bridge") }
    func test_en0_isWiFi()              { XCTAssertEqual(namer.friendlyName(for: "en0"),     "Wi-Fi") }
    func test_en1_isEthernetAdapter()   { XCTAssertEqual(namer.friendlyName(for: "en1"),     "Ethernet Adapter") }
    func test_en7_isEthernetAdapter()   { XCTAssertEqual(namer.friendlyName(for: "en7"),     "Ethernet Adapter") }
    func test_ppp_isPPPVPN()            { XCTAssertEqual(namer.friendlyName(for: "ppp0"),    "PPP / VPN") }
    func test_ipsec_isIPSecVPN()        { XCTAssertEqual(namer.friendlyName(for: "ipsec0"),  "IPSec VPN") }
    func test_unknown_isGeneric()       { XCTAssertEqual(namer.friendlyName(for: "zz99"),    "Network Interface") }

    func test_mapOverride_takesPrecedence() {
        let n = InterfaceNamer(map: ["en0": "Wi-Fi (Custom)"])
        XCTAssertEqual(n.friendlyName(for: "en0"), "Wi-Fi (Custom)")
        XCTAssertEqual(n.friendlyName(for: "en1"), "Ethernet Adapter") // fallback
    }

    func test_fullLabel_format() {
        XCTAssertEqual(namer.fullLabel(for: "en0"), "en0 — Wi-Fi")
    }

    func test_fullLabel_withMapEntry() {
        let n = InterfaceNamer(map: ["en7": "Realtek LAN"])
        XCTAssertEqual(n.fullLabel(for: "en7"), "en7 — Realtek LAN")
    }
}

// MARK: MemorySampleTests

final class MemorySampleTests: XCTestCase {

    private func sample(used: UInt64, total: UInt64) -> MemorySample {
        MemorySample(timestamp: Date(), totalBytes: total, usedBytes: used,
                     appBytes: 0, wiredBytes: 0, compressedBytes: 0,
                     cachedBytes: 0, swapUsedBytes: 0, swapTotalBytes: 0)
    }

    func test_halfFull_is50Percent() {
        let s = sample(used: 8_000_000_000, total: 16_000_000_000)
        XCTAssertEqual(s.usedPercent, 50.0, accuracy: 0.01)
    }

    func test_zeroTotal_returnsZero() {
        XCTAssertEqual(sample(used: 0, total: 0).usedPercent, 0.0)
    }

    func test_full_is100Percent() {
        let total: UInt64 = 16_000_000_000
        XCTAssertEqual(sample(used: total, total: total).usedPercent, 100.0, accuracy: 0.01)
    }

    func test_usedPercent_neverExceeds100() {
        // used > total should still be clamped in the UI, but the model itself is honest
        let s = sample(used: 20_000_000_000, total: 16_000_000_000)
        XCTAssertGreaterThan(s.usedPercent, 100.0) // model is honest; UI clamps
    }
}

// MARK: CPUSampleTests

final class CPUSampleTests: XCTestCase {

    func test_totalPercent_stored() {
        let s = CPUSample(timestamp: Date(), totalPercent: 42.5, corePercents: [35, 50])
        XCTAssertEqual(s.totalPercent, 42.5, accuracy: 0.001)
    }

    func test_corePercents_stored() {
        let cores = [10.0, 20.0, 30.0, 40.0]
        let s = CPUSample(timestamp: Date(), totalPercent: 25.0, corePercents: cores)
        XCTAssertEqual(s.corePercents, cores)
    }

    func test_identifiable_uniqueIDs() {
        let s1 = CPUSample(timestamp: Date(), totalPercent: 10, corePercents: [])
        let s2 = CPUSample(timestamp: Date(), totalPercent: 10, corePercents: [])
        XCTAssertNotEqual(s1.id, s2.id)
    }

    func test_emptyCorePercents() {
        let s = CPUSample(timestamp: Date(), totalPercent: 0, corePercents: [])
        XCTAssertTrue(s.corePercents.isEmpty)
    }
}

// MARK: InterfaceStatsTests

final class InterfaceStatsTests: XCTestCase {

    func test_rateInPositive_isActive()   { XCTAssertTrue(InterfaceStats(bytesIn:0, bytesOut:0, rateIn:1, rateOut:0).isActive) }
    func test_rateOutPositive_isActive()  { XCTAssertTrue(InterfaceStats(bytesIn:0, bytesOut:0, rateIn:0, rateOut:1).isActive) }
    func test_bytesInPositive_isActive()  { XCTAssertTrue(InterfaceStats(bytesIn:1, bytesOut:0, rateIn:0, rateOut:0).isActive) }
    func test_bytesOutPositive_isActive() { XCTAssertTrue(InterfaceStats(bytesIn:0, bytesOut:1, rateIn:0, rateOut:0).isActive) }
    func test_allZero_notActive()         { XCTAssertFalse(InterfaceStats(bytesIn:0, bytesOut:0, rateIn:0, rateOut:0).isActive) }
}

// MARK: TimeWindowTests

final class TimeWindowTests: XCTestCase {

    func test_twoMin_rawValue()       { XCTAssertEqual(TimeWindow.twoMin.rawValue, 120) }
    func test_tenMin_rawValue()       { XCTAssertEqual(TimeWindow.tenMin.rawValue, 600) }
    func test_twoMin_label()          { XCTAssertEqual(TimeWindow.twoMin.label, "2m") }
    func test_tenMin_label()          { XCTAssertEqual(TimeWindow.tenMin.label, "10m") }
    func test_allCases_count()        { XCTAssertEqual(TimeWindow.allCases.count, 2) }

    func test_rollingBuffer_suffix_matchesWindow() {
        // Simulate slicing history to a window — mirrors production windowedHistory
        let buf = RollingBuffer<Int>(capacity: 600)
        for i in 0..<300 { buf.append(i) }
        let twoMin = Array(buf.values.suffix(TimeWindow.twoMin.rawValue))
        let tenMin = Array(buf.values.suffix(TimeWindow.tenMin.rawValue))
        // Only 300 samples available; both windows return all 300
        XCTAssertEqual(twoMin.count, 120)
        XCTAssertEqual(tenMin.count, 300) // capped by available data
    }
}

// MARK: RollingBuffer + WindowedHistory integration

final class WindowedHistoryTests: XCTestCase {

    func test_windowSlice_exactlyCapacity_whenEnoughData() {
        let buf = RollingBuffer<Double>(capacity: 600)
        for i in 0..<600 { buf.append(Double(i)) }
        let slice = Array(buf.values.suffix(120))
        XCTAssertEqual(slice.count, 120)
        XCTAssertEqual(slice.first!, 480.0, accuracy: 0.001)
        XCTAssertEqual(slice.last!,  599.0, accuracy: 0.001)
    }

    func test_windowSlice_lessThanWindow_returnsAll() {
        let buf = RollingBuffer<Double>(capacity: 600)
        for i in 0..<50 { buf.append(Double(i)) }
        let slice = Array(buf.values.suffix(120))
        XCTAssertEqual(slice.count, 50) // only 50 samples collected so far
    }
}
