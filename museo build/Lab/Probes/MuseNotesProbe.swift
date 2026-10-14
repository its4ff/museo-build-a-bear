#if DEBUG
import Foundation
import FoundationModels

/// See the on-device model's real titles and notes without tapping through the app.
/// Launch with `-museNotesProbe`: it titles and notes the sample card (brief) and market
/// (long thought) muses, reads the market one in parts too, prints everything with
/// `[muse][notes probe]` and exits.
///
/// ```
/// scripts/lab.sh build
/// xcrun simctl launch --console-pty "museo build lab" <bundle id> -museNotesProbe
/// ```
///
/// The simulator uses the Mac's Apple Intelligence, so it needs to be on there.
@MainActor
enum MuseNotesProbe {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-museNotesProbe")
    }

    /// Runs once, then ends the app.
    static func run() {
        Task {
            await probe()
            say("done")
            exit(0)
        }
    }

    // MARK: - Private

    private static func probe() async {
        say("model available: \(MuseAI.isAvailable)\(MuseAI.unavailableNote.map { " · \($0)" } ?? "")")
        guard MuseAI.isAvailable else { return }
        say("context size: \(SystemLanguageModel.default.contextSize) tokens")

        let samples = SampleMuses.make()
        let picks: [(UUID, MuseNotes.Kind, Int?)] = [
            (SampleMuses.cardID, .brief, nil),
            (SampleMuses.marketID, .longThought, nil),
            (SampleMuses.marketID, .longThought, 160),
        ]
        var titled = Set<UUID>()
        for (id, kind, partWords) in picks {
            guard let muse = samples.first(where: { $0.id == id }) else { continue }
            say("")
            say("── \(muse.displayTitle) · \(muse.wordCount) words · \(kind.rawValue)\(partWords.map { " in parts of about \($0) words" } ?? "")")
            if titled.insert(id).inserted {
                let started = ContinuousClock.now
                let title = await MuseAI.title(for: muse.words)
                say("title: \(title ?? "(none)") · \(started.duration(to: .now).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))")
            }
            if kind == .longThought, partWords == nil {
                let fit = await MuseNotesWriter.fitsOneCall(muse.words)
                say("one call: \(fit.fits ? "fits" : "too long") · \(fit.used) of \(fit.room) tokens")
            }
            if let partWords {
                let parts = MuseWordParts.split(muse.words, around: partWords)
                say("parts: \(parts.map { "\(MuseWordParts.wordCount($0))" }.joined(separator: ", ")) words")
            }
            let started = ContinuousClock.now
            let notes = await MuseNotesWriter.write(kind, for: muse.words, partWords: partWords)
            say("notes · \(started.duration(to: .now).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))")
            guard let notes else {
                say("(no notes)")
                continue
            }
            if let overview = notes.overview { say("overview: \(overview)") }
            if let mood = notes.moodWord { say("mood: \(mood) (\(notes.mood ?? 0))") }
            for line in notes.plainText.components(separatedBy: "\n") { say(line) }
            let dashed = ([notes.overview ?? ""] + notes.plainText.components(separatedBy: "\n"))
                .filter { $0.contains("\u{2014}") || $0.contains("\u{2013}") || $0.contains("!") }
            say(dashed.isEmpty ? "voice: no dashes, no exclamation marks" : "voice: \(dashed.count) lines break the voice")
        }
    }

    private static func say(_ line: String) {
        print("[muse][notes probe] \(line)")
    }
}
#endif
