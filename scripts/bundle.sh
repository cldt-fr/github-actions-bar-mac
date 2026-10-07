#!/usr/bin/env bash
# Builds a release binary and wraps it into build/ActionsBar.app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ActionsBar.app"
FLAGS=(-c release --arch arm64 --arch x86_64)

swift build "${FLAGS[@]}"
BIN_DIR="$(swift build "${FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ActionsBar" "$APP/Contents/MacOS/ActionsBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon: Resources/AppIcon.png (1024×1024) -> AppIcon.icns
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run locally, use notifications and launch at login.
codesign --force --deep --sign - "$APP"

echo "✅ $APP"
