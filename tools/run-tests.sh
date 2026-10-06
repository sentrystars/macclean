#!/bin/bash
# 逻辑测试：用 swiftc 直接编译测试运行器并执行（不依赖 xcodebuild / XCTest）。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/tests"
CACHE_DIR="$PROJECT_DIR/build/ModuleCache"
TMP_DIR="$PROJECT_DIR/build/tmp"

mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$TMP_DIR"
export TMPDIR="$TMP_DIR"

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
ARCH="$(uname -m)"

if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
  echo "❌ 找不到 macOS SDK" >&2
  exit 1
fi

echo "==> 编译测试运行器"
"$SWIFTC" \
  -sdk "$SDK_PATH" \
  -target "${ARCH}-apple-macos14.0" \
  -module-cache-path "$CACHE_DIR" \
  -swift-version 6 \
  -Xfrontend -disable-sandbox \
  -Onone \
  -o "$BUILD_DIR/MacCleanTests" \
  "$PROJECT_DIR"/MacClean/Models/*.swift \
  "$PROJECT_DIR"/MacClean/Services/*.swift \
  "$PROJECT_DIR"/MacClean/Utilities/*.swift \
  "$PROJECT_DIR"/MacClean/Extensions/*.swift \
  "$PROJECT_DIR"/MacCleanTests/*.swift

echo "==> 运行测试"
"$BUILD_DIR/MacCleanTests"