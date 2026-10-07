#!/usr/bin/env bash
# Builds ActionsBar.app and packages it as build/ActionsBar-<version>.dmg (+ .zip).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"

STAGING="$(mktemp -d)"
cp -R build/ActionsBar.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="build/ActionsBar-$VERSION.dmg"
ZIP="build/ActionsBar-$VERSION.zip"
rm -f "$DMG" "$ZIP"
hdiutil create -volname "ActionsBar" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DMG" >/dev/null
ditto -c -k --keepParent build/ActionsBar.app "$ZIP"

shasum -a 256 "$DMG" "$ZIP"
