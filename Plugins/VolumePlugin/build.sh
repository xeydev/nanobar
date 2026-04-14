#!/usr/bin/env bash
# Builds VolumePlugin.bundle. Run from the Plugins/VolumePlugin directory.
set -euo pipefail

PLUGIN_NAME=VolumePlugin
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
    <string>com.example.nanobar.volume-plugin</string>
    <key>CFBundleName</key>
    <string>VolumePlugin</string>
    <key>CFBundleExecutable</key>
    <string>VolumePlugin</string>
    <key>NSPrincipalClass</key>
    <string>VolumePlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  [plugins.volume]"
echo "  bundle = \"$BUNDLE_PATH\""
echo "  color  = \"#AEC6CF\""
