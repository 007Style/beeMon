# Contributing to beeMon

Thank you for your interest in contributing! beeMon is a native macOS app
written in pure Swift / SwiftUI with no third-party dependencies.

---

## Requirements

| Tool | Version |
|------|---------|
| macOS | 13 Ventura or later |
| Xcode | 15+ |
| Swift | 5.9+ |

---

## Getting started

```bash
git clone https://github.com/007Style/beeMon.git
cd beeMon
swift build          # debug build
swift run            # build and launch
```

Or open in Xcode:

```bash
open Package.swift
```

---

## Project layout

```
Sources/beeMon/
├── main.swift                  # AppDelegate, NSApplication bootstrap
├── Info.plist                  # Bundle metadata (excluded from SPM compile)
├── Models/
│   ├── SystemMonitor.swift     # CPU / memory / network sampling (IOKit + Darwin)
│   └── InterfaceNamer.swift    # Friendly names for network interfaces
├── Charts/
│   └── SparklineChart.swift    # Canvas-based sparkline components
├── Views/
│   ├── DesignSystem.swift      # DS tokens, MetricCard, TimeWindowPicker, helpers
│   ├── DashboardView.swift     # Tabbed main window
│   ├── CPUView.swift           # CPU section + core zoom overlay
│   ├── MemoryView.swift        # Memory section + tooltip popovers
│   ├── NetworkView.swift       # Network section with interface rows
│   └── AboutView.swift         # About panel
└── Tray/
    └── TrayController.swift    # NSStatusItem sparkline icon + window management

Tests/beeMonTests/
└── beeMonTests.swift           # Unit tests for models and helpers

scripts/
├── build.sh                    # Debug / release build
├── test.sh                     # Run test suite
├── release.sh                  # Build .app bundle + zip for distribution
└── lint.sh                     # swift-format + SwiftLint (optional)
```

---

## Scripts

```bash
./scripts/build.sh              # debug build
./scripts/build.sh --release    # release build
./scripts/test.sh               # run unit tests
./scripts/release.sh 1.0.0      # package dist/beeMon.app + zip
./scripts/lint.sh               # lint (requires swift-format / swiftlint)
```

---

## Running tests

```bash
swift test
# or
./scripts/test.sh
```

Tests cover `RollingBuffer`, `formatBytes`, `InterfaceNamer` fallback logic,
`MemorySample`, `CPUSample`, `InterfaceStats`, and `TimeWindow`.

---

## Code style

- Follow existing file and `// MARK: -` section structure
- No third-party dependencies — use only Apple frameworks
- All UI must compile for macOS 13+
- Keep `@MainActor` on anything that touches `SystemMonitor.shared`
- New data-layer changes should include a corresponding unit test

---

## Submitting a pull request

1. Fork the repo and create a branch: `git checkout -b feat/my-feature`
2. Make your changes with clear, focused commits
3. Run `./scripts/test.sh` and confirm all tests pass
4. Open a PR against `main` with a clear description

---

*beeMon is crafted by Daneyand & IBM's Bob 🐝*
