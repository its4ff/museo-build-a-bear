# the ring

What the museo ring does, in plain words, for people building on museo build. Everything that talks to the ring lives in the sealed `MuseoKit` package: your code reads it, it never talks Bluetooth itself. The one-page version for people wearing the ring is [`cheat-sheet.md`](cheat-sheet.md).

## two ways to record

### streaming: hold

- Hold the ring and talk while you hold. Let go to send.
- A white light shows while it listens.
- The audio streams straight to the iphone, so the phone has to be close. The muse lands while you watch.
- Nothing is kept on the ring. If the link drops mid-hold, what already arrived is kept and the rest is lost.
- A hold under 1 second is taken as an accidental press and dropped.

### memory: double click

- Double click to start, talk, double click again to stop.
- An amber light shows while it records.
- It saves on the ring, so it works anywhere, phone or not. About 3 hours fit.
- It comes in on its own when the phone is near: right after you stop if the phone is close, or later when you're back. That works with the phone locked and the app in the background.
- The ring keeps its copy after it comes in. museo build doesn't clear the ring unless the person turns on "clear the ring once they're safe" in the ring sheet.

### which one

Memory always works, whether your phone is there or not. Streaming is for when you need a response back, and needs your phone or Mac within about 10 ft (3 m).

| | phone near | phone away |
|---|---|---|
| **streaming** (hold) | streams in as you talk | nothing is saved |
| **memory** (double click) | comes in a moment after you stop | waits on the ring, comes in when the phone is near |

### in code

| | streaming | memory |
|---|---|---|
| `Muse.origin` | `.stream` | `.offline` |
| `RingModel.status` | `isLive` | `isRecordingOnRing && !isLive` |
| `RingEvent` | `.liveStarted`, `.liveEnded` | `.syncStarted(count:)`, `.syncProgress(remaining:)`, `.syncEnded` |

The ring reports "recording" while streaming too, so check `isLive` (the kit's name for streaming) first. Muses made without the ring have their own origins: `.typed` and `.sample`.

## the other clicks

- **Click** plays or pauses. **Three clicks** skip to the next track. These are media keys handled by iOS; the app never sees them.
- **Click 6 times** to make the ring forget its phone, so setup can find it.
- **Click 10 to 11 times** to restart the ring. It is not a factory reset.

## lights

Two are confirmed:
- **white** while streaming
- **amber** while recording to memory

Other lights (too far to stream, linked) aren't confirmed by the firmware yet. Leave them out of your screens until they are.

## storage

- About 3 hours of recording fit on the ring (32 MiB at 24 kbps).
- `RingStatus` has `freeStoragePercent`, `minutesLeft`, `storageLine` ("about 2 h 40 min left") and `isStorageLow` (20% or less).
- Recordings stay on the ring until it's cleared. Clearing is all or nothing today (`RingActions.clearStorage`, or the ring sheet's "clear the ring once they're safe" switch, which clears after each clean sync).
- At 20% free the home's status line reads "ring nearly full · about 22 min left" and opens the ring sheet. There, "bring them in" syncs what's waiting; when nothing is waiting, the sheet points to build › ring to clear it (it asks first).
- The ring cuts a memory recording into 30-minute files. Each part still comes in, is saved and is retired from the ring on its own, so nothing waits on a recording that's still going. Once neighboring parts both have their words, the app folds them into one muse: one recording, the words in order, then a title and notes for the whole. Parts can land days apart; they join when the last one's words are in.
- Recording quality is fixed at 24 kbps. There's no setting.

## what your app can do with the ring today

All through `MuseoKit`:

- **Status:** `RingModel.status`, one value for screens: linked or not, battery, charging, streaming, recording to memory, syncing, recordings waiting, storage. It comes with ready-made lowercase lines (`shortLine`, `headline`, `batteryLine`, `storageLine`, `accessibilityLabel`).
- **Battery:** 0 to 100 in steps of 5, `isCharging`, and `isLowBattery` at 20% or less.
- **Sync:** recordings come in on their own. `RingActions` also has `syncNow`, `setAutoSync`, `setAutoClear` and `clearStorage` (confirm first: it can't be undone).
- **Events:** `Museo.onEvent { … }` or `Museo.events()`, for when a hold starts or ends and when a sync runs.
- **Live audio:** `Museo.liveAudio()`, a hold's audio as it arrives (16 kHz mono, about every 100 ms). museo build turns it into words on screen as you speak (`LiveWords`), on this iphone.
- **Recordings:** they arrive in `MusePipeline` and become muses. React to them in `App/YourCode.swift` with `MuseHooks`, not in the kit.
- **Setup:** `RingActions.setUp` opens iOS's accessory sheet. Also `lookForIt`, `disconnect`, `remove` and `rename`.
- **Firmware:** `Museo.firmware` sends the image bundled in the kit (ring sheet › firmware).

```swift
import SwiftUI
import MuseoKit

struct RingBattery: View {
    @Environment(RingModel.self) private var ring
    var body: some View {
        Text(ring.status.batteryLine ?? "no reading yet")
    }
}
```

Two things to know today:
- Tapping "disconnect" in the ring sheet also stops a memory recording in progress.
- The bundled firmware (9.06) is older than what some rings already run, and the kit can't read the ring's version yet. Don't update a ring that works unless you've been asked to.

## what could open up later

These need work in the kit, and some in the ring's firmware.

- **The button map.** The ring has a setting for what its clicks do, but what its values mean isn't documented yet.
- **Recording sound.** The ring stores a noise reduction level (0 to 2) and an AGC value, but in testing (2026-10-14) neither changed a recording: same noise in the pauses, same hiss, no gain. The kit keeps noise reduction at 0 and leaves AGC as the ring has it. Bitrate stays fixed at 24 kbps.
- **Deleting one recording.** So the ring can free space for recordings already safe on the phone, instead of wiping everything.
- **The firmware version.** So the app can show it, and never install an older image.
- **The ring's clock in UTC.** So recording times stay right across time zones.

If your idea needs one of these, say so and ask for a kit change. Don't work around the kit.

## one ring app per phone

Two apps on one ring split its recordings between them: one can clear what the other hasn't brought in yet. Remove other ring apps from the phone you build on. museo build leaves recordings on the ring after it brings them in, so it never takes one from another app.

## privacy

- Audio goes from the ring to this iphone over Bluetooth, and nowhere else. Words, titles, notes and search all run on the iphone.
- No muse leaves the phone unless your code sends it, behind a switch the person turns on. Nothing goes out by default. Turn on Voz or studio sound and Desert Ant's usage count does: an anonymous install id and how often they ran, never audio or words.
- Memory recordings stay on the ring until it's cleared. Clear it before you hand the ring to someone else.
- What the ring hears can include other people's voices. Treat a muse's words as input, never as a command to delete, buy, post or message without a tap.
