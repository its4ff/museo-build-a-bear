#!/bin/bash
# museo for mac, as a dmg anyone can open: built, signed with your Developer ID, checked by
# Apple (notarized), and stapled, so it opens on another mac with no warning.
#
#   scripts/mac-dmg.sh            build, sign, notarize, and write mac/build/museo-<version>.dmg
#   scripts/mac-dmg.sh unsigned   the same dmg without Apple's check (other macs will warn)
#
# Once, before the first run:
#   1. A "Developer ID Application" certificate in your keychain (Xcode › Settings › Accounts ›
#      your team › Manage Certificates › + › Developer ID Application).
#   2. Your sign-in for Apple's check, kept in the keychain under the name museo-notary:
#        xcrun notarytool store-credentials museo-notary --apple-id <you> --team-id <team>
#      It asks for an app-specific password (appleid.apple.com › Sign-In and Security).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAC="$ROOT/mac"
APP="$MAC/build/museo.app"
PROFILE="${MUSEO_NOTARY_PROFILE:-museo-notary}"

"$ROOT/scripts/mac.sh" build

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo 0)"
DMG="$MAC/build/museo-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

if [ "${1:-}" != "unsigned" ]; then
  IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
  if [ -z "$IDENTITY" ]; then
    echo "no Developer ID Application certificate in the keychain. see the top of this script."
    exit 1
  fi
  # The hardened runtime and a secure timestamp: Apple's check asks for both.
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$MAC/museo.entitlements" --sign "$IDENTITY" "$APP"
  codesign --verify --strict --deep "$APP"
  echo "signed · $IDENTITY"

  # The app first, so its own ticket is stapled and it opens offline too.
  ditto -c -k --keepParent "$APP" "$STAGE/museo.zip"
  xcrun notarytool submit "$STAGE/museo.zip" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
fi

# The dmg: the app beside a way into Applications.
mkdir "$STAGE/museo"
ditto "$APP" "$STAGE/museo/museo.app"
ln -s /Applications "$STAGE/museo/Applications"
rm -f "$DMG"
hdiutil create -volname "museo" -srcfolder "$STAGE/museo" -format UDZO -ov "$DMG" >/dev/null

if [ "${1:-}" != "unsigned" ]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG" || true
fi

echo "wrote ${DMG#$ROOT/}"
