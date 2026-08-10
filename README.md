# beeMon

A beautiful native macOS system monitor — CPU per-core, memory, and network bandwidth displayed in a sleek dark dashboard with a live tray sparkline.

## Features

- **CPU** — per-core usage with individual sparklines, usage bars, and a total aggregate chart
- **Memory** — used/free breakdown with pressure bar and rolling history
- **Network** — per-interface bandwidth (↓ in / ↑ out) with dual-overlay sparklines
- **2-minute rolling window** for all charts at 1-second intervals
- **Menu bar tray** — compact CPU sparkline icon + percentage, click to toggle dashboard
- **Dark glass UI** — beautiful native SwiftUI design

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (or Swift 5.9+)

## Build & Run

```bash
swift run
```

Or open in Xcode:

```bash
open Package.swift
```

Then **Product → Run**.

## Architecture

```
Sources/beeMon/
├── main.swift              # AppDelegate + NSApplication entry point
├── Models/
│   └── SystemMonitor.swift # CPU/memory/network sampling via IOKit & Darwin
├── Charts/
│   └── SparklineChart.swift # Reusable Canvas-based sparkline components
├── Views/
│   ├── DesignSystem.swift  # Design tokens, MetricCard, SectionHeader helpers
│   ├── DashboardView.swift # Main tabbed dashboard window
│   ├── CPUView.swift       # CPU section with per-core grid
│   ├── MemoryView.swift    # Memory section
│   └── NetworkView.swift   # Network section with per-interface rows
└── Tray/
    └── TrayController.swift # NSStatusItem with live sparkline icon
```

## Usage

- **Left-click** the menu bar icon to open/close the dashboard
- **Right-click** for a menu with Open and Quit options
- Tabs: Overview · CPU · Memory · Network
