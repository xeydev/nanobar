#!/usr/bin/env bash
# Builds all plugins and NanoBar in DEBUG mode, links bundles, then runs NanoBar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DEST="$ROOT/.build/debug/Plugins"

echo "── plugins ──"
for plugin_dir in "$ROOT/Plugins"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    echo "  $plugin_name"
    (cd "$plugin_dir" && bash build.sh 2>&1) | grep -E "error:|warning:.*error|Built:|Signing|Building" || true
done

echo "── NanoBar (debug) ──"
(cd "$ROOT" && swift build 2>&1 | grep -E "error:|Build complete|warning:" || true)

echo "── linking ──"
mkdir -p "$PLUGINS_DEST"
for plugin_dir in "$ROOT/Plugins"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    bundle="$plugin_dir/$plugin_name.bundle"
    [ -d "$bundle" ] && ln -sfn "$(realpath "$bundle")" "$PLUGINS_DEST/$plugin_name.bundle"
done

echo "── starting (debug) ──"
pkill -x NanoBar 2>/dev/null || true
sleep 0.3
"$ROOT/.build/debug/NanoBar" 2>&1 | tee /tmp/nanobar-debug.log &
echo "PID $!  |  log: /tmp/nanobar-debug.log"
