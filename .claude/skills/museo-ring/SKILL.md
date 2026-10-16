---
name: museo-ring
description: 'Works with the museo ring from museo build app code without touching the sealed MuseoKit package: reading RingStatus, the ring icon and ring sheet, RingActions, setup through AccessorySetupKit, ring events, sync and ring storage, firmware updates, ring fixtures for previews. Use when a task mentions the ring, battery, link, pairing, setup, connect, disconnect, remove, sync, recordings on the ring, storage, firmware, OTA, bluetooth, streaming (live) or memory.'
---

# museo ring

The ring lives in the `MuseoKit` Swift package (GitHub `its4ff/museo-kit`, pinned to an exact version; `scripts/local-kit.sh` swaps in a local `../museo-kit` for kit work). It's sealed: you never copy it in, edit it from this repo, or work around it, and app code never speaks bluetooth. Everything an app needs comes through a few names, all from `import MuseoKit`:

```
MuseoKit (sealed) ──▶ RingModel.status (RingStatus) ──▶ RingButton, RingSheet, home, onboarding
        │      ▲                         ▲
        │      └── RingActions ──────────┘  (set up, look for it, sync, remove, firmware)
        ├──▶ Museo.onCapture ──▶ MusePipeline (saves the muse, then the ring may let go)
        └──▶ Museo.onEvent   ──▶ anything: .liveStarted, .liveEnded, .syncStarted, .syncProgress, .syncEnded
```

| Name | What it is |
|---|---|
| `Museo.start(name:clearsRingAfterSync:)` | Once, at launch (`App/AppStart.swift`). Makes the manager and starts everything below. |
| `RingStatus` | One `Equatable` value with everything screens show. Changes only when something on screen would. |
| `RingModel` | `@Observable`, `RingModel.shared`, `RingModel.preview(.syncing)`. Its `status` is what views read. |
| `RingActions` | Closures: `setUp`, `lookForIt`, `disconnect`, `remove`, `rename`, `syncNow`, `clearStorage`, `openFirmware`, `setAutoSync`, `setAutoClear`, `refresh`. `.live(openFirmware:)` or `.preview`. |
| `RingEvent` | `Museo.onEvent { }` or `for await event in Museo.events()`. Any number of listeners. |
| `LiveAudio` | `for await piece in Museo.liveAudio()`: a hold's audio as it arrives, 16 kHz mono. `LiveWords` turns it into words on screen; reuse that rather than opening a second stream. |
| `RingSetup` | AccessorySetupKit, inside the kit. Apps read `RingSetup.shared.events` (the setup log) and `RingSetup.isEnabled`. |
| `Museo.firmware` | The one `RingFirmwareUpdater`, with the firmware bundled in the kit (`BundledFirmware.version`). |

## Read the ring

```swift
import SwiftUI
import MuseoKit

struct RingSummary: View {
    @Environment(RingModel.self) private var ring

    var body: some View {
        let status = ring.status
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(status.shortLine)                       // "ring linked", "listening…", "bringing in 3"
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
            if let battery = status.batteryLine {        // "80% · charging"
                Text(battery)
                    .font(MuseType.meta)
                    .foregroundStyle(status.isLowBattery ? MuseColor.clay : MuseColor.ink55)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityLabel)
    }
}

#Preview {
    RingSummary().environment(RingModel.preview(.charging))
}
```

`RingStatus` fields: `link` (`.notSetUp`, `.bluetoothOff`, `.joining`, `.away`, `.linked`), `name`, `advertisedName` ("Museo_47cf"), `battery` (5% steps), `isCharging`, `batteryIsStale`, `batteryReadAt`, `isLive`, `liveSince`, `isRecordingOnRing`, `isSyncing`, `syncProgress`, `waiting`, `freeStoragePercent`, `autoSync`, `autoClear`, `syncError`, `usesAccessorySetup`, `isFirmwareUpdating`, `userDisconnected`, `isSettingUp`, `setupNote`, `canRename`.

Derived: `isLinked`, `needsAttention`, `isLowBattery`, `isStorageLow`, `minutesLeft`. Memory recording is `isRecordingOnRing && !isLive` (the ring also reports recording while streaming).

Ready-made copy in the house voice (use it, don't write your own): `headline`, `shortLine`, `deviceLine`, `batteryLine`, `storageLine`, `accessibilityLabel`.

Fixtures for previews and the lab: `.notSetUp`, `.joining`, `.linked`, `.linkedLow`, `.charging`, `.live` (streaming), `.syncing`, `.nearlyFull`, `.away`, `.bluetoothOff`, and `RingStatus.fixtures` (all of them, named).

## Make the ring do something

- **From any screen:** open the ring sheet. `@Environment(AppRouter.self) private var router`, then `router.open(.ring)`. Firmware is `router.open(.firmware)`.
- **In a view that needs a command:** take `RingActions` as a parameter, like `RingSheet(status:actions:events:)`. `App/RootView.swift` builds the live one with `RingActions.live(openFirmware:)`; previews and lab pass `.preview`.
- **In your code:** `Museo.onEvent { event in … }` to react. To act, use `RingActions.live(openFirmware:)`'s closures.
- **Not available yet** (kit work): the ring's firmware version, remapping click and three clicks, recording sound (the firmware's noise reduction and AGC changed nothing in testing; the kit keeps noise reduction at 0). Never add a bitrate control: it's always 24 kbps. Say so and stop rather than reaching for bluetooth.

## The ring screens

- **Ring icon:** `Screens/Ring/RingButton.swift`. `RingButton(status:style:action:)` with styles `.island`, `.glyph`, `.glyphPercent`, `.pill` (default in `AppConfig.ringButtonStyle`, `.island`). The island (`Screens/Ring/RingIslandFace.swift`) is one capsule that says what the ring is doing ("bringing in 3" filling as they come in, a clock on moss while you hold, "recording" with the amber light, "nearly full" in clay) and settles back to the battery. Beside it, the home's status line only says what to do next (`HomeStatusLine.line(for:besideIsland:)`). The other styles draw `MuseRingGlyph`: the band is the battery, dashed when not set up, inverted while streaming, clay when low, a count while syncing, "!" when only the person can fix it.
- **Ring sheet:** `Screens/Ring/RingSheet.swift`. `RingSheet(status:actions:events:)`: the device card, battery, the one next action (set up, look for it, or making room on a nearly full ring: `Screens/Ring/RingStatus+Room.swift`), on the ring (waiting, storage, the two switches, clear ring storage behind a dialog), firmware, disconnect and remove. The cheat card (how museo works) opens from the home's question mark, `router.open(.howItWorks)`.
- **Firmware:** `Screens/Ring/FirmwareSheet.swift` drives `Museo.firmware`. The ring must be linked, and the sheet can't be dismissed while an update runs. New firmware ships in a new MuseoKit version; never hand-roll DFU.
- **Ring console** (build › ring › ring console, live app only): every public value of the manager plus the setup log, for debugging on a device.

## How setup works (AccessorySetupKit)

- The app's `Config/Info.plist` declares `NSAccessorySetupKitSupports` [Bluetooth], `NSAccessorySetupBluetoothServices` [0004] and `NSAccessorySetupBluetoothNames` [Muse]. That puts the app in ASK mode: iOS's own accessory sheet sets the ring up, there's no bluetooth prompt, and the app only sees rings set up through that sheet.
- The sheet names the ring `AppConfig.ringName` ("museo"). The first app to set a ring up names it for every app.
- The sheet matches "Muse" in the name: `Museo_47cf` (firmware 10.14 and later) and `Muse_47cf` (earlier) both show.
- Remove the three `NSAccessorySetup…` keys and setup falls back to a plain scan that connects the closest ring with "Muse" in its name that answers in 20 s.

## Rules

- **One ring app per phone.** Two apps on one ring split its recordings. The ring sheet says so; keep that line.
- **Never let the ring retire a recording before the muse is saved.** Only `MusePipeline` uses `Museo.onCapture`, and it returns true after `store.flush()`. "clear the ring once they're safe" starts off (`AppConfig.clearsRingAfterSyncByDefault`). Only a confirmed tap may clear the ring.
- **Views never observe the manager.** It publishes many times a second while a muse streams. Read `RingModel.status`.
- **Recording is always 24 kbps.** No setting, and none to add.
- **Copy** comes from `RingStatus` or follows its voice. Ring words: hold (streaming; the muse is streamed, never "live"), double click (memory), click, three clicks.

## Test

- Real linking, streaming, memory, sync and firmware need an iPhone and a ring. The simulator has no Bluetooth.
- Everything else uses fixtures: `#Preview` with `RingModel.preview(.syncing)` or `RingSheet(status: .away, actions: .preview)`, and lab ids `ring.glyphs`, `ring.sheet.linked`, `ring.sheet.notsetup`, `ring.sheet.syncing`, `ring.sheet.away`, `ring.sheet.full`, `ring.sheet.full.clear`, `home.full`, `firmware` (`scripts/lab.sh build-shot ring.glyphs`).
- After changing a ring screen, run `museo-review`.
