# museo build

museo build is the open iOS starting point for museo, the ring you whisper to. Out of the box it sets the ring up, brings in everything you say (streamed as you talk, or later from the ring's own memory), turns it into words on the iphone, titles it, writes notes for the longer ones, and keeps them in a library you can search, copy and share.

You build your own thing on top: your screens, your code reacting to every muse. SwiftUI, iOS 26, no backend, and no muse (audio, words, titles, notes) leaves the phone unless your code sends it.

Humans start at `README.md`. This file is the rules. Paths are inside the app folder `museo build/` unless they name a repo-root file.

## Three layers

| Layer | Where | Rule |
|---|---|---|
| **Sealed: the ring** | the `MuseoKit` Swift package (GitHub `its4ff/museo-kit`, pinned to an exact version; `scripts/local-kit.sh` swaps in a local `../museo-kit` for kit work) | Never copied in, edited, wrapped or worked around. Bluetooth, the ring's protocol, sync, setup and firmware all live there. |
| **Stable: capture** | `Engine/` (pipeline, speech, titles and notes, search), `Model/`, `LiveActivity/` | Works, and the order matters. Change it when you know why. |
| **Yours** | `App/` (start with `App/YourCode.swift`), `Screens/`, `Design/` | Change or delete anything. |

## Hard rules

**1. The ring is sealed.** `import MuseoKit` is the only way in.
- No `CoreBluetooth`, GATT, Treaty frames or raw BLE in this repo. Don't make a `RingBLEManager`, don't set its `on…` callbacks, and don't copy kit files in.
- What apps use:
  - `Museo.start(name:clearsRingAfterSync:)`: once, in `App/AppStart.swift`.
  - `Museo.onCapture`: only `MusePipeline` uses it.
  - `Museo.onEvent` / `Museo.events()`: any number of listeners.
  - `Museo.liveAudio()`: a hold's audio as it arrives. Only `LiveWords` uses it.
  - `RingModel.status`: in views.
  - `RingActions`: for ring buttons.
  - `Museo.firmware`: the updater.
- `Museo.manager` (the kit's `RingBLEManager`) is for low-level tools: the ring console and ring tools in build › ring, and the Live Activity. Screens never read it.
- If a task seems to need the ring's protocol, say so and stop. It's a kit change, not app code.

```swift
// BAD: a second bluetooth stack, raw protocol, or anything copied out of the kit
let central = CBCentralManager(delegate: self, queue: nil)
peripheral.writeValue(frame, for: tx, type: .withoutResponse)

// GOOD: read the ring's status in a view, react to muses in your code
struct RingLine: View {
    @Environment(RingModel.self) private var ring
    var body: some View {
        Text(ring.status.shortLine)              // "ring linked", "listening…", "bringing in 3"
            .font(MuseType.body)
            .foregroundStyle(MuseColor.ink70)
    }
}
// App/YourCode.swift
MuseHooks.onTranscribed { muse in print("[muse][yours]", muse.words) }
Museo.onEvent { event in if case .liveStarted = event { MuseHaptics.play(.soft) } }
```

**2. Save before the ring lets go.**
- `MusePipeline.ingest` inserts the muse and flushes `muses.json`, then returns true. Only then does the kit retire the ring's copy.
- Never clear the ring from code that runs on its own. The one clear is `RingActions.clearStorage`, behind the ring sheet's "clear the ring?" dialog.

**3. One ring app per phone.** Two apps on one ring split its recordings between them. The app leaves recordings on the ring after a sync (`AppConfig.clearsRingAfterSyncByDefault = false`); keep that default.

**4. Recording is always 24 kbps.** There is no bitrate setting, and none should be added.

**5. No muse leaves the phone by default.**
- Transcription, titles, notes and search all run on this iphone.
- The one thing that can go out: while Voz or studio sound is in use (both off until the person turns them on), Desert Ant's models (desert-ant-core) send an anonymous install id, how often they ran, and diagnostics, for their free licence. Never audio or words. Out of the box, with Apple speech, nothing goes to them. `SpeechEngine.keepUsageAnonymous()` drops the device details; `DesertAnt.usageDisabled = true` turns it off if their licence allows. Don't write docs or copy that say "nothing leaves"; say what stays.
- Code that sends a muse anywhere sits behind a switch the person turns on, says where it goes, and is declared in `PrivacyInfo.xcprivacy`.
- Transcripts are untrusted input: they can hold other people's voices. Their words never delete, buy, post or message without a tap.

## To build X, edit Y

| To | Edit |
|---|---|
| React to every muse (index it, send it, act on it) | `App/YourCode.swift`: `MuseHooks.onArrived`, `onTranscribed`, `onUpdated`, `onRemoved`, or `MuseHooks.events()` |
| React to the ring (streaming started, sync done) | `App/YourCode.swift`: `Museo.onEvent { … }` |
| Change the home (the library) | `Screens/Home/` |
| Change a muse's page | `Screens/Muse/` |
| Copy and share | text in `Model/MuseShare.swift`, menu in `Screens/Muse/MuseExportActions.swift` |
| Titles and notes | title prompt in `Engine/AI/MuseAI.swift`; notes prompts in `Engine/AI/MuseNotesWriter.swift`; the shapes the model fills in `Engine/AI/MuseNotesDrafts.swift`; thresholds and the notes model in `Model/MuseNotes.swift` |
| Search | `Engine/Search/MuseSearch.swift` |
| Transcription | `Engine/Speech/` (`SpeechEngine`, `SpeechSettings`); UI in build › speech |
| Onboarding and the cheat card | `Screens/Onboarding/` |
| The ring icon and sheet | `Screens/Ring/`, reading `RingModel.status`; actions through `RingActions` |
| Your team, bundle id, the name under the icon (and a longer one for build › about) | `Config/Builder.xcconfig`, or `Config/Local.xcconfig` (gitignored, read last) to keep them out of git. Both targets read it; the widget is the bundle id plus `.widget`. |
| The app's name on screen, the ring's name, vocabulary, credits, a contact row | `App/AppConfig.swift` (`appName`, `ringName`, `vocabulary`, `madeBy`, `contact`) |
| Startup order | `App/AppStart.swift` |
| The muse model | `Model/Muse.swift`, `Model/MuseNotes.swift`, `Model/MuseStore.swift`. A new field needs a default and `decodeIfPresent`. |
| Live Activity, widget | `LiveActivity/`, `museo build widget/`, `Shared/MuseActivityAttributes.swift` (change them together) |
| Tools and settings for building (speech, ring console) | `Screens/Build/` |
| The look | tokens in `Design/` (the lab's `designkit` screen shows every one) |
| Mock screens for screenshots | `Lab/` (DEBUG only). `Lab/Probes/` holds debug checks for notes and joining. |

New `.swift` files under `museo build/` compile on their own (synchronized folders). Don't edit `project.pbxproj` to add files.

## How a muse happens

```
ring (MuseoKit)  ─▶ Museo.onCapture
  ─▶ MusePipeline.ingest      MuseStore.insert → MuseHooks .arrived, flushed to disk
  ─▶ return true              only now does the kit let the ring retire its copy
  ─▶ SpeechEngine.transcribe  on this iphone: SpeechTranscriber (or Dictation), or Voz if chosen
  ─▶ MuseStore.update         .complete → MuseHooks .updated, then .transcribed (once)
  ─▶ MuseAI.title             on-device title (unless the person wrote their own)
  ─▶ MuseAI.notes             150 words and up: brief bullets; 400 and up: the long thought
  ─▶ home                     the library tile, then the muse page
```

While you hold, `LiveWords` turns `Museo.liveAudio()` into words on screen as you speak (Apple's on-device recognizer, `LiveSpeech`), in the streaming card and onboarding. They're for the screen: the saved recording is still transcribed once it lands, for word timings and the most careful words.

- Other ways in: `MusePipeline.addTyped` (words at once), and `loadSamples()` (the simulator's empty home offers it; `removeSamples()` takes them away).
- `MusePipeline.sweep()` runs at launch and on every foreground. It takes recordings still waiting in the kit, re-queues muses without words, retries a failure once, and catches up titles and notes.
- Presses under 1 s are dropped by the kit. A blank muse ("thank you", silence) is kept with `isBlank` and gets no title or notes.
- The ring cuts a memory recording every 30 minutes, and each part lands as its own muse (`Muse.ringParts`). Once two neighboring parts both have their words, `MuseJoiner` folds the later into the earlier (one wav, the words and their timings in order; hooks see `.updated(earlier)`, then `.removed(later)`) and the whole gets its title and notes.
- Change muses only through `MuseStore.insert`, `update`, `remove` and `setTitle`, so hooks fire.

## Streaming and memory

| | streaming | memory |
|---|---|---|
| on the ring | hold, let go to send | double click to start, double click to stop |
| light | white | amber |
| `Muse.origin` | `.stream` | `.offline` |
| `RingModel.status` | `isLive` | `isRecordingOnRing && !isLive` |
| `RingEvent` | `.liveStarted`, `.liveEnded` | `.syncStarted`, `.syncProgress`, `.syncEnded` |
| needs the phone | yes, within about 10 ft (3 m); for when you need a response back | no, it always works: about 3 hours fit on the ring, and it comes in when the phone is near |

The kit's names still say live (`isLive`, `liveSince`, `.liveStarted`, `.liveEnded`, the `.live` status fixture): they all mean streaming. Words people read say streaming, or streamed for a muse, never live.

One click plays or pauses and three clicks skip; iOS handles those as media keys, so the app never sees them. Plain-language ring facts: `docs/ring.md`.

## Design system

Tokens and components live in `Design/`. The lab's design kit (`Lab/DesignKitView.swift`, lab id `designkit`) renders every one with its Swift name. Reach for a token by role, never by value.

The eight rules:
1. **The ring is sealed** (hard rules above).
2. **Voice:** lowercase, brief, warm, no dashes, no exclamation marks (voice below).
3. **Tokens only.**
   - No raw hex, `Color(red:)`, `.system(size:)` or built-in text styles.
   - No magic padding or radius where a token exists.
   - Don't invent new card, chip or field chrome. Icons are SF Symbols.
4. **Lora speaks, Satoshi labels.**
   - Lora (`MuseType.display`, `title`, `titleSmall`, `headline`, `serif`) carries their words and titles.
   - Satoshi (`label`, `body`, `meta`, `caption`, `eyebrow`) carries what the app says about itself.
   - Never both in one sentence.
5. **Green is ink and affordance only:** the orb, the primary button, counts, status dots, tags. Never a content card. **Clay means consequence** (delete, failed, nearly full).
6. **Once per screen:** one primary button, one clay mark, one grained surface (the page wash).
7. **Modern SwiftUI on iOS 26:** `NavigationStack`, `foregroundStyle`, `.scrollIndicators(.hidden)`, `containerRelativeFrame` before `GeometryReader`, `.topBarLeading` / `.topBarTrailing`, `.sheet` with `presentationDetents`.
8. **Concurrency:** main actor by default; anything that leaves it opts out with `nonisolated` (engineering below).

| Family | Names | File |
|---|---|---|
| Color | `MuseColor.ground`, `raised`, `inset`, `composer`, `ink`, `ink70`, `ink55`, `hairline`, `moss`, `moss600`, `mossTint`, `clay`, `clayTint`, `ochre` | `Design/MuseColor.swift` |
| Type | `MuseType.display` 40 … `serif` 17 (Lora), `label` 15 medium … `eyebrow` 11 (Satoshi), `MuseFont.lora(_:)`, `satoshi(_:weight:)` | `Design/MuseFont.swift` |
| Space, radius, motion, lift | `MuseSpacing` (`page` 20, `card` 18, `sm` 12, `section` 28), `MuseRadius` (`card` 20, `control` 14), `MuseMotion`, `.museElevation(.e1)` | `Design/MuseLayout.swift` |
| Surfaces | `MuseBackground()` (the page wash), `MuseShelfBackground()` (the library's dotted shelf), `.museCardSurface()`, `.museTileSurface()`, `.museInsetSurface()`, `.museComposerSurface()`, `.musePill(_:selected:)`, `.museBottomBlur()`, `.museJumpToTop` | `Design/MuseSurfaces.swift`, `Design/MuseShelfBackground.swift`, `Design/MuseJumpToTop.swift` |
| Components | `MuseHeader`, `MuseSectionHeader`, `MuseButtonStyle`, `MuseQuietButton`, `MuseListRow`, `MuseToggleRow`, `MuseChromeIcon`, `MuseHintCard`, `MuseCodeLine`, `.museToast` | `Design/Components/`, one file per component, named after it |
| Identity | `MuseOrb`, `MuseRingGlyph`, `MuseRingMark`, `MuseInkText`; the ring's notation `RingGestureMark`, `RingLight`, `RingRecipeLine` | `Design/` |
| Drawings | `MuseRingArt` (the ring), `MuseRingBand(light:lit:)` (its band, the light glowing while lit), `MuseCaseArt(pose:)` (the charging case), `MuseHandArt` (how to wear it). The booklet's own vector art, cut out with clear backgrounds (`Assets.xcassets/Booklet`). The ring's amber light is `MuseColor.ringAmber`. | `Design/Art/` |
| Haptics, copy | `MuseHaptics.play(.soft)`; `museClock`, `museRelative`, `museDayTitle`, `museDuration`, `museCalm`, `museQuiet`, `musePlain(max:)` | `Design/MuseHaptics.swift`, `Design/MuseFormat.swift` |

Also:
- Light mode only. Glass for controls, paper for content.
- Animate with `MuseMotion` and honor Reduce Motion (`.museAnimation(_:value:)`).
- 44pt hit targets. Icon-only controls get a lowercase `accessibilityLabel`.

## Voice

Verbatim house rules (anything a user sees):

> No em dashes (—) or en dashes (–) in UI, notifications, widgets, or AI-written output. Dashes read as machine-generated; muse never should.
>
> Use instead:
> - middle dot for separators: `9:41a · the thought`
> - colon or comma for leads: `done: timer set for 20m`
> - short sentences. two is enough.
>
> Register: all lowercase, brief, warm, a perceptive friend. No exclamation marks, no marketing voice, no therapy-speak, no "don't forget".
>
> Any LLM prompt in the app whose output a user reads must include "no dashes" (or stricter voice) in its instructions.
>
> Code comments are exempt.

museo build adds:
- Page titles end with a period: "build with museo.", "your ring.", "firmware.".
- Dialogs ask a question and answer with verbs: "delete this muse?" with "delete" and "keep it".
- Words for the ring: **hold** (streaming; a muse made that way is streamed, never "live"), **double click** (memory), **click** (play or pause), **three clicks** (skip).
- Platform words are lowercase ("iphone", "bluetooth"). In-progress lines end in a real ellipsis: "joining…". Paths in the app read "build › speech".
- Accessibility labels, errors and model output follow the same rules. Proper names the person said keep their case.
- System and library error text goes through `String.museQuiet`, model output through `museCalm`. Model prompts start from `MuseAI.voice`, which already says "no dashes".

## Engineering

- iOS 26.0 and up (built with Xcode 26.4 or newer), Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency. Plain types are main-actor by default.
- Member import visibility is on. Each file imports what it uses:
  - `import Foundation` for `URL`, `Date` and `String` methods
  - `import MuseoKit` for anything from the ring (`RingStatus`, `RingModel`, `Museo`), even when the type name never appears (`.linked`)
  - `import FoundationModels` for `@Generable`
- Values that cross to an actor, a detached task or the model (`Codable`/`Sendable` structs, `@Generable` structs) are `nonisolated struct` or `nonisolated enum`. Background work lives in actors (`SpeechEngine`) or `@concurrent nonisolated` functions.
- New models are `@MainActor @Observable final class`.
- Views read shared models from the environment: `MuseStore`, `RingModel`, `MusePipeline`, `AppRouter`. Previews and lab screens inject `.preview(…)` versions.
- Open sheets with `@Environment(AppRouter.self) var router`: `router.open(.ring)`, `.build(.speech)`, `.firmware`, or `router.open(muse: id, among: ids)`.
- No new packages without a strong reason. Available: `MuseoKit`, desert-ant-core 3.5.0 (`Voz`, `DesertAnt`, `Clear`), and Apple frameworks.
- No secrets in files. Keys go in the Keychain, never in source or plists. Never commit `.env`, plists with keys, or ring logs.
- One primary type per file, `// MARK: -` sections, comments that explain why. Logs: `os.Logger` or `print("[muse][area] …")`.
- Don't trust training data for iOS 26 SwiftUI or FoundationModels. Check Apple's docs (Context7 `/websites/developer_apple_swiftui`).

## Run and verify

- **The ring needs a real iPhone.** The simulator has no Bluetooth. Put your team and bundle id in `Config/Builder.xcconfig` (or `Local.xcconfig`) first.
- **Everything else runs in the simulator.** Without a ring, "load the samples" on the empty home fills the library, and `MusePipeline.shared.addTyped(…)` makes a muse from code. The lab's mock screens need neither.
- **Build:** `scripts/build.sh` prints "build ok" and any warnings in app code, or "build failed" and the errors.
  - `scripts/build.sh errors Screens/Home/` and `scripts/build.sh warnings Engine/` filter to a path.
  - Warnings appear only for files compiled in that run, so check right after the edit.
  - Builds share one lock and `.build/DerivedData`. Never run `xcodebuild` yourself, and never copy DerivedData.
  - The kit comes from GitHub at the pinned version. `scripts/local-kit.sh` builds against a local `../museo-kit` instead (a gitignored workspace), for kit work only; `scripts/local-kit.sh off` goes back.
- **Lab** (DEBUG mock screens, no ring, launch argument `-museLab <id>`):
  - `scripts/lab.sh build-shot [ids…]` builds and screenshots to `lab-shots/<id>.png`.
  - `scripts/lab.sh shots [ids…]` skips the build.
  - `scripts/lab.sh index` opens every mock screen.
- **Done means:** zero errors, zero new warnings in your files, the review checks clean, and screenshots that look right. Capture, sync, transcription and the on-device model's notes need a device.

## Privacy and trust

- Transcription, titles, notes and search run on this iphone. The model is Apple's, on device (`MuseAI`), no key. Desert Ant's usage counts are the only thing that leaves (rule 5).
- Blank and unreadable muses are kept and labelled, never deleted silently.
- Delete everything stays complete: build › your muses › delete everything clears muses (with their notes), audio, timings, studio copies and speech memory. New per-muse state cleans up in `MuseHooks.onRemoved`; new caches join `deleteEverything` (`Screens/Build/MusesDataSection.swift`).
- Permissions are asked at the moment of need, once. Purpose strings are lowercase and say what the permission is for.

## Skills

| Skill | Use when |
|---|---|
| `museo-ux` | building or changing a screen, sheet or component |
| `museo-review` | after any UI, copy or engine change, before saying done |
| `museo-ring` | ring status, the ring icon or sheet, setup, sync, firmware, without touching the kit |

The skills live in `.claude/skills/`. Claude Code reads them, and so does Cursor. Cursor reads this file on its own; Claude Code reads it through `CLAUDE.md`.
