#!/usr/bin/env bash
# Builds KeyboardPlugin.bundle. Run from the Plugins/KeyboardPlugin directory.
set -euo pipefail

PLUGIN_NAME=KeyboardPlugin
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
    <string>com.example.nanobar.keyboard-plugin</string>
    <key>CFBundleName</key>
    <string>KeyboardPlugin</string>
    <key>CFBundleExecutable</key>
    <string>KeyboardPlugin</string>
    <key>NSPrincipalClass</key>
    <string>KeyboardPlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  [plugins.keyboard]"
echo "  bundle = \"$BUNDLE_PATH\""
echo "  color  = \"#DDB6F2\""
