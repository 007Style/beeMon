#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build.sh  —  Debug build for beeMon
# Usage:  ./scripts/build.sh [--release]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

CONFIG="debug"
if [[ "${1:-}" == "--release" ]]; then
  CONFIG="release"
fi

echo "🐝 beeMon — building ($CONFIG)…"
swift build -c "$CONFIG"

BINARY=".build/$CONFIG/beeMon"
echo ""
echo "✅  Build complete: $BINARY"
echo "    Size: $(du -sh "$BINARY" | cut -f1)"
