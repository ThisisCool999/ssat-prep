#!/bin/bash
# Builds SSAT Prep in release mode (universal: Apple Silicon + Intel) and
# assembles a signed, Hardened-Runtime "SSAT Prep.app" next to Package.swift.
#
# Ad-hoc by default (works with no Apple account). For a distributable build:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./Scripts/make_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_ID="${SIGN_ID:--}"
ENTITLEMENTS="Scripts/SSATPrep.entitlements"

echo "Building universal release (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release/SSATPrep"
[ -f "$BIN" ] || BIN=".build/release/SSATPrep"

APP="SSAT Prep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SSATPrep"

# Strip local/debug symbols before signing — must run BEFORE codesign
# (stripping invalidates the signature).
strip -x "$APP/Contents/MacOS/SSATPrep"

cp Scripts/Info.plist "$APP/Contents/Info.plist"
if [ -f Scripts/AppIcon.icns ]; then
  cp Scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

if [ "$SIGN_ID" != "-" ]; then
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$SIGN_ID" "$APP"
else
  codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS" --sign "-" "$APP"
fi

echo "Built $(pwd)/$APP  (identity: $SIGN_ID)"
echo -n "  arch: "; lipo -archs "$APP/Contents/MacOS/SSATPrep" 2>/dev/null || echo "?"
echo "  size: $(du -sh "$APP" | cut -f1)"
