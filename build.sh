#!/bin/bash
# Build script for MacClean

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="MacClean"
CONFIGURATION="Release"

echo "=== MacClean Build Script ==="
echo ""

# Step 1: Check for XcodeGen
if command -v xcodegen &>/dev/null; then
	echo "[1/5] Generating Xcode project with XcodeGen..."
	cd "$PROJECT_DIR"
	xcodegen generate
	echo "  ✅ Project generated"
else
	echo "[1/5] XcodeGen not found. Install with: brew install xcodegen"
	echo "  ⚠ Skipping project generation (use existing .xcodeproj if available)"
fi

# Step 2: Build
echo "[2/5] Building $SCHEME ($CONFIGURATION)..."
cd "$PROJECT_DIR"
xcodebuild -project MacClean.xcodeproj \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-derivedDataPath "$BUILD_DIR/DerivedData" \
	build \
	CODE_SIGN_STYLE=Manual \
	CODE_SIGN_IDENTITY="-" \
	CODE_SIGNING_ALLOWED=NO \
	DEVELOPMENT_TEAM="" 2>&1 | tail -20

echo "  ✅ Build completed"

# Step 3: Locate app
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "MacClean.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
	APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/MacClean.app"
fi

if [ -d "$APP_PATH" ]; then
	echo "[3/5] App built at: $APP_PATH"
	rm -rf "$BUILD_DIR/MacClean.app"
	cp -R "$APP_PATH" "$BUILD_DIR/MacClean.app"
	echo "  ✅ Copied to $BUILD_DIR/MacClean.app"
else
	echo "  ⚠ App not found at expected path"
	echo "  🔍 Searching..."
	find "$BUILD_DIR/DerivedData" -name "*.app" -type d 2>/dev/null | head -5
fi

# Step 4: Create DMG with volume icon
if [ -d "$BUILD_DIR/MacClean.app" ]; then
	echo "[4/5] Creating DMG..."

	DMG_PATH="$BUILD_DIR/MacClean.dmg"
	TEMP_DMG="$BUILD_DIR/MacClean-temp.dmg"
	STAGING="$BUILD_DIR/dmg-staging"
	ICON_SRC="$PROJECT_DIR/MacClean/Resources/AppIcon.icns"

	# Detach any previous mount
	hdiutil detach "/Volumes/MacClean" 2>/dev/null || true

	mkdir -p "$STAGING"
	cp -R "$BUILD_DIR/MacClean.app" "$STAGING/"
	ln -s /Applications "$STAGING/Applications"

	# Set volume icon on staging folder
	if [ -f "$ICON_SRC" ]; then
		cp "$ICON_SRC" "$STAGING/.VolumeIcon.icns"
		SetFile -a C "$STAGING" 2>/dev/null || true
	fi

	# Create read-write DMG from staging, then attach
	hdiutil create -volname "MacClean" \
		-srcfolder "$STAGING" \
		-ov -format UDRW \
		"$TEMP_DMG" 2>&1

	rm -rf "$STAGING"

	# Attach and set icon on the volume
	DEVICE=$(hdiutil attach -nobrowse "$TEMP_DMG" 2>/dev/null | grep "/Volumes/MacClean" | awk '{print $1}')
	if [ -n "$DEVICE" ]; then
		sleep 1
		if [ -f "$ICON_SRC" ]; then
			cp "$ICON_SRC" "/Volumes/MacClean/.VolumeIcon.icns" 2>/dev/null || true
			SetFile -a C "/Volumes/MacClean" 2>/dev/null || true
		fi
		hdiutil detach "$DEVICE" 2>&1
	fi

	# Convert to compressed DMG
	rm -f "$DMG_PATH"
	hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH" 2>&1
	rm -f "$TEMP_DMG"

	echo "  ✅ DMG created at: $DMG_PATH"
else
	echo "  ⚠ No app found, skipping DMG creation"
fi

# Step 5: Summary
echo ""
echo "[5/5] Build Summary"
if [ -f "$DMG_PATH" ]; then
	SIZE=$(du -h "$DMG_PATH" | cut -f1)
	echo "  DMG: $DMG_PATH ($SIZE)"
fi
if [ -d "$BUILD_DIR/MacClean.app" ]; then
	APP_SIZE=$(du -sh "$BUILD_DIR/MacClean.app" | cut -f1)
	echo "  App: $BUILD_DIR/MacClean.app ($APP_SIZE)"
fi
echo ""
echo "=== Build Complete ==="
