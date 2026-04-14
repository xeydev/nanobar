#!/usr/bin/env bash
# Builds TmuxPlugin.bundle from the Swift package.
# Run from the Plugins/TmuxPlugin directory.
set -euo pipefail

PLUGIN_NAME=TmuxPlugin
BUNDLE="${PLUGIN_NAME}.bundle"

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
    <string>com.example.nanobar.tmux-plugin</string>
    <key>CFBundleName</key>
    <string>TmuxPlugin</string>
    <key>CFBundleExecutable</key>
    <string>TmuxPlugin</string>
    <key>NSPrincipalClass</key>
    <string>TmuxPlugin</string>
    <key>NanoBarKitVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

BUNDLE_PATH="$(pwd)/$BUNDLE"
echo "Built: $BUNDLE_PATH"
echo ""
echo "Add to config.toml:"
echo "  right = [\"tmux\", ...]"
echo ""
echo "  [plugins.tmux]"
echo "  bundle = \"$BUNDLE_PATH\""
echo "  color  = \"#B5EAD7\""
