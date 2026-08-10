# beeMon Changelog

All notable changes to beeMon are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] — 2026-08-10

### Added
- **CPU monitoring** — per-core usage with individual sparkline charts, usage
  bars, and a total aggregate graph
- **CPU core class detection** — Performance (P) and Efficiency (E) core badges
  per cell via `sysctl hw.perflevel0/1.logicalcpu` with IOKit fallback
- **Core zoom** — click any core cell to expand a full overlay with a large
  sparkline, Now / Avg / Peak stats; Esc or click backdrop to dismiss
- **Memory monitoring** — App Memory, Wired, Compressed, Cached Files, Swap
  Used, Swap Total, and Physical Memory with segmented pressure bar
- **Memory tooltips** — click the ⓘ next to any memory metric for a floating
  popover explaining that category
- **Network monitoring** — per-interface bandwidth (↓ in / ↑ out) with dual
  sparklines, friendly interface names (en0 — Wi-Fi, etc.)
- **Interface naming** — `InterfaceNamer` queries `networksetup` at launch and
  falls back to a pattern table for VPN tunnels, AirDrop, etc.
- **2-minute / 10-minute time window toggle** on CPU, Memory, and Network tabs
- **Overview tab** — CPU + Memory side by side, network below; no scrolling;
  capped at 2 active network interfaces with "+ N more" hint
- **Menu bar tray icon** — live CPU sparkline + percentage drawn into a 56×18
  `NSImage`; left-click opens dashboard, right-click shows menu
- **About beeMon panel** — animated hex-grid background, pulsing glow ring,
  live demo sparkline, feature pills, system info chips, version, credits
- **Dark glass UI** — custom design system with `DS` tokens, `MetricCard`,
  `SectionHeader`, `TimeWindowPicker`, `SparklineChart` (SwiftUI `Canvas`)
- **1-second live updates** across all metrics
- **Rolling 600-sample buffer** (10 minutes of history) per metric

### Technical
- Pure Swift / SwiftUI — no third-party dependencies
- CPU data via `host_processor_info` (IOKit)
- Memory data via `host_statistics64` + `vm.swapusage` sysctl
- Network data via Darwin `getifaddrs`
- `dispatch_once`-safe singleton pattern for `InterfaceNamer`
- macOS 13 Ventura minimum deployment target

---

*beeMon is crafted by Daneyand & IBM's Bob 🐝*
