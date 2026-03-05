#!/usr/bin/env bash
# create-dmg.sh — Package CallTranscriber.app into a distributable DMG.
#
# Requires: create-dmg (brew install create-dmg)
#
# Usage: ./Scripts/create-dmg.sh --app path/to/CallTranscriber.app [--version 1.0.0]

set -euo pipefail

APP_PATH=""
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/../dist"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP_PATH="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

[[ -z "$APP_PATH" ]] && { echo "Usage: $0 --app <path> [--version <ver>]"; exit 1; }
[[ ! -d "$APP_PATH" ]] && { echo "❌ App not found: $APP_PATH"; exit 1; }

if ! command -v create-dmg &>/dev/null; then
    echo "❌ create-dmg not found. Install it: brew install create-dmg"
    exit 1
fi

mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/CallTranscriber-$VERSION.dmg"

echo "📀 Creating DMG: $DMG_PATH"

create-dmg \
    --volname "Call Transcriber $VERSION" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "CallTranscriber.app" 180 170 \
    --hide-extension "CallTranscriber.app" \
    --app-drop-link 480 170 \
    --background "$SCRIPT_DIR/dmg-background.png" \
    "$DMG_PATH" \
    "$APP_PATH" \
    || true  # create-dmg exits 1 if background is missing; app still created

if [ -f "$DMG_PATH" ]; then
    echo "✅ DMG created: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"
else
    # Fallback: basic hdiutil approach
    echo "⚠️  create-dmg had issues, falling back to hdiutil..."
    STAGING=$(mktemp -d)
    cp -r "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "Call Transcriber" \
        -srcfolder "$STAGING" \
        -ov -format UDZO \
        "$DMG_PATH"
    rm -rf "$STAGING"
    echo "✅ DMG created: $DMG_PATH"
fi
