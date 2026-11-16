<p align="center">
  <img src="docs/images/ring.png" width="300" alt="the museo ring">
</p>

<h1 align="center">museo build-a-bear</h1>

<p align="center"><i>a new interface for your thoughts.</i></p>

<p align="center">an open starting point to build anything on museo, on your iphone and your mac.</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-preview-8250df" alt="status: preview">
  <img src="https://img.shields.io/badge/iOS-26-3E5A3F" alt="iOS 26">
  <img src="https://img.shields.io/badge/macOS-26-3E5A3F" alt="macOS 26">
  <img src="https://img.shields.io/badge/Xcode-26.4-3E5A3F" alt="Xcode 26.4">
</p>

<p align="center"><b><a href="#museo-for-mac">museo for mac</a> · <a href="#museo-for-iphone">museo for iphone</a> · <a href="#the-build-a-bear-path">start in 5 minutes</a> · <a href="#tips">tips</a> · <a href="#two-asks-until-launch">two asks</a></b></p>

> [!IMPORTANT]
> **preview.** museo build is out ahead of its launch. two small asks [below](#two-asks-until-launch).

## museo for mac

hold the ring and talk. your words type into whatever app is in front, and every hold lands in a library on your mac. a menu bar app, in [`mac/`](mac/).

<table>
  <tr>
    <td width="34%" valign="top">
      <img src="docs/images/mac/panel.jpg" alt="the menu bar panel: the ring, speech, voice commands and recent muses"><br>
      <b>the menu bar</b><br>your ring, speech, voice commands, and what you said last.<br>
      <a href="mac/Sources/MuseoMac/MenuPanel.swift">MenuPanel →</a>
    </td>
    <td width="66%" valign="top">
      <img src="docs/images/mac/island.jpg" alt="the island under the notch: words forming, a prompt for claude, typed into claude"><br>
      <b>the island</b><br>words form under the notch while you hold, then land where you are.<br>
      <a href="mac/Sources/MuseoMac/NotchIsland.swift">NotchIsland →</a>
      <br><br>
      <img src="docs/images/mac/note.jpg" alt="a museo note: big lora on paper, words forming at the line"><br>
      <b>museo notes</b><br>⌘N for a bare page. hold to talk, or type. it names itself when you're done.<br>
      <a href="mac/Sources/MuseoMac/NoteWindow.swift">NoteWindow →</a>
    </td>
  </tr>
  <tr>
    <td colspan="2" valign="top">
      <img src="docs/images/mac/library.jpg" alt="the library: every muse by day, one open beside it"><br>
      <b>the library</b><br>everything you've said, by day, with where it went. search it, play it, copy it.<br>
      <a href="mac/Sources/MuseoMac/LibraryWindow.swift">LibraryWindow →</a>
    </td>
  </tr>
  <tr>
    <td colspan="2" valign="top">
      <img src="docs/images/mac/stats.jpg" alt="your words: how much you said this week, and the commands you use"><br>
      <b>your words</b><br>how much you said, how long it saved you, the commands you reach for.<br>
      <a href="mac/Sources/MuseoMac/StatsPane.swift">StatsPane →</a>
    </td>
  </tr>
</table>

**run it** on macOS 26 with Xcode 26.4 or newer:

```bash
git clone https://github.com/its4ff/museo-build-a-bear.git
```

```bash
cd museo-build-a-bear && scripts/mac.sh
```

museo shows up in the menu bar. set up your ring from the panel, then let it use bluetooth, speech, and accessibility (that last one is how it types into other apps). `scripts/mac.sh log` follows what it's doing.

- **voice commands:** end a hold with "send" to press return. "new line", "switch tab", "undo", "open claude" and more, each one yours to edit or add to.
- **talk to your agents:** "hey claude…" or "hey cursor…" opens a new chat with what you said.
- **speech on this mac:** apple dictation out of the box, or parakeet ultra on the neural engine, downloaded once from the panel. audio and words stay on your mac, except where you type them.
- **your iphone and your mac, one ring:** the mac brings in only what you record after it first sees the ring, newest first, so the iphone keeps its own. the panel brings in the older ones when you ask.

## museo for iphone

the ring sets up, what you say lands on your iphone as words, gets a title and notes, and stays in a library. all of it runs on the phone. you build what comes next.

<table>
  <tr>
    <td width="33%" valign="top">
      <img src="docs/images/streaming.jpg" alt="hold to stream: words appear as you speak"><br>
      <b>streaming</b><br>hold the ring and talk. words appear as you speak.<br>
      <a href="museo%20build/Screens/Home/">Screens/Home →</a>
    </td>
    <td width="33%" valign="top">
      <img src="docs/images/memory.jpg" alt="double click to record on the ring"><br>
      <b>memory</b><br>double click to record on the ring. it comes in later.<br>
      <a href="museo%20build/Engine/Pipeline/">Engine/Pipeline →</a>
    </td>
    <td width="33%" valign="top">
      <img src="docs/images/library.jpg" alt="the library of muses by day"><br>
      <b>the library</b><br>every muse, by day.<br>
      <a href="museo%20build/Screens/Home/">Screens/Home →</a>
    </td>
  </tr>
  <tr>
    <td width="33%" valign="top">
      <img src="docs/images/auto-notes.jpg" alt="a long muse with its notes"><br>
      <b>auto-notes</b><br>titles and notes, written on the iphone.<br>
      <a href="museo%20build/Engine/AI/">Engine/AI →</a>
    </td>
    <td width="33%" valign="top">
      <img src="docs/images/speech.jpg" alt="audio and transcription settings"><br>
      <b>audio + transcription</b><br>basic settings to use as they are, or customize.<br>
      <a href="museo%20build/Engine/Speech/">Engine/Speech →</a>
    </td>
    <td width="33%" valign="top">
      <img src="docs/images/setup.jpg" alt="iOS's setup sheet finding the museo ring"><br>
      <b>your ring</b><br>set up with iOS's own sheet. no pairing codes.<br>
      <a href="museo%20build/Screens/Ring/">Screens/Ring →</a>
    </td>
  </tr>
</table>

## the build-a-bear path

1. **clone it.**

   ```bash
   git clone https://github.com/its4ff/museo-build-a-bear.git
   ```

2. **open it in Xcode 26.4 or newer**, pick your iphone at the top and your team under Signing & Capabilities, then run. a free apple account works.
3. **keep your museo ring close by** so you can try it and learn the ropes.
4. **make it yours:** a name and your own bundle id go in `Config/Local.xcconfig`, a file you add. git ignores it.
5. **pick where muses live:** on the phone, or your own backend from [`App/YourCode.swift`](museo%20build/App/YourCode.swift).
6. **vibe code it** in Claude Code or Cursor. [`AGENTS.md`](AGENTS.md) keeps your agent off the ring and the firmware.
7. **build anything** you can imagine.

## tips

- **one ring, one app.** your ring links to one app at a time. remove it from the build-a-bear app (or any other) before your own app can set it up.
- **one backend, many apps.** send your muses to a backend like convex, so every app you try starts full.
- **keep a clean baseline.** one untouched clone. clone it again for each idea, and give each its own bundle id in `Config/Local.xcconfig` so they sit side by side on your phone.
- **one ring, iphone and mac.** museo for mac brings in only what you record after it first sees the ring, so both can sit beside each other. for another app of your own, read your muses from your backend.
- **a free apple account has limits.** apps you install with it run for 7 days, three at a time on one phone. testflight needs the paid apple developer program.

> [!TIP]
> this is how naveed landed on a daily museo: two rings, one paired with [museum](https://4ff.com/museum), one with a co-creator edition that turns walks into projects.

## two asks, until launch

1. please don't post about this repo yet.
2. please don't fork or copy it yet.

made something you love? show naveed at [x.com/naveedg](https://x.com/naveedg), then share it anywhere.

## more

<details>
<summary><b>what you need</b></summary>

| | |
|---|---|
| **to try it** | a Mac with Xcode 26.4 or newer. the simulator runs everything but the ring. |
| **for the ring** | a museo ring and an iphone on iOS 26 or newer. |
| **for museo for mac** | macOS 26 and Xcode 26.4 or newer, on any Mac with bluetooth. |
| **for titles and notes** | Apple Intelligence turned on (iphone 15 Pro or newer). without it, muses still get their words. |
| **an Apple account** | a free one works on your own iphone, but the app stops opening after 7 days until you run it from Xcode again. a paid developer account lasts a year and adds TestFlight. |

</details>

<details>
<summary><b>your first code</b></summary>

open [`museo build/App/YourCode.swift`](museo%20build/App/YourCode.swift). it already has this:

```swift
MuseHooks.onTranscribed { muse in
    print("[muse][yours] \(muse.origin.label): \(muse.words)")
}
```

run, hold your ring and say "hello there". the line shows in Xcode's console. no ring? `MusePipeline.shared.addTyped("hello there")` makes a muse from code, through the same hooks. the same file has examples for notes landing, ring events, deletes, and sending muses to your own server once the person turns it on.

a screen of your own reads the muses from the environment:

```swift
struct MyScreen: View {
    @Environment(MuseStore.self) private var store
    var body: some View {
        List(store.muses) { muse in Text(muse.displayTitle) }
    }
}
```

</details>

<details>
<summary><b>on your iphone, with your ring</b></summary>

1. **pick your team** in Xcode: the museo build target › Signing & Capabilities › Team. the bundle id follows it, so it's already yours.
2. **turn on Developer Mode:** Settings › Privacy & Security › Developer Mode, then restart. without it, Xcode can't install the app.
3. **move your ring over.** bring in everything waiting in the old app, then remove the ring there.
4. **run on the iphone** and tap **set up your ring**. can't find it? click the ring 6 times so it forgets its old phone.
5. **hold the ring**, say "hello there", let go.

</details>

<details>
<summary><b>ideas to ask your agent for</b></summary>

- "a today screen: just today's muses, as a timeline"
- "pull the to-dos out of every muse's notes into a list i can check off"
- "a widget with the title of my latest muse"
- "send each muse to my convex backend, behind a switch in build"
- "make the home one column, with bigger tiles"

the agent can check its own work: `scripts/build.sh` builds and prints "build ok" or the errors, and `scripts/lab.sh build-shot [ids]` screenshots mock screens into `lab-shots/`.

</details>

<details>
<summary><b>what doesn't work yet</b></summary>

- the simulator has no bluetooth, so the ring needs a real iphone.
- museo for mac doesn't write titles and notes for muses yet, only names for notes.
- titles and notes need Apple Intelligence.

</details>

<details>
<summary><b>how it's laid out</b></summary>

| layer | where | what it means |
|---|---|---|
| **sealed: the ring** | [museo kit](https://github.com/its4ff/museo-kit), the `MuseoKit` package Xcode fetches | bluetooth, sync, setup and firmware. you `import MuseoKit` and never edit it, so you (and your agent) can't break the ring. |
| **stable: capture** | `Engine/`, `Model/` | the pipeline, speech, titles and notes, search. it works; change it when you know why. |
| **yours** | `App/`, `Screens/`, `Design/` | the screens, the look, `YourCode.swift`. change or delete anything. |

| folder | what's there |
|---|---|
| `museo build/` | the iphone app. |
| `mac/` | museo for mac, a Swift package. `scripts/mac.sh` builds and opens it. |
| `Config/` | `Builder.xcconfig` (the app's name and bundle id, and how to change them) and `Info.plist`. |
| `docs/` | [the ring in plain words](docs/ring.md) and [the cheat sheet](docs/cheat-sheet.md). |
| `scripts/` | build and screenshot from the command line. |

</details>

<details>
<summary><b>staying up to date</b></summary>

`git pull`. updates mostly touch `Engine/`, `Model/` and the docs, and your work mostly lives in `App/` and `Screens/`, so they rarely collide. museo kit updates come with it: Xcode fetches the version this repo pins.

</details>

<details>
<summary><b>credits and licenses</b></summary>

museo build is in preview. no license yet, so all rights reserved. a license comes with the launch.

- **Lora** by Cyreal (`museo build/Design/Fonts/`), under the SIL Open Font License 1.1.
- **Satoshi** by the Indian Type Foundry (`museo build/Design/Fonts/`), from Fontshare under the ITF Free Font License. free to use in apps, and its terms ask you to credit ITF by name. read them at [fontshare.com/terms](https://www.fontshare.com/terms) before you publish anything that includes the font file. if in doubt, swap the face in `museo build/Design/MuseFont.swift`.
- **Voz and Clear** by Desert Ant Labs (desert-ant-core 3.5.0): the optional Voz speech engine and studio sound, under the Desert Ant Labs Source-Available License 1.0 ([license.desertant.com/1.0](https://license.desertant.com/1.0)). free below 100,000 monthly active devices per platform for each model, attribution required (build › about credits them, so keep that line), and no using the models or their output to train a competing model. neither ships in the app: each downloads the first time it's used (build › speech).
  - **what it sends:** while Voz or studio sound runs, and only then, desert-ant-core sends Desert Ant an anonymous install id, how often each model ran, and diagnostics. never audio or words. `SpeechEngine.keepUsageAnonymous()` already drops the device model, OS and locale; `DesertAnt.usageDisabled = true` turns it off, if their licence allows it for you. put it on your App Store privacy label.
- **firmware updates** (inside museo kit) use Nordic Semiconductor's nRF Connect Device Manager (Apache 2.0) with ZIPFoundation (MIT) and SwiftCBOR (Unlicense).
- speech recognition and the on-device model are Apple's (Speech, FoundationModels).

</details>

<br>

<p align="center">made by 4ff · tech built 4 friends &amp; family.</p>
