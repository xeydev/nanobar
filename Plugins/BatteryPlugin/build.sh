#!/usr/bin/env bash
# Builds BatteryPlugin.bundle. Run from the Plugins/BatteryPlugin directory.
set -euo pipefail

PLUGIN_NAME=BatteryPlugin
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
    <string>com.example.nanobar.battery-plugin</string>
    <key>CFBundleName</key>
    <string>BatteryPlugin</string>
    <key>CFBundleExecutable</key>
    <string>BatteryPlugin</string>
    <key>NSPrincipalClass</key>
    <string>BatteryPlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  [plugins.battery]"
echo "  bundle    = \"$BUNDLE_PATH\""
echo "  color     = \"#B5EAD7\""
echo "  warnColor = \"#FFD1A8\""
echo "  medColor  = \"#FEFAC1\""
echo "  lowColor  = \"#FFB3BF\""
