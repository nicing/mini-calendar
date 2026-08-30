#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/.build/MiniCalendar.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FONT_FILE="$PROJECT_DIR/Resources/MiSansLatinVF.ttf"

cd "$PROJECT_DIR"

if [[ ! -f "$FONT_FILE" ]]; then
    echo "Missing Resources/MiSansLatinVF.ttf"
    echo "Download MiSans Latin from https://hyperos.mi.com/font/en/download/"
    echo "and place MiSansLatinVF.ttf in the Resources directory."
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR"
clang \
    -fobjc-arc \
    -fmodules \
    -mmacosx-version-min=14.0 \
    -framework Cocoa \
    -framework EventKit \
    -framework QuartzCore \
    -framework CoreText \
    "$PROJECT_DIR"/Sources/*.m \
    -o "$CONTENTS_DIR/MacOS/MiniCalendar"

cp "$FONT_FILE" "$RESOURCES_DIR/MiSansLatinVF.ttf"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>极简日历</string>
    <key>CFBundleExecutable</key>
    <string>MiniCalendar</string>
    <key>CFBundleIdentifier</key>
    <string>com.lizhenyang.minicalendar</string>
    <key>CFBundleName</key>
    <string>极简日历</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>用于在极简日历中显示、创建、完成和删除您的系统提醒事项。</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>用于在极简日历中只读展示您选择日期的系统日程；极简日历不会创建或修改日程。</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"
