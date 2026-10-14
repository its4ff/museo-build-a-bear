#!/bin/bash
# museo build: build against your own checkout of museo kit instead of the tagged one.
#
#   scripts/local-kit.sh        make "museo build local.xcworkspace": the app plus ../museo-kit
#   scripts/local-kit.sh off    remove it, back to the kit version the project pins
#
# For working on the kit itself. Open the workspace in Xcode and it uses ../museo-kit in place of
# the GitHub package; scripts/build.sh and scripts/lab.sh use it too whenever it exists. The
# workspace is gitignored, so the repo and everyone who clones it keep the pinned kit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WS="$ROOT/museo build local.xcworkspace"

if [ "${1:-}" = "off" ]; then
  rm -rf "$WS"
  echo "local kit off · builds use the pinned museo kit"
  exit 0
fi

if [ ! -f "$ROOT/../museo-kit/Package.swift" ]; then
  echo "no ../museo-kit here. clone it next to this folder first:"
  echo "  git clone https://github.com/its4ff/museo-kit.git \"$(dirname "$ROOT")/museo-kit\""
  exit 1
fi

mkdir -p "$WS"
cat > "$WS/contents.xcworkspacedata" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:museo build.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:../museo-kit">
   </FileRef>
</Workspace>
XML
echo "local kit on · open \"museo build local.xcworkspace\" · builds use ../museo-kit"
