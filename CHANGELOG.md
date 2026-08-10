# beeMon Changelog

All notable changes to beeMon are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.2] — 2026-08-10

### Fixed
- **Overview tab layout** — window now auto-sizes to exactly fit its content
  (no dead space below the last widget); other tabs keep a fixed 680 pt scroll
  area so the window stays consistent when switching tabs
- **Overview CPU card** — restored per-core mini grid below the total sparkline;
  12 cores displayed in a 6-column grid using a new compact `MiniCoreCell`
  (20 px sparkline, live %, thin usage bar); clicking any cell still opens the
  full `CoreZoomOverlay` with User / System / Idle breakdown
- **CPU tab** — full-size `CoreCell` (60 px sparkline) in a 4-column grid is
  completely unchanged; overview and CPU tab are now rendered by separate cell
  types (`MiniCoreCell` vs `CoreCell`)
- **Memory tab** — process table (top-20 by RSS) hidden on Overview card to
  keep the card compact; still fully visible on the Memory tab
- **About page version** — reads `CFBundleShortVersionString` from the app
  bundle at runtime; will always match the installed distributable without
  needing a manual string update on every release

### Added
- **App icon** — cute bee holding a clipboard with CPU / Memory / Network stat
  bars; generated at all macOS icon sizes (16 → 2048 px) by `scripts/make_icon.py`
  using only Pillow (no numpy); packed into `AppIcon.icns` and wired into the
  app bundle via `CFBundleIconFile`
- **DMG distributable** — `release.sh` now produces `beeMon-v<ver>.dmg` in
  addition to the `.zip`; the DMG has a styled Finder window with `beeMon.app`
  and an `/Applications` symlink for drag-to-install
- **`scripts/make_icon.py`** — standalone icon generator; re-run any time to
  regenerate icons from source

### Technical
- `isOverview: Bool = false` parameter added to `CPUView` and `MemoryView`;
  the overview passes `true`, the full tabs pass nothing (default `false`)
- `MiniCoreCell` struct introduced for the overview core grid
- `GeometryReader` removed from `overviewGrid`; replaced with a plain `VStack`
  so the window can use `.fixedSize(horizontal: true, vertical: true)`

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
