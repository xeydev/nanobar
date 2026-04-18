#!/usr/bin/env bash
# Builds PomodoroPlugin.bundle. Run from the Plugins/PomodoroPlugin directory.
set -euo pipefail

PLUGIN_NAME=PomodoroPlugin
BUNDLE="${PLUGIN_NAME}.bundle"

echo "Building $PLUGIN_NAME..."
swift build -c release

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

cp ".build/release/lib${PLUGIN_NAME}.dylib" "$BUNDLE/Contents/MacOS/$PLUGIN_NAME"

cat > "$BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.nanobar.pomodoro-plugin</string>
    <key>CFBundleName</key>
    <string>PomodoroPlugin</string>
    <key>CFBundleExecutable</key>
    <string>PomodoroPlugin</string>
    <key>NSPrincipalClass</key>
    <string>PomodoroPlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  [plugins.pomodoro]"
echo "  work       = \"25\""
echo "  shortBreak = \"5\""
echo "  longBreak  = \"15\""
echo "  sessions   = \"4\""
echo "  workColor  = \"#FF6B6B\""
echo "  breakColor = \"#B5EAD7\""
