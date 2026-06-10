#!/bin/zsh
# Builds MacClipboard.app into the project root.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="MacClipboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/MacClipboard "$APP/Contents/MacOS/MacClipboard"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.leonmendel.macclipboard</string>
    <key>CFBundleName</key>
    <string>MacClipboard</string>
    <key>CFBundleExecutable</key>
    <string>MacClipboard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the Accessibility (TCC) grant survives rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP — launch with: open $APP"
