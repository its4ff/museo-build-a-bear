@AGENTS.md

## Claude Code

AGENTS.md above is the rulebook. This part is only what's specific to Claude Code.

**Skills** (`.claude/skills/`, identical copies in `.cursor/skills/`):
- `museo-ux`: build or change a screen with the design system.
- `museo-review`: the checklist and greps that catch voice, token and ring violations. Reports only failures.
- `museo-ring`: ring status, the ring icon and sheet, setup, sync, firmware, without touching the kit.

**Commands** (run from the repo root):
- `scripts/build.sh`: "build ok" plus any warnings in app code, or "build failed" and the errors. `scripts/build.sh errors <path>` and `scripts/build.sh warnings <path>` build, print the same first line, then filter to a folder like `Screens/Home/`. One call is the check: warnings show only for files compiled in that run, so a second run lists nothing.
- `scripts/lab.sh build-shot [ids…]`: build, then screenshot lab screens to `lab-shots/<id>.png`. `scripts/lab.sh shots [ids…]` skips the build. `scripts/lab.sh index` opens every mock screen in the simulator.
- `scripts/local-kit.sh`: build against a local `../museo-kit` (a gitignored workspace) instead of the pinned GitHub kit. `scripts/local-kit.sh off` goes back. Only for work on the kit itself, which happens in the kit's own repo.
- Look at a screenshot with the Read tool on `lab-shots/<id>.png`.

**Habits:**
- After any change to a screen or copy, run the `museo-review` skill before you say done.
- Builds are serialized by a lock and share `.build/DerivedData`. Never run `xcodebuild` directly, and never copy DerivedData (disk is tight). `MUSE_DERIVED_DATA=/path scripts/build.sh` builds into another folder (for a worktree or scratch copy), and `scripts/lab.sh` installs from the same folder. Leave it unset normally.
- The ring is the `MuseoKit` package (GitHub `its4ff/museo-kit`, pinned to an exact version; `scripts/local-kit.sh` swaps in a local `../museo-kit` for kit work). Never copy it in or edit it from this repo. If a task seems to need the ring's protocol, say so and stop.
