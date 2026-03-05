#!/usr/bin/env bash
# notarize.sh — Code-sign and notarize CallTranscriber for Developer ID distribution.
#
# Prerequisites:
#   - Valid Developer ID Application certificate in Keychain
#   - App-specific password stored in Keychain (for notarytool)
#   - xcrun notarytool credentials configured
#
# Usage:
#   ./Scripts/notarize.sh \
#     --app path/to/CallTranscriber.app \
#     --team-id XXXXXXXXXX \
#     --bundle-id com.callTranscriber.app \
#     --keychain-profile "notarytool-profile"

set -euo pipefail

APP_PATH=""
TEAM_ID=""
BUNDLE_ID="com.callTranscriber.app"
KEYCHAIN_PROFILE="notarytool-profile"
ENTITLEMENTS="$(dirname "$0")/../CallTranscriber/Resources/CallTranscriber.entitlements"

usage() {
    echo "Usage: $0 --app <path> --team-id <id> [--bundle-id <id>] [--keychain-profile <name>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP_PATH="$2"; shift 2 ;;
        --team-id) TEAM_ID="$2"; shift 2 ;;
        --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
        --keychain-profile) KEYCHAIN_PROFILE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

[[ -z "$APP_PATH" || -z "$TEAM_ID" ]] && usage
[[ ! -d "$APP_PATH" ]] && { echo "❌ App not found: $APP_PATH"; exit 1; }

IDENTITY="Developer ID Application: * ($TEAM_ID)"

echo "🔏 Code signing: $APP_PATH"
codesign --force --deep --timestamp \
    --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP_PATH"

echo "✅ Code signing complete"

# Create zip for notarization
ZIP_PATH="${APP_PATH%.app}.zip"
echo "📦 Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "⬆️  Submitting for notarization (this takes 1-5 minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

rm -f "$ZIP_PATH"

echo ""
echo "✅ Notarization complete: $APP_PATH"
