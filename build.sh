#!/bin/bash
set -e
swift build -c release
codesign --sign - --identifier "com.apple.controlcenter.NowPlayingHelper" --force .build/release/NowPlayingHelper
echo "Build complete"
