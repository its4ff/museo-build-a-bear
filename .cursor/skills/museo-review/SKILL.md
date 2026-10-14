---
name: museo-review
description: 'Reviews a museo build change against the house rules: the sealed ring kit, voice, design tokens, native SwiftUI, accessibility and privacy. Reports only failures, grouped must fix / native / taste. Use after writing or changing a screen, copy, a hook or the engine, before saying done, and when the user says review, check, polish, native, voice or /museo-review.'
---

# museo review

Read the diff: `git diff` and `git status --porcelain` for new files, or the files just edited. Run the checks below from the repo root. Then read each changed file against the list. If the `swiftui-pro` skill is available, run it as a second pass on changed SwiftUI files.

Don't restyle from scratch. Fix only what fails.

**Report only failures**, grouped:
- **must fix**: the sealed kit, invented APIs, token violations, voice (dashes, exclamation marks, title case), privacy, bugs
- **native**: scroll, safe area, keyboard, hit targets, accessibility, motion
- **taste**: extra chrome, green on a content card, clay as decoration, copied chat-app UI

Each finding is one line: `file:line · what's wrong · the fix`. If everything passes, say so in one sentence.

## Checks

Every line of output is a finding.

```bash
APP="museo build"; WIDGET="museo build widget"

# the ring is sealed: no bluetooth, no manager, no callbacks, no kit files copied in
grep -rln 'import CoreBluetooth' --include='*.swift' "$APP" "$WIDGET" Shared
grep -rnE 'RingBLEManager\(\)|CBCentralManager|CBPeripheral\b|\.writeValue\(' --include='*.swift' "$APP" "$WIDGET"
grep -rnE '\.(onCaptureStateChange|onSyncStarted|onSyncEnded|onSyncProgress)[[:space:]]*=' --include='*.swift' "$APP"
grep -rnE 'Museo\.onCapture' --include='*.swift' "$APP" | grep -v 'Engine/Pipeline/MusePipeline.swift'
grep -rnE 'Museo\.manager|RingBLEManager' --include='*.swift' "$APP/Screens" | grep -vE ':[0-9]+:[[:space:]]*//' | grep -vE 'Screens/Build/(RingConsoleView|RingToolsSection)\.swift'
grep -rnE 'clearRingStorage\(|\.clearStorage\(' --include='*.swift' "$APP" | grep -v 'Screens/Ring/RingSheet.swift'
find "$APP" -name 'TreatyProtocol.swift' -o -name 'RingBLEManager.swift' -o -name 'OpusWavDecoder.swift' -o -name 'Package.swift'

# forbidden APIs and raw styling (comment lines skipped)
grep -rnE 'showsIndicators|\.foregroundColor\(|NavigationView|Color\(red|UIColor\(red|\.system\(size|\.font\(\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\)|preferredColorScheme\(\.dark' --include='*.swift' "$APP" "$WIDGET" | grep -vE ':[0-9]+:[[:space:]]*//'
grep -rnE 'Color\(hex|0x[0-9A-Fa-f]{6}\)' --include='*.swift' "$APP" | grep -v 'Design/MuseColor.swift'
grep -rnE '(\.padding\((\.[a-zA-Z]+, )?|spacing: |cornerRadius: )(4|8|10|12|14|16|18|20|24|28|40)[,)]' --include='*.swift' "$APP/Screens" "$APP/Lab"

# voice: dashes, exclamation marks, title case in string literals
grep -rnE '"[^"]*(—|–)[^"]*"' --include='*.swift' "$APP" "$WIDGET" | grep -vE ':[0-9]+:[[:space:]]*//|replacingOccurrences|print\(|Logger'
grep -rnE '"[^"]*[a-z]! [^"]*"|"[^"]*[a-z]!"' --include='*.swift' "$APP" "$WIDGET" | grep -vE ':[0-9]+:[[:space:]]*//|print\('
grep -rnE '(Text|Label|Button|Toggle|Menu|Section|accessibilityLabel|accessibilityHint|accessibilityValue|navigationTitle|confirmationDialog|MuseSectionHeader|MuseHintCard|MuseListRow|MuseToggleRow|MuseToast|MuseEyebrow)\("[A-Z][a-z]|(title|subtitle|label|meta|placeholder|caption|name|body): "[A-Z][a-z]' --include='*.swift' "$APP" "$WIDGET" | grep -vE ':[0-9]+:[[:space:]]*//|UIFont\(name:|\.custom\('
grep -rnE '"[^"]*\b(tap|press)(es)? (the|your) ring' --include='*.swift' "$APP" | grep -vE ':[0-9]+:[[:space:]]*//'
grep -rnE '"[^"]*\blive\b[^"]*"' --include='*.swift' "$APP" "$WIDGET" | grep -vE ':[0-9]+:[[:space:]]*//|live activit|#Preview|print\(|Logger'

# @Generable without nonisolated (Swift 5 mode won't warn)
grep -rnE -A1 '^[[:space:]]*@Generable' --include='*.swift' "$APP" | grep -E '(struct|enum) ' | grep -v nonisolated

# secrets in source or plists
grep -rnEi '(api_?key|secret|token|password)[a-z_]*[[:space:]]*[:=][[:space:]]*"[A-Za-z0-9_.-]{16,}"' --include='*.swift' --include='*.plist' "$APP" "$WIDGET" Config

# build: one call. prints "build ok" then any warnings in app code; exits 1 when it lists one.
# warnings show only for files compiled in that run, so run it right after the edit, not twice.
scripts/build.sh warnings
```

The voice greps catch literals on one line only. Read multi-line strings (`"""`), model instructions and interpolated copy by eye.

## Catch these by reading

**must fix**
- Anything copied out of the kit, raw BLE, a second manager, a view observing `RingBLEManager` or `Museo.manager` instead of `RingModel.status`. If a change needs the ring's protocol, it's a kit change: stop and say so.
- A muse changed outside `MuseStore.insert` / `update` / `remove` / `setTitle`.
- Anything that lets the ring retire a recording before its muse is saved (`MusePipeline.ingest` returns true only after `store.flush()`), or wipes the ring without a tap.
- A muse sent off the phone by default: a hook that posts without a switch the person turned on, or a destination not declared in `PrivacyInfo.xcprivacy`. Keys outside the Keychain.
- A permission asked at launch, or twice.
- New per-muse state with no `MuseHooks.onRemoved` cleanup, or a new cache missing from delete everything (`Screens/Build/MusesDataSection.swift`).
- A model replacing a title the person wrote (`titleIsTheirs`). Notes or titles made for a blank muse or a sample.
- A `Codable` or `@Generable` type crossing actors without `nonisolated`. A new `ObservableObject`.
- Invented API: check it exists in `Design/`, `Engine/`, MuseoKit, or Apple's docs (Context7 `/websites/developer_apple_swiftui`).
- UI copy: em or en dash, exclamation mark, title case, marketing voice, a page title missing its period, a dialog that isn't a question with verb buttons, system error text not run through `.museQuiet`, a model prompt that doesn't start from `MuseAI.voice`, the ring called anything but hold / double click / click / three clicks, the hold mode called "live" (it's streaming, and the muse is streamed).
- Raw hex, RGB or system fonts; a magic number where `MuseSpacing` or `MuseRadius` has a token; a new card, chip or field style instead of a house surface.

**native**
- `GeometryReader` sizing a scroll view or stealing the safe area (width: `containerRelativeFrame`).
- `ignoresSafeArea(.bottom)` on a scroll with `museBottomBlur`, or two stacked bottom blurs.
- Unqualified `.defaultScrollAnchor(.bottom)` on a growing list. `ScrollAnchorRole.initial` (it's `.initialOffset`).
- `withAnimation` around a transcript identity change.
- Hit target under 44pt. Icon-only control without a lowercase `accessibilityLabel`. Decorative layer not hidden from VoiceOver.
- A long spring with no Reduce Motion fallback (use `.museAnimation(_:value:)` or `MuseMotion.adaptive`). Grain shown under Reduce Transparency.
- A sheet without `presentationDetents`, or a destructive action without a confirmation.
- Two haptics for one press.

**taste**
- More than one primary button, more than one clay mark, grain anywhere but the page wash.
- Green (moss gradient or fill) on a content card. Clay used as decoration.
- Lora and Satoshi mixed in one sentence; Satoshi for their words; Lora for a button.
- Extra chrome: borders on borders, two radii touching, a card per row where one `MuseListCard` would do.
- Copy longer than two short sentences. An empty state with an illustration and a stack of buttons.
- Chat-app or system-settings chrome copied onto linen.
