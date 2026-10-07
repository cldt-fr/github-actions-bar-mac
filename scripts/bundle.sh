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

# Ad-hoc signature: enough to run locally, use notifications and launch at login.
codesign --force --deep --sign - "$APP"

echo "✅ $APP"
