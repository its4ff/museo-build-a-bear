import Foundation

/// How the library narrows, from the pills under the title: every muse, the ones streamed,
/// the ones that waited in the ring's memory, the long ones, and the typed ones (shown only
/// once there are any).
nonisolated enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    /// Held and spoken with the phone close (`MuseOrigin.stream`).
    case streamed
    /// Kept on the ring and brought in later (`MuseOrigin.offline`).
    case memory
    /// A long thought: its notes say so, or it runs past `MuseNotes.longThoughtFrom` words.
    case long
    /// Typed instead of said (`MusePipeline.addTyped`). Only offered when there are some.
    case typed

    var id: String { rawValue }

    /// The pill's word.
    var label: String {
        switch self {
        case .all: "all"
        case .streamed: "streamed"
        case .memory: "memory"
        case .long: "long"
        case .typed: "typed"
        }
    }

    func includes(_ muse: Muse) -> Bool {
        switch self {
        case .all: true
        case .streamed: muse.origin == .stream
        case .memory: muse.origin == .offline
        case .long: muse.notes?.kind == .longThought || muse.wordCount >= MuseNotes.longThoughtFrom
        case .typed: muse.origin == .typed
        }
    }

    /// The pills worth showing for these muses: all of them, but typed only once one exists.
    static func available(in muses: [Muse]) -> [LibraryFilter] {
        let hasTyped = muses.contains { LibraryFilter.typed.includes($0) }
        return allCases.filter { $0 != .typed || hasTyped }
    }
}
