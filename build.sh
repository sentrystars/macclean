#!/bin/bash
# MacClean 构建脚本
#
# 优先使用 xcodebuild；当环境无法运行 xcodebuild（例如 clang 模块缓存目录不可写、
# 宏插件沙箱受限）时，自动回退到 tools/build-app.sh（纯 swiftc 构建）。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="MacClean"
APP_PATH="$BUILD_DIR/MacClean.app"

# ---- 受限环境兼容设置 ----------------------------------------------------
# 背景：xcodebuild 在 CreateBuildDescription 阶段会跑一个 clang 探测进程，它固定使用
# $DARWIN_USER_CACHE_DIR/clang（即 /var/folders/<xx>/<hash>/C/clang）。该路径在沙箱/CI
# 中可能不可写，导致 "unable to write module session file" 直接失败。
# 解决办法有两条，这里都做了：
#   1) -derivedDataPath 指向工程内目录：Xcode 会把模块缓存与 TMPDIR 都放进 DerivedData；
#   2) 显式设置 MODULE_CACHE_DIR 与 CLANG_MODULE_CACHE_PATH。
export TMPDIR="$PROJECT_DIR/build/tmp"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/build/ModuleCache"
export SWIFT_MODULE_CACHE_PATH="$PROJECT_DIR/build/ModuleCache"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH"

if [ -z "${DEVELOPER_DIR:-}" ]; then
  for candidate in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$candidate/Contents/Developer" ]; then
      export DEVELOPER_DIR="$candidate/Contents/Developer"
      break
    fi
  done
fi

echo "=== MacClean Build Script ==="

# Step 1: 生成工程（若安装了 XcodeGen）
if command -v xcodegen >/dev/null 2>&1; then
  echo "[1/5] 使用 XcodeGen 生成工程…"
  (cd "$PROJECT_DIR" && xcodegen generate)
else
  echo "[1/5] 未安装 XcodeGen，沿用现有 .xcodeproj（brew install xcodegen 可自动生成）"
fi

# Step 2: 构建
echo "[2/5] 构建 ${SCHEME}（${CONFIGURATION}）…"
BUILT=0
if xcodebuild -project "$PROJECT_DIR/MacClean.xcodeproj" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -derivedDataPath "$BUILD_DIR/DerivedData" \
      MODULE_CACHE_DIR="$CLANG_MODULE_CACHE_PATH" \
      OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
      CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" \
      build; then
  BUILT=1
else
  echo "  ⚠ xcodebuild 失败，回退到 swiftc 构建（tools/build-app.sh）"
  "$PROJECT_DIR/tools/build-app.sh" "$CONFIGURATION"
  rm -rf "$APP_PATH"
  cp -R "$BUILD_DIR/restricted/MacClean.app" "$APP_PATH"
  BUILT=2
fi

# Step 3: 收集产物
if [ "$BUILT" = "1" ]; then
  FOUND=$(find "$BUILD_DIR/DerivedData" -name "MacClean.app" -type d 2>/dev/null | head -1 || true)
  if [ -n "$FOUND" ]; then
    rm -rf "$APP_PATH"
    cp -R "$FOUND" "$APP_PATH"
    echo "[3/5] 应用已复制到 $APP_PATH"
  fi
else
  echo "[3/5] 应用位于 $APP_PATH"
fi

# Step 4: 生成 DMG
if [ -d "$APP_PATH" ]; then
  echo "[4/5] 生成 DMG…"
  DMG_PATH="$BUILD_DIR/MacClean.dmg"
  TEMP_DMG="$BUILD_DIR/MacClean-temp.dmg"
  STAGING="$BUILD_DIR/dmg-staging"
  ICON_SRC="$PROJECT_DIR/MacClean/Resources/AppIcon.icns"

  hdiutil detach "/Volumes/MacClean" >/dev/null 2>&1 || true

  rm -rf "$STAGING"
  mkdir -p "$STAGING"
  cp -R "$APP_PATH" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"

  if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$STAGING/.VolumeIcon.icns"
    SetFile -a C "$STAGING" 2>/dev/null || true
  fi

  rm -f "$DMG_PATH"
  # 磁盘映像创建在沙箱环境中可能被禁止；失败不影响 App 产物。
  if diskutil image create from "$STAGING" --format UDZO --volumeName MacClean "$DMG_PATH" >/dev/null 2>&1 \
     || hdiutil create -volname "MacClean" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null 2>&1; then
    echo "  ✅ DMG：${DMG_PATH}"
  else
    echo "  ⚠ 当前环境不允许创建磁盘映像（沙箱限制），已跳过 DMG。"
    echo "     在普通终端中重新运行本脚本即可生成 DMG。"
  fi
  rm -rf "$STAGING"
  rm -f "$TEMP_DMG"
else
  echo "  ⚠ 未找到应用，跳过 DMG"
fi

echo ""
echo "[5/5] 构建完成"
[ -d "$APP_PATH" ] && echo "  应用：$APP_PATH"
[ -f "$BUILD_DIR/MacClean.dmg" ] && echo "  DMG ：$BUILD_DIR/MacClean.dmg"
echo ""
echo "运行测试：tools/run-tests.sh"