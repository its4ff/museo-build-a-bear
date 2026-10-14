import SwiftUI

/// Decides which tiles type their title in on the home, so each one types exactly once.
///
/// A tile types in when its words land and you're there to see it: either the muse is fresh
/// (landed under 90 seconds ago) or you watched its "transcribing…" tile while you waited.
/// What types is whatever first fills the title slot: the start of their words, or the
/// model's title if it was already there. A title that lands later cross-fades in its place.
/// Fresh words that land while a full-height sheet covers the home (build, say) wait,
/// hidden, and type in as the home comes back to the front. Under the ring sheet at half
/// height the home still shows, so they type. Everything else shows plainly.
/// Once a tile has typed (or shown plainly) that sticks for the life of the home, so
/// scrolling back, a sheet closing, a filter or a title landing never types it twice.
///
/// Not `@Observable` on purpose: decisions are bookkeeping, recorded while the tile
/// renders, and must never trigger a redraw of their own.
@MainActor
final class ArrivalTracker {
    nonisolated enum Mode: Sendable, Equatable {
        /// Show the title plainly.
        case plain
        /// Type the title in now (`MuseInkText`).
        case types
        /// Fresh words, but the home is covered by a full-height sheet: keep their space,
        /// hide them, and type them in once the home is in front again.
        case waits
    }

    /// Words that land within this long of the muse arriving still type in.
    static let freshWindow: TimeInterval = 90

    private var decided: [UUID: Mode] = [:]
    private var watched: Set<UUID> = []

    /// How this muse's tile shows its title right now. Call it while building the tile.
    /// - Parameters:
    ///   - visible: the home is on screen and in front, with no full-height sheet over it.
    ///   - enabled: `AppConfig.typesNewWords`.
    func mode(for muse: Muse, visible: Bool, enabled: Bool, now: Date = .now) -> Mode {
        guard muse.isTranscribed, !muse.isBlank, !muse.words.isEmpty else {
            // Still waiting for words: remember that someone watched it wait.
            if visible { watched.insert(muse.id) }
            return .plain
        }
        if let mode = decided[muse.id] { return mode }
        let eligible = enabled
            && (watched.contains(muse.id) || muse.isFresh(within: Self.freshWindow, now: now))
        guard eligible else {
            decided[muse.id] = .plain
            watched.remove(muse.id)
            return .plain
        }
        // The home is covered: hold the words, undecided, until it's in front again.
        guard visible else { return .waits }
        decided[muse.id] = .types
        watched.remove(muse.id)
        return .types
    }

    /// The title finished typing, or the tile left the screen mid-typing. Either way it
    /// shows plainly from now on.
    func finished(_ id: UUID) {
        decided[id] = .plain
    }

    /// The muse is gone: forget it.
    func forget(_ ids: some Sequence<UUID>) {
        for id in ids {
            decided[id] = nil
            watched.remove(id)
        }
    }
}

extension AnyTransition {
    /// A muse tile arriving on the home: it settles in from 97% at its top edge and fades
    /// up; leaving, it only fades. Run it under `MuseMotion.drift`.
    static var museArrival: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
            removal: .opacity
        )
    }
}
