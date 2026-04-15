#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/Syphon-Framework"
OUT_DIR="$SCRIPT_DIR/Frameworks"

if [ -d "$OUT_DIR/Syphon.framework" ]; then
    echo "Syphon.framework already present in $OUT_DIR — skipping build."
    echo "Delete it to rebuild."
    exit 0
fi

if [ ! -d "$SRC_DIR" ]; then
    echo "Cloning Syphon-Framework…"
    git clone --depth 1 https://github.com/Syphon/Syphon-Framework.git "$SRC_DIR"
fi

echo "Building Syphon.framework (Release, universal)…"
cd "$SRC_DIR"
xcodebuild \
    -project Syphon.xcodeproj \
    -target Syphon \
    -configuration Release \
    -arch arm64 -arch x86_64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    BUILD_DIR="$SRC_DIR/build" \
    build

mkdir -p "$OUT_DIR"
cp -R "$SRC_DIR/build/Release/Syphon.framework" "$OUT_DIR/"
echo "Syphon.framework installed at $OUT_DIR/Syphon.framework"
