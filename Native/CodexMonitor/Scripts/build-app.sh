#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_ROOT="$PROJECT_DIR/.build/app"
APP_PATH="$BUILD_ROOT/Codex Monitor.app"
ICONSET_PATH="$BUILD_ROOT/AppIcon.iconset"

cd "$PROJECT_DIR"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

rm -rf "$APP_PATH" "$ICONSET_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$BUILD_ROOT"

cp "$BIN_PATH/CodexMonitor" "$APP_PATH/Contents/MacOS/CodexMonitor"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"

swift "$PROJECT_DIR/Scripts/generate-icon.swift" "$ICONSET_PATH"
iconutil -c icns "$ICONSET_PATH" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_PATH"

codesign --force --deep --sign - "$APP_PATH"
printf '%s\n' "$APP_PATH"
