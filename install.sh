#!/usr/bin/env bash
set -euo pipefail

BINARY_DEST="/usr/local/bin/nanobar"
PLIST_SRC="$(dirname "$0")/com.user.nanobar.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.nanobar.plist"
AEROSPACE_CONFIG="$HOME/.aerospace.toml"

echo "==> Building NanoBar (release)..."
swift build -c release

echo "==> Installing binary to $BINARY_DEST..."
sudo cp .build/release/NanoBar "$BINARY_DEST"
sudo codesign --force --sign - "$BINARY_DEST"

echo "==> Installing LaunchAgent..."
cp "$PLIST_SRC" "$PLIST_DEST"

# Unload old instance if running
launchctl unload "$PLIST_DEST" 2>/dev/null || true

launchctl load "$PLIST_DEST"

echo "==> Patching ~/.aerospace.toml..."
if grep -q "sketchybar" "$AEROSPACE_CONFIG"; then
    # Replace sketchybar startup with nanobar
    sed -i '' "s|exec-and-forget sketchybar|exec-and-forget $BINARY_DEST|g" "$AEROSPACE_CONFIG"
    # Replace exec-on-workspace-change to notify nanobar via socket
    sed -i '' "s|exec-on-workspace-change = .*|exec-on-workspace-change = ['/bin/bash', '-c', 'printf \"%s\" \"\$AEROSPACE_FOCUSED_WORKSPACE\" \| nc -U /tmp/nanobar-notify.sock']|g" "$AEROSPACE_CONFIG"
    echo "   Patched AeroSpace config. You may want to review the changes:"
    grep -A2 "exec-on-workspace-change\|exec-and-forget" "$AEROSPACE_CONFIG" | head -20
fi

echo ""
echo "Done! NanoBar is running."
echo "Logs: /tmp/nanobar.log  /tmp/nanobar.err"
echo ""
echo "NOTE: If you still have SketchyBar running, stop it with:"
echo "  brew services stop sketchybar"
