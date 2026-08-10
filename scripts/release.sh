#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# release.sh  —  Build, bundle, and package beeMon for distribution
#
# Produces:
#   dist/beeMon.app          — macOS .app bundle (drag-to-install)
#   dist/beeMon-v<ver>.zip   — zipped bundle ready for GitHub release
#
# Usage:  ./scripts/release.sh [version]
#   e.g.  ./scripts/release.sh 1.0.0
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

VERSION="${1:-1.0.0}"
APP_NAME="beeMon"
DIST="$ROOT/dist"
APP_BUNDLE="$DIST/$APP_NAME.app"
BINARY="$ROOT/.build/release/$APP_NAME"

echo "🐝 beeMon — release build v$VERSION"
echo ""

# ── 1. Compile ────────────────────────────────────────────────────────────────
echo "▸ Building release binary…"
swift build -c release
echo "  Binary: $BINARY ($(du -sh "$BINARY" | cut -f1))"

# ── 2. Create .app bundle structure ─────────────────────────────────────────
echo "▸ Creating .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>      <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>       <string>com.beemon.app</string>
    <key>CFBundleVersion</key>          <string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleExecutable</key>       <string>$APP_NAME</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHighResolutionCapable</key>  <true/>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>NSHumanReadableCopyright</key> <string>© 2026 Daneyand &amp; IBM's Bob</string>
</dict>
</plist>
PLIST

# Write a minimal PkgInfo
printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "  Bundle: $APP_BUNDLE"

# ── 3. Ad-hoc code sign ──────────────────────────────────────────────────────
echo "▸ Code-signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 && echo "  Signed." || echo "  ⚠️  codesign skipped (run on macOS with Xcode installed)"

# ── 4. Zip for distribution ──────────────────────────────────────────────────
echo "▸ Creating distribution archive…"
mkdir -p "$DIST"
ZIPFILE="$DIST/$APP_NAME-v$VERSION.zip"
cd "$DIST"
zip -qr "$ZIPFILE" "$APP_NAME.app"
cd "$ROOT"
echo "  Archive: $ZIPFILE ($(du -sh "$ZIPFILE" | cut -f1))"

# ── 5. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "✅  Release v$VERSION complete!"
echo ""
echo "   App bundle : dist/$APP_NAME.app"
echo "   Zip archive: dist/$APP_NAME-v$VERSION.zip"
echo ""
echo "   To install: drag dist/$APP_NAME.app to /Applications"
echo "   To release: gh release create v$VERSION dist/$APP_NAME-v$VERSION.zip \\"
echo "               --title 'beeMon v$VERSION' --notes-file CHANGELOG.md"
