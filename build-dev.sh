#!/usr/bin/env bash
# Builds all plugins and the main app, then links bundles into .build/debug/Plugins/
# so the zero-config auto-discovery works during development.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DEST="$ROOT/.build/debug/Plugins"

echo "── Building plugins ──────────────────────────────────────────────────────"
for plugin_dir in "$ROOT/Plugins"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    echo "  $plugin_name"
    (cd "$plugin_dir" && bash build.sh > /dev/null)
done

echo "── Building NanoBar ──────────────────────────────────────────────────────"
(cd "$ROOT" && swift build)

echo "── Linking bundles into .build/debug/Plugins/ ────────────────────────────"
mkdir -p "$PLUGINS_DEST"
for plugin_dir in "$ROOT/Plugins"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    bundle="$plugin_dir/$plugin_name.bundle"
    if [ -d "$bundle" ]; then
        ln -sfn "$bundle" "$PLUGINS_DEST/$plugin_name.bundle"
        echo "  linked $plugin_name.bundle"
    fi
done

echo "── Done ──────────────────────────────────────────────────────────────────"
echo "Run: .build/debug/NanoBar"
