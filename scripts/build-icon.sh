#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
MASTER="$TMP/AppIcon.png"
OUT="$ROOT/Resources/AppIcon.icns"

mkdir -p "$ICONSET" "$ROOT/Resources"

echo "Generating master PNG…"
swift "$SCRIPT_DIR/generate-icon.swift" "$MASTER"

echo "Resizing into iconset…"
sips -z   16   16 "$MASTER" --out "$ICONSET/icon_16x16.png"       >/dev/null
sips -z   32   32 "$MASTER" --out "$ICONSET/icon_16x16@2x.png"    >/dev/null
sips -z   32   32 "$MASTER" --out "$ICONSET/icon_32x32.png"       >/dev/null
sips -z   64   64 "$MASTER" --out "$ICONSET/icon_32x32@2x.png"    >/dev/null
sips -z  128  128 "$MASTER" --out "$ICONSET/icon_128x128.png"     >/dev/null
sips -z  256  256 "$MASTER" --out "$ICONSET/icon_128x128@2x.png"  >/dev/null
sips -z  256  256 "$MASTER" --out "$ICONSET/icon_256x256.png"     >/dev/null
sips -z  512  512 "$MASTER" --out "$ICONSET/icon_256x256@2x.png"  >/dev/null
sips -z  512  512 "$MASTER" --out "$ICONSET/icon_512x512.png"     >/dev/null
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

echo "Assembling icns…"
iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"
