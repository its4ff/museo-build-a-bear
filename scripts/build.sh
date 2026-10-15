#!/bin/bash
# museo build: compile for the simulator and print only what matters.
#
#   scripts/build.sh                 build the app. prints "build ok" and any warnings in
#                                    app code, or "build failed" and the errors.
#   scripts/build.sh errors [path]   build, print "build ok" or "build failed", then the errors under
#                                    a path, e.g. Screens/Home/
#   scripts/build.sh warnings [path] build, print "build ok" or "build failed", then any errors and
#                                    the warnings in app code under a path (not packages). exits 1
#                                    when it lists a warning, so `&&` chains stop.
#
# One call is the whole check. Warnings show only for files compiled in that run, so check right
# after an edit: a second run compiles nothing and lists nothing.
#
# Builds run one at a time (a lock), so several agents can call this at once.
# DerivedData lives in .build/ at the repo root (gitignored). MUSE_DERIVED_DATA=/path builds into
# another folder (for a worktree or scratch copy), and scripts/lab.sh installs from the same folder.
# Leave it unset normally.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${MUSE_BUILD_LOCKED:-}" ]; then
  export MUSE_BUILD_LOCKED=1
  exec /usr/bin/lockf -t 3600 "$ROOT/.build.lock" "$0" "$@"
fi

DD="${MUSE_DERIVED_DATA:-$ROOT/.build/DerivedData}"
LOG="$ROOT/.build/build.log"
mkdir -p "$ROOT/.build"

# The pinned kit by default. With scripts/local-kit.sh's workspace, your ../museo-kit instead
# (its packages resolve freely, since a local kit can need versions the pin file doesn't hold).
LOCAL_WS="$ROOT/museo build local.xcworkspace"
if [ -d "$LOCAL_WS" ]; then
  SOURCE=(-workspace "$LOCAL_WS")
else
  SOURCE=(-project "$ROOT/museo build.xcodeproj" -onlyUsePackageVersionsFromResolvedFile)
fi

xcodebuild "${SOURCE[@]}" -scheme "museo build" \
  -configuration Debug -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DD" \
  -skipMacroValidation -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO -quiet build >"$LOG" 2>&1
status=$?

# Diagnostics in app code (packages are not ours to fix).
app_lines() {
  # The ring kit's errors still show (a local checkout of museo-kit fails here too); its
  # warnings don't, like any package's.
  if [[ "$1" == *warning* ]]; then
    grep -E "$1" "$LOG" | grep -v "/SourcePackages/" | grep -v "/museo-kit/" | sort -u
  else
    grep -E "$1" "$LOG" | grep -v "/SourcePackages/" | sort -u
  fi
}

# "build ok" or "build failed", first in every mode.
status_line() { if [ $status -eq 0 ]; then echo "build ok"; else echo "build failed"; fi; }

# App lines of one kind, only those under $2 when given. Returns 1 when it printed any.
filtered() {
  local lines
  lines=$(app_lines "$1")
  if [ -n "${2:-}" ] && [ -n "$lines" ]; then lines=$(printf '%s\n' "$lines" | grep -F -- "$2"); fi
  [ -z "$lines" ] && return 0
  printf '%s\n' "$lines" | head -60
  return 1
}

# After a failed build: the errors under $1, or a pointer when they are all somewhere else.
failed_errors() {
  if filtered ": error:" "${1:-}"; then
    if [ -n "${1:-}" ]; then echo "no errors under $1 · the failure is elsewhere, run scripts/build.sh to see it"; fi
    grep -E "error:" "$LOG" | grep -v ": error:" | sort -u | head -10
  fi
}

case "${1:-}" in
  errors)
    status_line
    [ $status -ne 0 ] && failed_errors "${2:-}"
    ;;
  warnings)
    status_line
    [ $status -ne 0 ] && failed_errors "${2:-}"
    filtered ": warning:" "${2:-}" || { [ $status -eq 0 ] && status=1; }
    ;;
  *)
    status_line
    if [ $status -eq 0 ]; then
      w=$(app_lines ": warning:")
      if [ -n "$w" ]; then
        n=$(printf '%s\n' "$w" | wc -l | tr -d ' ')
        if [ "$n" = 1 ]; then echo "1 warning in app code:"; else echo "$n warnings in app code:"; fi
        printf '%s\n' "$w" | head -40
      fi
    else
      app_lines ": error:" | head -60
      grep -E "error:" "$LOG" | grep -v ": error:" | sort -u | head -10
    fi
    ;;
esac
exit $status
