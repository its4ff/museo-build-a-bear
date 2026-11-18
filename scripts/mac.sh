#!/bin/bash
# museo for mac: build the menu bar app into mac/build/museo.app, then open it.
#
#   scripts/mac.sh          build and open
#   scripts/mac.sh build    build only
#   scripts/mac.sh log      follow the app's log (the ring's and the app's "[museo]" lines)
#
# museo kit comes from GitHub at the version mac/Package.swift pins. Signs with your first
# Apple Development identity so macOS remembers the bluetooth and accessibility permissions
# between builds; with none it signs ad hoc, and macOS asks again after every build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAC="$ROOT/mac"
APP="$MAC/build/museo.app"
# Not next to the app: the repo may sit in a folder macOS guards (Downloads, Documents), and
# then the app can't open its own log and won't launch.
LOG="$HOME/Library/Logs/museo-mac.log"

if [ "${1:-}" = "log" ]; then
  exec tail -f "$LOG"
fi

swift build -c release --package-path "$MAC" 2>&1 | grep -E "error|warning: .*/mac/Sources|Compiling MuseoMac|Build complete" || true
BIN="$(swift build -c release --package-path "$MAC" --show-bin-path)"
[ -x "$BIN/MuseoMac" ] || { echo "build failed"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/MuseoMac" "$APP/Contents/MacOS/museo"
cp "$MAC/Info.plist" "$APP/Contents/Info.plist"
for bundle in "$BIN"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
# Sparkle (updates) rides inside the app, and the app is told where to find it.
if [ -d "$BIN/Sparkle.framework" ]; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/museo" 2>/dev/null || true
fi
# Only a released build updates itself (scripts/mac-dmg.sh sets MUSEO_RELEASE): a build made
# here drops the feed, so it is never swapped for the public one.
if [ -z "${MUSEO_RELEASE:-}" ]; then
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || true
fi
# Lora and Satoshi, from the iphone app's design folder (one copy of the fonts in the repo).
cp "$ROOT/museo build/Design/Fonts/"*.ttf "$APP/Contents/Resources/"
# The dot ring for the panel (bone dots, from the 4ff site's museo iconography).
cp "$MAC/Resources/"* "$APP/Contents/Resources/"

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
codesign --force --deep --sign "${IDENTITY:--}" "$APP" >/dev/null 2>&1
# A rebuilt bundle at the same path: tell LaunchServices it changed.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "built mac/build/museo.app · signed ${IDENTITY:-ad hoc}"

if [ "${1:-}" != "build" ]; then
  pkill -x museo 2>/dev/null && sleep 1 || true
  : > "$LOG"
  open "$APP" --stdout "$LOG" --stderr "$LOG" --args -quietLaunch YES
  echo "museo is in the menu bar · scripts/mac.sh log to follow it"
fi
