#if DEBUG
import Foundation
import MuseoKit
import SwiftUI

/// Pictures of the real library window, drawn from made-up muses so nobody's own words are
/// in them: `MuseoMac -renderDuo <folder> -duoOnly live-library -libraryShot <which>`.
/// One state a run (`muse`, `ring`, `note`, `picked`, `palette`, `found`, `empty`), since
/// every window reads the one shared library.
enum LibraryShots {
    static var all: [DuoShot] {
        guard let which = UserDefaults.standard.string(forKey: "libraryShot") else { return [] }
        let library = MacLibrary.shared
        let samples = samples
        library.useSamples(which == "empty" ? [] : samples)
        var ring = RingStatus.linked
        ring.battery = 82
        LibraryRingPill.previewRing = ring
        switch which {
        case "ring": library.selection = samples[2].id
        case "note": library.selection = samples[3].id
        case "picked":
            library.selection = samples[0].id
            library.picked = Set(samples.prefix(3).map(\.id))
        case "palette", "found":
            library.selection = samples[1].id
            LibraryWindow.previewPalette = which == "palette" ? "" : "window"
        case "empty": break
        default: library.selection = samples[1].id
        }
        // The dune's strength, for comparing: `-libraryGround calm` or `quiet`.
        let ground = UserDefaults.standard.string(forKey: "libraryGround")
        switch ground {
        case "calm": LibraryWindow.ground = (0.6, 0.4, true)
        case "quiet": LibraryWindow.ground = (0.42, 0.22, true)
        default: break
        }
        return [DuoShot("live-library-\(which)\(ground.map { "-" + $0 } ?? "")") { LibraryWindow() }]
    }

    static var samples: [MacMuse] {
        let now = Date()
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        var note = MacMuse(id: UUID(), createdAt: ago(3), duration: 0, origin: "note", audioFile: "",
                           words: "The card in the box should be the first thing you touch. Heavy stock, one line, no logo.\n\nIt says what the ring is for, and nothing about how it works.")
        note.name = "the card in the box"
        var ring = MacMuse(id: UUID(), createdAt: ago(2), duration: 186, origin: "memory", audioFile: "sample.wav",
                           words: "The window is the shop. If the rings are floating there at night, nobody needs a sign. You walk past, you stop, you come back in the morning. That's the whole plan for the first month.",
                           model: "parakeet")
        ring.unseen = true
        var saved = MacMuse(id: UUID(), createdAt: ago(27), duration: 62, origin: "streamed", audioFile: "sample.wav",
                            words: "A supper club, but for strangers. Eight seats, one long table, and everyone brings one thing they said out loud that week.",
                            model: "parakeet")
        saved.saved = true
        return [
            MacMuse(id: UUID(), createdAt: ago(0.2), duration: 41, origin: "streamed", audioFile: "sample.wav",
                    words: "Rings floating in the window, lit from underneath, so at night it looks like they're holding themselves up.",
                    model: "parakeet", typedInto: "Notes"),
            MacMuse(id: UUID(), createdAt: ago(0.6), duration: 8, origin: "streamed", audioFile: "sample.wav",
                    words: "For Claude, book the dentist Thursday. Late afternoon if they have it, and put it on my calendar.",
                    model: "parakeet", typedInto: "Claude", wasSent: true),
            ring,
            note,
            MacMuse(id: UUID(), createdAt: ago(26), duration: 15, origin: "streamed", audioFile: "sample.wav",
                    words: "Call the print shop about the heavier card stock before Friday.",
                    model: "apple speech", typedInto: "Things"),
            saved,
            MacMuse(id: UUID(), createdAt: ago(74), duration: 190, origin: "memory", audioFile: "sample.wav",
                    words: "What dad said about the farm: you don't own it, you look after it for a while. I think about that with the shop.",
                    model: "parakeet"),
            MacMuse(id: UUID(), createdAt: ago(76), duration: 42, origin: "memory", audioFile: "sample.wav",
                    words: "A walk by the water. The tide was all the way out and a man was teaching his dog to wait.",
                    model: "parakeet"),
        ]
    }
}
#endif
