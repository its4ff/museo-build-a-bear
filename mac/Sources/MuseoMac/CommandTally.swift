import Foundation
import Observation

/// How often each voice command ran, by day, for the stats page. A command hold isn't kept
/// as a muse, so the library can't count them: this does, in this mac's settings, from the
/// day it shipped on. Only the command's name is kept, never what else was said.
@MainActor
@Observable
final class CommandTally {
    static let shared = CommandTally()
    private static let key = "commandTally"

    nonisolated struct Day: Codable, Sendable {
        var day: Date
        var counts: [String: Int]
    }

    private var days: [Day] = CommandTally.load() {
        didSet { if !isPreview { save() } }
    }
    @ObservationIgnored private var isPreview = false

    /// One more run of `name`: a command's first phrase ("switch tab"), "hey claude", "send".
    func add(_ name: String, at date: Date = .now) {
        let day = Calendar.current.startOfDay(for: date)
        if let index = days.firstIndex(where: { $0.day == day }) {
            days[index].counts[name, default: 0] += 1
        } else {
            days.append(Day(day: day, counts: [name: 1]))
        }
    }

    /// The commands run most in `span`, most first.
    func top(_ span: LibraryStats.Span, count: Int = 5, now: Date = .now) -> [LibraryStats.Count] {
        var total: [String: Int] = [:]
        for day in days where span.contains(day.day, now: now) {
            total.merge(day.counts, uniquingKeysWith: +)
        }
        return total
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(count)
            .map { LibraryStats.Count(name: $0.key, count: $0.value) }
    }

    #if DEBUG
    /// Counts for `ScreenSheet`, kept in memory only.
    func preview(_ counts: [String: Int]) {
        isPreview = true
        days = [Day(day: Calendar.current.startOfDay(for: .now), counts: counts)]
    }
    #endif

    // MARK: - Settings

    private static func load() -> [Day] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Day].self, from: data)) ?? []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
