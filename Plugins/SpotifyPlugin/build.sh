#!/usr/bin/env bash
# Builds SpotifyPlugin.bundle from the Swift package.
# Run from the Plugins/SpotifyPlugin directory.
set -euo pipefail

PLUGIN_NAME=SpotifyPlugin
BUNDLE="${PLUGIN_NAME}.bundle"
NANOBAR_DIR="../.."

# Build NowPlayingHelper (needed at runtime by the plugin)
echo "Building NowPlayingHelper..."
swift build -c release --package-path "$NANOBAR_DIR" --product NowPlayingHelper

HELPER="$NANOBAR_DIR/.build/release/NowPlayingHelper"

# Re-sign NowPlayingHelper with com.apple.controlcenter identifier so
# MediaRemote reports reliable now-playing state.
echo "Signing NowPlayingHelper as com.apple.controlcenter..."
codesign --force --sign - --identifier com.apple.controlcenter "$HELPER"

# Build the plugin
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
    <string>com.example.nanobar.spotify-plugin</string>
    <key>CFBundleName</key>
    <string>SpotifyPlugin</string>
    <key>CFBundleExecutable</key>
    <string>SpotifyPlugin</string>
    <key>NSPrincipalClass</key>
    <string>SpotifyPlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  center = [\"now_playing\"]"
echo ""
echo "  [plugins.now_playing]"
echo "  bundle      = \"$BUNDLE_PATH\""
echo "  activeColor = \"#B5EAD7\""
