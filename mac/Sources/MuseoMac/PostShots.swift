#if DEBUG
import Foundation
import MuseoKit
import SwiftUI

/// A picture of "your words." to post: today's real numbers (counts only, read from this
/// mac), beside made-up thoughts, so nothing anyone said is in it.
/// `MuseoMac -renderDuo <folder> -postShot YES`.
enum PostShots {
    static var all: [DuoShot] {
        let library = MacLibrary.shared
        // The real library, only long enough to add it up.
        library.loadForPreview()
        let stats = LibraryStats(library.muses, span: .today)
        library.useSamples(LibraryShots.samples)
        StatsPane.preview = (stats, commandsToday(), .today)
        var ring = RingStatus.linked
        ring.battery = 82
        LibraryRingPill.previewRing = ring
        return [
            DuoShot("post-window") { LibraryWindow() },
            DuoShot("post-poster", size: CGSize(width: 1000, height: 860)) { poster },
        ]
    }

    /// The page alone on the dune, the ring's mark large and faint behind it.
    private static var poster: some View {
        StatsPane()
            .padding(.top, -MuseSpacing.sectionLabel)
            .background(alignment: .bottomTrailing) {
                PocketHalftoneRing(size: 560, ink: MuseColor.moss.opacity(0.16), dots: 61)
                    .offset(x: 150, y: 170)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: MuseSpacing.xs) {
                    PocketHalftoneRing(size: DuoMetrics.pillMark, ink: MuseColor.moss, dots: DuoMetrics.pillMarkDots)
                    Text("museo for mac")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink70)
                }
                .padding(.leading, 190)
                .padding(.bottom, MuseSpacing.sectionLabel)
            }
            .clipped()
            .background { PocketGround() }
            .preferredColorScheme(.light)
    }

    /// Today's command counts, from the app's own settings (this tool runs outside the app).
    private static func commandsToday() -> [LibraryStats.Count] {
        nonisolated struct Day: Codable { var day: Date; var counts: [String: Int] }
        guard let data = UserDefaults(suiteName: appID)?.data(forKey: "commandTally"),
              let days = try? JSONDecoder().decode([Day].self, from: data) else { return [] }
        var total: [String: Int] = [:]
        for day in days where LibraryStats.Span.today.contains(day.day, now: .now) {
            total.merge(day.counts, uniquingKeysWith: +)
        }
        return total.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { LibraryStats.Count(name: $0.key, count: $0.value) }
    }

    private static let appID = "build.museo.mac"
}
#endif
