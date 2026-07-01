#!/bin/bash
# MacClean DMG Packaging & Notarization Script
# Usage: ./package.sh [--notarize]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_PATH="$BUILD_DIR/MacClean.dmg"
NOTARIZE=${1:---skip-notarize}

echo "=== MacClean Packaging ==="
echo ""

# Ensure the app is built
if [ ! -d "$BUILD_DIR/MacClean.app" ]; then
    echo "Building app first..."
    "$PROJECT_DIR/build.sh"
fi

echo "[1/4] Preparing DMG..."
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$BUILD_DIR/MacClean.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "[2/4] Creating DMG..."
hdiutil create -volname "MacClean" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" 2>&1

rm -rf "$STAGING"
echo "  ✅ DMG: $DMG_PATH"

# Notarization
if [ "$NOTARIZE" == "--notarize" ]; then
    echo "[3/4] Submitting for notarization..."
    if [ -z "${APPLE_ID:-}" ] || [ -z "${TEAM_ID:-}" ]; then
        echo "  ⚠ Set APPLE_ID and TEAM_ID environment variables for notarization"
        echo "  Skipping notarization."
    else
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "@keychain:AC_PASSWORD" \
            --wait 2>&1

        echo "[4/4] Stapling notarization ticket..."
        xcrun stapler staple "$DMG_PATH" 2>&1
        echo "  ✅ Notarization complete"
    fi
else
    echo "[3/4] Skipping notarization (pass --notarize to enable)"
    echo "[4/4] Done"
fi

echo ""
echo "📦 DMG ready: $DMG_PATH"
SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "   Size: $SIZE"
echo ""
echo "To notarize: APPLE_ID=\"you@example.com\" TEAM_ID=\"YOURTEAMID\" ./package.sh --notarize"
