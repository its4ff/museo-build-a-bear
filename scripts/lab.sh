#!/bin/bash
# museo build lab: launch the app straight into mock screens (no ring) and screenshot each.
#
#   scripts/lab.sh build                 build (scripts/build.sh), errors printed
#   scripts/lab.sh shots [id ...]        install + capture (every screen in the manifest when no ids)
#   scripts/lab.sh build-shot [id ...]   build, then capture (the default)
#   scripts/lab.sh index                 install and open the browsable index in the simulator
#   scripts/lab.sh udid                  print the lab simulator's udid
#
# Screens live in "museo build/Lab/" (LabRegistry). Each launches with `-museLab <id>`, writes
# Documents/lab-ready when it has settled, and lands in lab-shots/<id>.png.
#
# The simulator is "museo build lab": an iPhone 17 Pro on the newest iOS installed (or the
# newest iPhone that runtime has), made on first use, light appearance, status bar at 9:41. It is only ever this one device: other projects' simulators
# are never booted, changed or used. Everything runs under one machine-wide lock (the simulator
# and bundle id are shared by every checkout), so parallel callers, including other worktrees,
# take turns.
#
# The app is installed from .build/DerivedData, or from $MUSE_DERIVED_DATA when it is set, the
# same folder scripts/build.sh builds into.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${LAB_LOCKED:-}" ]; then
  export LAB_LOCKED=1
  exec /usr/bin/lockf -t 3600 "${TMPDIR:-/tmp}/museo-build-lab.lock" "$0" "$@"
fi

NAME="museo build lab"
PREFERRED_DEVICE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
BID=""   # read from the built app (bid below), so a changed bundle id just works
APP="${MUSE_DERIVED_DATA:-$ROOT/.build/DerivedData}/Build/Products/Debug-iphonesimulator/museo build.app"
OUT="$ROOT/lab-shots"
MANIFEST="$ROOT/.build/lab-manifest.json"
mkdir -p "$OUT" "$ROOT/.build"

# The lab simulator's udid, by exact name. Made on first use.
device() {
  local udid
  udid=$(xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d.get("name") == name and d.get("isAvailable", True):
            print(d["udid"])
            sys.exit(0)
' "$NAME")
  if [ -z "$udid" ]; then
    local pick
    pick=$(newest_iphone) || { echo "no iOS simulator runtime installed (Xcode › Settings › Components)" >&2; return 1; }
    udid=$(xcrun simctl create "$NAME" ${pick}) || return 1
  fi
  echo "$udid"
}

# "<device type> <runtime>" for a new lab simulator: the newest iOS runtime installed, with
# an iPhone 17 Pro when it has one, else its newest iPhone.
newest_iphone() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
preferred = sys.argv[1]
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("platform") == "iOS" and r.get("isAvailable")]
if not runtimes:
    sys.exit(1)
newest = max(runtimes, key=lambda r: [int(p) for p in r["version"].split(".")])
phones = [d["identifier"] for d in newest.get("supportedDeviceTypes", [])
          if d.get("productFamily") == "iPhone"]
if not phones:
    sys.exit(1)
print(preferred if preferred in phones else phones[-1], newest["identifier"])
' "$PREFERRED_DEVICE"
}

UDID=""
need_device() {
  [ -n "$UDID" ] && return 0
  UDID="$(device)" || { echo "couldn't find or make the \"$NAME\" simulator"; return 1; }
  [ -n "$UDID" ] || { echo "couldn't find or make the \"$NAME\" simulator"; return 1; }
}

boot() {
  need_device || return 1
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularMode active --cellularBars 4 >/dev/null 2>&1 || true
}

build() {
  "$ROOT/scripts/build.sh"
}

# The app's bundle id, from the built app, so it follows the Xcode target when you change it.
# Only valid once the build has made the .app.
bid() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null \
    || echo "com.example.museobuild"
}

install_app() {
  [ -d "$APP" ] || { echo "no app at $APP, run scripts/lab.sh build first"; return 1; }
  BID="$(bid)"
  xcrun simctl install "$UDID" "$APP" || { echo "install failed"; return 1; }
}

docs_dir() {
  local data
  data="$(xcrun simctl get_app_container "$UDID" "$BID" data)" || return 1
  mkdir -p "$data/Documents"
  echo "$data/Documents"
}

# wait_ready <file> <id> [seconds]: until the app writes <id> into <file>.
wait_ready() {
  local file="$1" want="$2" seconds="${3:-30}"
  local tries=$((seconds * 4))
  for _ in $(seq 1 "$tries"); do
    if [ -f "$file" ] && [ "$(cat "$file")" = "$want" ]; then return 0; fi
    sleep 0.25
  done
  return 1
}

launch() {
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -museLab "$1" >/dev/null
}

# Writes the manifest (every registered screen) and prints its ids, one per line.
manifest_ids() {
  local docs="$1"
  rm -f "$docs/lab-ready"
  launch manifest || return 1
  wait_ready "$docs/lab-ready" manifest || { echo "manifest timeout" >&2; return 1; }
  cp "$docs/lab-manifest.json" "$MANIFEST"
  python3 -c '
import json, sys
for row in json.load(open(sys.argv[1])):
    print(row["id"])
' "$MANIFEST"
}

shots() {
  boot || return 1
  install_app || return 1
  local docs
  docs="$(docs_dir)" || { echo "no app container"; return 1; }

  local ids=("$@") all=0
  if [ ${#ids[@]} -eq 0 ]; then
    all=1
    local listed
    listed="$(manifest_ids "$docs")" || return 1
    ids=()
    while IFS= read -r line; do [ -n "$line" ] && ids+=("$line"); done <<<"$listed"
    [ ${#ids[@]} -gt 0 ] || { echo "no screens in the manifest"; return 1; }
  fi

  local failed=0
  for id in "${ids[@]}"; do
    rm -f "$docs/lab-ready"
    if ! launch "$id"; then
      echo "launch failed $id"; failed=1; continue
    fi
    if ! wait_ready "$docs/lab-ready" "$id"; then
      echo "timeout $id"; failed=1; continue
    fi
    sleep 0.4
    if xcrun simctl io "$UDID" screenshot --type=png "$OUT/$id.png" >/dev/null 2>&1; then
      echo "shot lab-shots/$id.png"
    else
      echo "screenshot failed $id"; failed=1
    fi
  done

  # A full run leaves only the current screens behind.
  if [ $all -eq 1 ]; then
    local png base keep
    for png in "$OUT"/*.png; do
      [ -e "$png" ] || continue
      base="$(basename "$png" .png)"
      keep=0
      for id in "${ids[@]}"; do [ "$id" = "$base" ] && { keep=1; break; }; done
      [ $keep -eq 1 ] || { rm -f "$png"; echo "removed stale lab-shots/$base.png"; }
    done
  fi
  return $failed
}

index() {
  boot || return 1
  install_app || return 1
  launch index || return 1
  open -a Simulator --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || true
  echo "the lab index is open on \"$NAME\" ($UDID)"
}

cmd="${1:-build-shot}"
shift || true
case "$cmd" in
  build) build ;;
  shots) shots "$@" ;;
  build-shot) build || exit 1; shots "$@" ;;
  index) index ;;
  udid) need_device && echo "$UDID" ;;
  *) echo "usage: scripts/lab.sh [build | shots [id ...] | build-shot [id ...] | index | udid]"; exit 2 ;;
esac
