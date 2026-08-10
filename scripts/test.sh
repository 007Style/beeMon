#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# test.sh  —  Run the beeMon test suite
# Usage:  ./scripts/test.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

echo "🐝 beeMon — running tests…"
swift test --parallel 2>&1

echo ""
echo "✅  All tests passed."
