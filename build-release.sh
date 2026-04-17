#!/usr/bin/env bash
# Build NanoBar + all plugins in release mode and stage artifacts into dist/.
# Output: dist/ directory + nanobar-<version>-arm64.tar.gz
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0-dev")}"
DIST="$REPO_ROOT/dist"
TARBALL="$REPO_ROOT/nanobar-${VERSION}-arm64.tar.gz"

echo "==> Building NanoBar ${VERSION}"

# Clean staging dir
rm -rf "$DIST"
mkdir -p "$DIST/libexec/Plugins" "$DIST/bin"

# ── Main package (NanoBar + NowPlayingHelper) ──────────────────────────────
cd "$REPO_ROOT"
swift build -c release 2>&1 | grep -E "error:|Build complete|warning: "

cp .build/release/NanoBar "$DIST/libexec/NanoBar"
cp .build/release/NowPlayingHelper "$DIST/libexec/NowPlayingHelper"
cp .build/release/libNanoBarPluginAPI.dylib "$DIST/libexec/libNanoBarPluginAPI.dylib"

# NowPlayingHelper must carry the controlcenter identifier for MediaRemote access
codesign --sign - \
  --identifier "com.apple.controlcenter.NowPlayingHelper" \
  --force "$DIST/libexec/NowPlayingHelper"

echo "  NanoBar + NowPlayingHelper built and signed"

# ── Plugins ───────────────────────────────────────────────────────────────
for plugin_dir in "$REPO_ROOT/Plugins"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    echo "==> Building $plugin_name"
    (cd "$plugin_dir" && bash build.sh 2>&1 | grep -E "error:|Build complete|warning: ")
    bundle="$plugin_dir/${plugin_name}.bundle"
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$DIST/libexec/Plugins/"
        echo "  Copied ${plugin_name}.bundle"
    else
        echo "  WARNING: expected bundle not found at $bundle" >&2
    fi
done

# ── Wrapper script ─────────────────────────────────────────────────────────
cat > "$DIST/bin/nanobar" << 'WRAPPER'
#!/usr/bin/env bash
exec "$(dirname "$(realpath "$0")")/../libexec/NanoBar" "$@"
WRAPPER
chmod +x "$DIST/bin/nanobar"

# ── Tarball ────────────────────────────────────────────────────────────────
tar czf "$TARBALL" -C "$DIST" .
SHA256="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"

echo ""
echo "==> Done"
echo "    Tarball : $TARBALL"
echo "    SHA256  : $SHA256"
echo "    Version : $VERSION"
echo ""
echo "Update homebrew-tap Formula/nanobar.rb:"
echo "  sha256 \"$SHA256\""
