import Foundation
import MuseoKit

/// Where your code starts. `install()` runs once at launch, before the first muse can
/// arrive, so you see every one.
///
/// Everything else in the app already works: the ring sets up, muses stream in or come
/// from the ring's memory, words land on this iphone, then a title and (for longer ones)
/// notes. React to any of it here, or build your own screens in `Screens/`.
///
/// What a muse carries: `muse.words`, `muse.title`, `muse.notes` (bullets, overview,
/// to-dos), `muse.createdAt`, `muse.duration`, `muse.origin` (`.stream` streamed, `.offline`
/// memory), `muse.language`, `muse.audioURL` (16 kHz mono wav). Every muse so far:
/// `MuseStore.shared.muses`, newest first.
///
/// Sending muses off the phone? Put it behind a switch the person turns on, say where it
/// goes, and declare it in `PrivacyInfo.xcprivacy`. No muse leaves by default.
@MainActor
enum YourCode {
    static func install() {
        // Their words, the moment they land (once per muse).
        MuseHooks.onTranscribed { muse in
            #if DEBUG
            print("[muse][yours] \(muse.origin.label): \(muse.words)")
            #endif
        }

        // Titles and notes arrive a moment later, as updates.
        // MuseHooks.onUpdated { muse in
        //     guard let notes = muse.notes else { return }
        //     print(muse.displayTitle, notes.bullets, notes.actions)
        // }

        // The ring itself: a stream starting, a sync finishing.
        // Museo.onEvent { event in
        //     switch event {
        //     case .liveStarted: MuseHaptics.play(.soft)
        //     case .syncEnded: print("everything on the ring is in")
        //     default: break
        //     }
        // }

        // Keeping your own copy (an index, a server)? Delete it there too. A long memory
        // recording's later parts go this way as they fold into its first part (an update).
        // MuseHooks.onRemoved { id in
        //     print("forget", id)
        // }

        // Send each muse to your own server, once the person has turned it on.
        // MuseHooks.onTranscribed { muse in
        //     guard UserDefaults.standard.bool(forKey: "yours.sendsMuses"),
        //           let url = URL(string: "https://example.com/muses") else { return }
        //     var request = URLRequest(url: url)
        //     request.httpMethod = "POST"
        //     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        //     request.httpBody = try? JSONEncoder().encode(["words": muse.words, "id": muse.id.uuidString])
        //     Task { _ = try? await URLSession.shared.data(for: request) }
        // }
    }
}
