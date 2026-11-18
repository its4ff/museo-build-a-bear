#if DEBUG
import SwiftUI

/// The shelf itself: "your thoughts", its count, then every day as a row of glass tiles.
/// `selected` is the tile under the keys.
struct ShelfYoursPage: View {
    var selected: String? = PocketFixtures.dentist.id

    var body: some View {
        ScrollView {
            VStack(spacing: MuseSpacing.lg) {
                DuoPageTitle("your thoughts", count: ShelfFixtures.yoursCount)
                    .padding(.top, MuseSpacing.section)
                ForEach(ShelfFixtures.days, id: \.day) { group in
                    VStack(spacing: MuseSpacing.sm) {
                        ShelfDayRule(day: group.day, ink: group.thoughts.first?.ink ?? .full)
                        LazyVGrid(columns: ShelfGrid.columns(), spacing: MuseSpacing.sm) {
                            ForEach(group.thoughts) { thought in
                                ShelfTile(
                                    title: thought.title,
                                    foot: thought.foot,
                                    ink: thought.ink,
                                    selected: thought.id == selected
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, ShelfMetrics.gutter)
            .padding(.bottom, ShelfMetrics.footRoom)
        }
        .scrollIndicators(.hidden)
    }
}

/// `shelf-yours`: the library as the iphone's shelf, grown to a window.
struct ShelfYours: View {
    var body: some View {
        ShelfWindow(current: .yours, keys: ["↑↓←→ move", "↩ open", "⌘K send to…", "⌘F search"]) {
            ShelfYoursPage()
        }
    }
}
#endif
