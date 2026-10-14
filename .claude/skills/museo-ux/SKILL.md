---
name: museo-ux
description: 'Builds or changes museo build screens with the house design system: linen and moss tokens, Lora and Satoshi, house surfaces and components, modern SwiftUI on iOS 26. Use when writing or editing SwiftUI, a screen, sheet, card, tile, row, button, empty state, the home library, the muse page, onboarding, the build tools, the ring sheet, animation, haptics, or visual polish.'
---

# museo build UX

Ship like a senior Apple SwiftUI engineer with taste. Native structure, muse paper, type and voice. Never a generic chrome kit.

Read this skill fully, then follow the procedure.

## Procedure

1. **Read the house.** Open `museo build/Design/` (`MuseColor`, `MuseFont`, `MuseLayout`, `MuseSurfaces`, and `Components/`, one file per component) and the nearest existing screen in `museo build/Screens/`. Reuse its views and modifiers. Every token and component is rendered, with its Swift name, in `museo build/Lab/DesignKitView.swift` (lab id `designkit`).

2. **Live SwiftUI docs.** Don't trust training data for iOS 26 APIs. Fetch from Context7 (`/websites/developer_apple_swiftui`) before using a modifier you're not sure of: scroll anchors, safe area bars, glass, sheets, keyboard.

3. **Data comes from the environment.** Screens read `@Environment(MuseStore.self)`, `RingModel`, `MusePipeline` and `AppRouter`. They never touch the ring manager: ring commands arrive as `RingActions` closures (`import MuseoKit` for ring types). That keeps every screen previewable and lab-able.

4. **Place it.**
   - A part of an existing screen: a new file next to it, one view per file.
   - A page inside build: a `BuildRoute` case plus its `BuildDestination` (`Screens/Build/BuildView.swift`), pushed with `NavigationLink(value:)`.
   - A sheet over home: a case on `AppRouter.Sheet` (`App/AppRouter.swift`) and its branch in `RootSheet` (`App/RootView.swift`). Open it with `router.open(_:)`.

5. **Build it** from the skeleton below. Page wash behind, gutter `MuseSpacing.page`, title in `MuseHeader` ending with a period, sections under `MuseSectionHeader`.

6. **Words.** Every string follows the voice rules: lowercase, short, no dashes, no exclamation marks, middle dots as separators. Two short sentences of UI copy is enough.

7. **Motion and access.** Animate with `MuseMotion` through `.museAnimation(_:value:)`, which swaps long springs for `snappy` under Reduce Motion. One haptic per press (`MuseHaptics.play(.soft)` for chrome taps). Hit targets of at least 44pt. Icon-only controls get a lowercase `accessibilityLabel`. Decorative layers get `.accessibilityHidden(true)`.

8. **Check.**
   - `scripts/build.sh warnings Screens/`, once, right after the edit. It must print "build ok" and nothing else. Warnings show only for files compiled in that run, so don't run it twice to check.
   - Look at it. Add a `#Preview`, and a lab screen in `museo build/Lab/` (the `LabRegistry+…` file for that area) for anything people will see often. Then run `scripts/lab.sh build-shot <id>` and read `lab-shots/<id>.png`.
   - Run the `museo-review` skill.

## Skeleton

```swift
import SwiftUI

/// Today's muses as a quiet list. Tap one to open it.
struct TodayListView: View {
    @Environment(MuseStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let today = store.muses(on: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                MuseHeader(title: "today.", subtitle: "everything you said today, in one place.")
                VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                    MuseSectionHeader("muses", count: today.count)
                    ForEach(today) { muse in
                        Button {
                            router.open(.muse(muse.id))
                        } label: {
                            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                                Text(muse.createdAt.museClock)
                                    .font(MuseType.meta)
                                    .foregroundStyle(MuseColor.ink55)
                                Text(muse.displayTitle)
                                    .font(MuseType.headline)
                                    .foregroundStyle(MuseColor.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, MuseSpacing.md)
                            .padding(.vertical, MuseSpacing.row)
                            .museCardSurface()
                        }
                        .buttonStyle(MusePressStyle())
                    }
                }
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .museBottomBlur()
        .background { MuseBackground() }
    }
}

#Preview {
    TodayListView()
        .environment(MuseStore.preview(SampleMuses.make(now: .now)))
        .environment(AppRouter())
}
```

Previews and lab screens never use the live models. The preview versions: `MuseStore.preview([Muse])`, `RingModel.preview(.linked)`, `MusePipeline.preview(store, working:, noting:)`, `AppRouter()`, `RingActions.preview`. Sample muses: `SampleMuses.make()` (one with brief notes, `cardID`, and one long thought, `marketID`). Ring fixtures: `RingStatus.notSetUp`, `.joining`, `.linked`, `.linkedLow`, `.charging`, `.live`, `.syncing`, `.nearlyFull`, `.away`, `.bluetoothOff`.

## Pick the piece

| Need | Use |
|---|---|
| Page background | `.background { MuseBackground() }` (wash plus grain, once per screen) |
| Page title | `MuseHeader(title: "today.", subtitle: …)`, `titleSize: 28` in sheets |
| Home title | `HomeHeader(status:count:showsStatus:onRing:controls:)` in `Screens/Home/HomeHeader.swift` (not `MuseHeader`). Counts sit beside the title as ` · ` segments ("9 · 3 today"), built in `HomeView`. The one line under the title is the ring's `HomeStatusLine`; never add a second line |
| Section label | `MuseSectionHeader("on the ring")`, or `MuseSectionHeader("muses", count: n)` |
| Content card | `.museCardSurface()` / `.museTileSurface()` |
| Field or row inside a card | `.museInsetSurface()` |
| Where you type | `.museComposerSurface()` |
| Chip, capsule | `.musePill(.chip)`, `.musePill(selected:)`, `.museTopChrome()` for the chrome row |
| Buttons | `.buttonStyle(MuseButtonStyle(.primary))` once per screen; `.secondary`; `.tinted` for reversible; `.destructive` (clay text); `MuseQuietButton("skip for now") { }` for a quiet second choice under the primary |
| Pressable card | `.buttonStyle(MusePressStyle())` |
| Rows | `MuseListRow(title:meta:systemImage:action:)`, `MuseToggleRow(_:subtitle:isOn:)`, several in one `MuseListCard { }` |
| Icon button | `MuseChromeIcon("xmark", label: "close", action: …)` |
| Label, count, state | `MuseEyebrow("listening")`, `MuseSectionHeader("today", count: 3)`, `MuseConfidenceTag(0.91)`, `MuseLiveDot()` |
| Hint, code, toast | `MuseHintCard(_:systemImage:)`, `MuseCodeLine(_:caption:)`, `.museToast($message)` |
| Identity | `MuseOrb(mode:size:)`, `MuseRingGlyph(fill:style:)`, `MuseRingMark()` |
| Words typing in | `MuseInkText` |
| Times and copy | `date.museClock` ("9:41a"), `museRelative`, `museDayTitle`, `duration.museDuration`, `error.localizedDescription.museQuiet` |
| Bottom fade on a scroll | `.museBottomBlur()` on the `ScrollView` |

## Taste

- Linen paper and moss. Not white cards on a cool page, not system blue, not system green toggles.
- The card is lighter than the room, not a different room: one hairline, text does the work.
- Lora speaks (their words, titles, hints). Satoshi labels (buttons, times, counts). Never mix them in one sentence.
- Green is the orb, the primary button and accents. Never a content card. Clay is consequence, at most once per screen.
- Glass for controls, paper for content. No glass inside cards.
- Quiet. An empty state is an orb and two lowercase sentences, not an illustration and a stack of buttons.

## Do not

- Invent hex, `Color(red:)`, `.system(size:)`, a new spacing value or a new card, chip or field style.
- Read `RingBLEManager` in a view. Read `RingModel.status`.
- Wrap a `ScrollView` in `GeometryReader`, or `ignoresSafeArea(.bottom)` on a scroll that has `museBottomBlur`.
- Use `NavigationView`, `foregroundColor`, `showsIndicators:`, or an unqualified `.defaultScrollAnchor(.bottom)` on a growing list.
- Wrap a transcript's identity change in `withAnimation`. Every row fades.
- Add dark mode. museo build is light only.
- Copy ChatGPT, Claude or iMessage chrome onto linen.

## Done when

- [ ] It builds with no new warnings in `Screens/`.
- [ ] It has a `#Preview` fed with preview models, and a lab shot if people see it often.
- [ ] Only tokens and house components; one primary, at most one clay mark, grain only on the wash.
- [ ] Copy passes the voice rules.
- [ ] `museo-review` reports nothing to fix.
