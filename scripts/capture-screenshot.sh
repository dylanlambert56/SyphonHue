#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$ROOT/docs/screenshot.png}"
APP="${2:-SyphonHue}"

mkdir -p "$(dirname "$OUT")"

INFO="$(swift "$SCRIPT_DIR/window-id.swift" "$APP" 2>/dev/null || true)"
if [ -z "$INFO" ]; then
    echo "Window not found for $APP. Launch the app first."
    exit 1
fi

read -r WID X Y W H <<< "$INFO"

# Try window capture first (requires screen recording permission for the calling process).
if screencapture -l "$WID" -x -t png "$OUT" 2>/dev/null; then
    echo "Saved $OUT (window id $WID)"
    exit 0
fi

# Fall back to region capture (no permission required but includes any content behind non-opaque
# parts of the window; acceptable for a rectangular window).
screencapture -R "${X},${Y},${W},${H}" -x -t png "$OUT"
echo "Saved $OUT (region ${X},${Y} ${W}x${H} — window capture blocked by TCC)"
