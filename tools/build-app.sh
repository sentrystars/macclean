#!/bin/bash
# 在受限环境（沙箱 / 未安装完整 Xcode / clang 模块缓存不可写）中，
# 直接用 swiftc 编译并组装可运行的 MacClean.app。
#
# 为什么需要它：xcodebuild 在 CreateBuildDescription 阶段会执行一个 clang 探测进程，
# 该进程固定使用 $DARWIN_USER_CACHE_DIR/clang（即 /var/folders/<xx>/<hash>/C/clang），
# 该路径在部分沙箱/CI 环境中不可写，导致 xcodebuild 直接失败。
# swiftc 支持显式 -module-cache-path，因此可以绕过该探测。
#
# 用法：tools/build-app.sh [Debug|Release]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-Release}"
BUILD_DIR="$PROJECT_DIR/build/restricted"
APP="$BUILD_DIR/MacClean.app"
CACHE_DIR="$PROJECT_DIR/build/ModuleCache"
TMP_DIR="$PROJECT_DIR/build/tmp"

mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$TMP_DIR"
export TMPDIR="$TMP_DIR"

# 优先使用 Xcode 工具链；否则退回 Command Line Tools
if [ -z "${DEVELOPER_DIR:-}" ]; then
  for candidate in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$candidate/Contents/Developer" ]; then
      export DEVELOPER_DIR="$candidate/Contents/Developer"
      break
    fi
  done
fi

SWIFTC="$(xcrun --find swiftc 2>/dev/null || echo /usr/bin/swiftc)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
  echo "❌ 找不到 macOS SDK，请安装 Xcode 或 Command Line Tools" >&2
  exit 1
fi

ARCH="$(uname -m)"
echo "==> 编译 MacClean（${CONFIGURATION} / ${ARCH}）"
echo "    工具链: $SWIFTC"
echo "    SDK   : $SDK_PATH"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=$(find "$PROJECT_DIR/MacClean" -name '*.swift' -print)

# shellcheck disable=SC2086
"$SWIFTC" \
  -sdk "$SDK_PATH" \
  -target "${ARCH}-apple-macos14.0" \
  -module-cache-path "$CACHE_DIR" \
  -swift-version 6 \
  -Xfrontend -disable-sandbox \
  -O \
  -o "$APP/Contents/MacOS/MacClean" \
  $SOURCES

echo "==> 组装 App Bundle"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>MacClean</string>
    <key>CFBundleExecutable</key>
    <string>MacClean</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.macclean.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacClean</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 MacClean</string>
</dict>
</plist>
PLIST

if [ -f "$PROJECT_DIR/MacClean/Resources/AppIcon.icns" ]; then
  cp "$PROJECT_DIR/MacClean/Resources/AppIcon.icns" "$APP/Contents/Resources/"
fi

if [ -d "$PROJECT_DIR/MacClean/Resources/Assets.xcassets" ]; then
  "$(xcrun --find actool)" \
    --output-format human-readable-text \
    --output-dir "$APP/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --target-device mac \
    --compress-pngs \
    "$PROJECT_DIR/MacClean/Resources/Assets.xcassets" >/dev/null 2>&1 || \
    echo "    ⚠ actool 跳过（不影响功能）"
fi

for lproj in "$PROJECT_DIR"/MacClean/Resources/*.lproj; do
  [ -d "$lproj" ] || continue
  cp -R "$lproj" "$APP/Contents/Resources/"
done

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "    ⚠ 临时签名失败（本地运行通常仍可）"

echo "✅ 构建完成：${APP}"