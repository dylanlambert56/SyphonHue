#!/usr/bin/env bash
set -euo pipefail

# Sign, notarize, and staple SyphonHue.
#
# Requirements:
#   - Developer ID Application certificate in the login keychain
#   - A notarytool keychain profile. Create one once with:
#       xcrun notarytool store-credentials <PROFILE> \
#           --apple-id <YOUR_APPLE_ID>         \
#           --team-id 7M6Z5Y46DT               \
#           --password <APP_SPECIFIC_PASSWORD>
#     Then pass that profile as $PROFILE below (default: "syphonhue-notary").
#
# Usage:
#   PROFILE=my-profile ./scripts/sign-and-notarize.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="${PROFILE:-syphonhue-notary}"

cd "$ROOT"

echo "==> Regenerating Xcode project"
xcodegen generate >/dev/null

echo "==> Building Release"
xcodebuild -scheme SyphonHue -configuration Release \
    -destination 'platform=macOS' \
    clean build 2>&1 | grep -E '(error:|\*\* BUILD)' || true

APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 6 \
    -type d -name 'SyphonHue.app' -path '*/Release/*' | head -1)"
if [ -z "$APP_PATH" ]; then
    echo "Could not locate built SyphonHue.app"
    exit 1
fi
echo "App: $APP_PATH"

echo "==> Verifying signing"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvv --requirements - "$APP_PATH" 2>&1 | grep -E '(Authority|TeamIdentifier|Identifier|Timestamp|Runtime)'

ZIP="$ROOT/SyphonHue.zip"
echo "==> Creating notarization zip at $ZIP"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo "==> Submitting to notarytool (profile: $PROFILE)"
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$PROFILE" \
    --wait

echo "==> Stapling ticket to the .app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

DMG="$ROOT/SyphonHue.dmg"
echo "==> Creating distributable DMG at $DMG"
rm -f "$DMG"
/usr/bin/hdiutil create -fs HFS+ -srcfolder "$APP_PATH" -volname SyphonHue \
    -format UDZO -ov "$DMG" >/dev/null

# Sign and notarize the DMG too so Gatekeeper accepts it with no warnings.
codesign --sign "Developer ID Application" --timestamp --options runtime "$DMG"
echo "==> Submitting DMG to notarytool"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "✅ Done."
echo "   App:  $APP_PATH"
echo "   Zip:  $ZIP"
echo "   DMG:  $DMG"
