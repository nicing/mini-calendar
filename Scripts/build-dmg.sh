#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/.build/MiniCalendar.app"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mini-calendar-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_DIR/Scripts/build-app.sh"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DMG_PATH="$DIST_DIR/MiniCalendar-$APP_VERSION.dmg"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

cp -R "$APP_DIR" "$STAGING_DIR/极简日历.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "极简日历" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

echo "Built $DMG_PATH"
