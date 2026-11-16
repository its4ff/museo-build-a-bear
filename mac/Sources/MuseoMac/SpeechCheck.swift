#if DEBUG
import FluidAudio
import Foundation

/// `MuseoMac -speechCheck parakeet`: downloads the model if it isn't here, hears a few saved
/// holds with it, and prints its words beside the ones already in the library. Then reads a
/// long saved hold back at the ring's pace through `HoldParakeet`, and reads a few made up
/// holds as voice commands. Debug builds only; the ring isn't started.
enum SpeechCheck {
    static func run(_ kind: LocalSpeech.Kind) async {
        let library = MacLibrary.shared
        library.loadForPreview()
        let speech = LocalSpeech.shared
        if !speech.isReady(kind) {
            let started = Date.now
            guard await speech.fetch(kind) else { return }
            print("[check] downloaded in \(Int(Date.now.timeIntervalSince(started)))s")
        }
        MacSpeech.model = MacSpeech.Model(kind)

        let holds = library.muses.filter { !$0.isFromRing && !($0.words ?? "").isEmpty && $0.duration > 2 }.prefix(6)
        for muse in holds {
            let started = Date.now
            let words = await speech.words(of: library.audioURL(for: muse)) ?? "(nothing)"
            print("""
            [check] \(String(format: "%.1f", muse.duration))s heard in \(String(format: "%.2f", Date.now.timeIntervalSince(started)))s
              \(muse.model ?? "before"): \(muse.words ?? "")
              \(kind.name): \(words)
            """)
        }

        await holdCheck()

        let commands = VoiceCommands.shared
        for (apple, local) in [("Can you check this and send it.", "Can you check this and Sendet."), ("Send it.", "Sendet."), ("Switch tab.", "Switch Tap."), ("Looks good to me.", "Looks good to me."), ("Hey Claude, what's a good name for this?", "Hey Cloud, what's a good name for this?"), ("Hey Claude, summarize this and send it.", "Hey Claude, summarize this and Sendet."), ("Hey, Claude.", "Hey Claude."), ("Hey ChatGPT, plan my week.", "Hey chat GPT, plan my week."), ("Hey Cursor, fix the build and send.", "Hey Curser, fix the build and send.")] {
            print("[check] \"\(apple)\" / \"\(local)\" → \(commands.read(apple: apple, local: local))")
        }
        for said in ["Next tab.", "Switch tab.", "Scratch that.", "Open Notes.", "open the door", "Open figment.", "Open granola bar.", "Open curser.", "Open text edit.", "Open the window.", "Open settings.", "Can you check this, and send.", "Tell him I'll be late. Send it."] {
            print("[check] \"\(said)\" → \(commands.read(said))")
        }
    }

    /// A saved hold played back at the ring's pace into `HoldParakeet`: what the island would
    /// show, and when, beside the last pass's words.
    static func holdCheck() async {
        let library = MacLibrary.shared
        guard let muse = library.muses.filter({ $0.isStreamed && $0.hasAudio && $0.duration > 25 }).max(by: { $0.duration < $1.duration }),
              let audio = try? AudioConverter().resampleAudioFile(library.audioURL(for: muse)) else {
            print("[check] no long hold to play back")
            return
        }
        _ = await LocalSpeech.shared.words(of: [Int16](repeating: 0, count: 16_000))
        let samples = audio.map { Int16(max(-1, min(1, $0)) * 32_767) }
        let began = Date.now
        var shown = ""
        guard let live = HoldParakeet.begin(onWords: { words in
            shown = MacSpeech.joined(words.heard, words.hearing)
            print(String(format: "[check] %5.1fs  %@ ‹%@›", Date.now.timeIntervalSince(began), String(words.heard.suffix(60)), words.hearing))
        }) else {
            print("[check] parakeet isn't loaded")
            return
        }
        // The ring sends about every 100 ms.
        for at in stride(from: 0, to: samples.count, by: 1_600) {
            live.feed(Array(samples[at..<min(at + 1_600, samples.count)]))
            try? await Task.sleep(for: .milliseconds(100))
        }
        live.stop()
        let final = await LocalSpeech.shared.words(of: samples) ?? ""
        print("[check] \(String(format: "%.1f", muse.duration))s hold, last shown:\n  \(shown)\n  typed: \(final)")
    }
}
#endif
