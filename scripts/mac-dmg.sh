#!/bin/bash
# museo for mac, as a dmg anyone can open: built, signed with your Developer ID, checked by
# Apple (notarized), and stapled, so it opens on another mac with no warning.
#
#   scripts/mac-dmg.sh            build, sign, notarize, and write mac/build/museo-<version>.dmg
#   scripts/mac-dmg.sh unsigned   the same dmg without Apple's check (other macs will warn)
#
# It also writes mac/build/release/appcast.xml, the file a released museo reads to find its
# next version. Bump CFBundleShortVersionString AND CFBundleVersion in mac/Info.plist before
# each release: museo only updates to a build whose CFBundleVersion is higher than its own.
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

# A released build keeps its update feed (a build made with mac.sh alone drops it).
MUSEO_RELEASE=1 "$ROOT/scripts/mac.sh" build

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
  # Sparkle's own helpers first, innermost out, as its docs ask: each needs the hardened
  # runtime, and the downloader keeps the entitlements it shipped with.
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
  if [ -d "$SPARKLE" ]; then
    sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }
    sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
    sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
    sign "$SPARKLE/Versions/B/Autoupdate"
    sign "$SPARKLE/Versions/B/Updater.app"
    sign "$SPARKLE"
  fi
  # Then museo itself. The hardened runtime and a secure timestamp: Apple's check asks for both.
  codesign --force --options runtime --timestamp \
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

# The appcast: the small file museo reads to learn there is a newer build. Each dmg in
# mac/build/release is listed with a signature from museo's update key (in your keychain,
# made once by Sparkle's generate_keys --account museo). Upload the dmg and appcast.xml to
# the folder FEED points at.
if [ "${1:-}" != "unsigned" ]; then
  FEED="${MUSEO_FEED_PREFIX:-https://4ff.com/museo/mac/}"
  RELEASE="$MAC/build/release"
  TOOLS="$MAC/.build/artifacts/sparkle/Sparkle/bin"
  mkdir -p "$RELEASE"
  cp "$DMG" "$RELEASE/"
  "$TOOLS/generate_appcast" --account museo --download-url-prefix "$FEED" -o "$RELEASE/appcast.xml" "$RELEASE"
  echo "wrote ${RELEASE#$ROOT/}/appcast.xml · upload it and $(basename "$DMG") to $FEED"
fi
