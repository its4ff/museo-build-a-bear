import Foundation

/// The library's order, from the sort button beside the title. Newest and oldest keep the
/// day rules; longest and shortest are one run, by how long you spoke.
///
/// Remembered between launches (`HomeView` keeps it in `AppStorage`).
nonisolated enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case longest
    case shortest

    var id: String { rawValue }

    var label: String { rawValue }

    /// SF Symbol for the menu.
    var symbol: String {
        switch self {
        case .newest: "clock"
        case .oldest: "clock.arrow.circlepath"
        case .longest: "arrow.down.to.line"
        case .shortest: "arrow.up.to.line"
        }
    }

    /// Newest and oldest read by day; the lengths don't.
    var usesDayRules: Bool { self == .newest || self == .oldest }

    /// These muses in this order. `muses` arrive newest first (`MuseStore.muses`); equal
    /// lengths keep the newest first.
    func ordered(_ muses: [Muse]) -> [Muse] {
        switch self {
        case .newest:
            muses
        case .oldest:
            muses.reversed()
        case .longest:
            muses.sorted { lhs, rhs in
                lhs.duration == rhs.duration ? lhs.createdAt > rhs.createdAt : lhs.duration > rhs.duration
            }
        case .shortest:
            muses.sorted { lhs, rhs in
                lhs.duration == rhs.duration ? lhs.createdAt > rhs.createdAt : lhs.duration < rhs.duration
            }
        }
    }
}
