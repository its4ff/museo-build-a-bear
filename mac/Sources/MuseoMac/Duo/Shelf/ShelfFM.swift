#if DEBUG
import SwiftUI

/// `shelf-fm`: museo.fm as a collection. One thought given room on the dune, then other
/// people's as tiles with a city and an hour.
struct ShelfFM: View {
    var body: some View {
        ShelfWindow(current: .fm, keys: ["↑↓←→ move", "↩ open", "space listen", "⌘F search"]) {
            ScrollView {
                VStack(alignment: .leading, spacing: MuseSpacing.section) {
                    DuoPageTitle("museo.fm", count: ShelfFixtures.fmCount)
                        .padding(.top, MuseSpacing.section)
                    first
                    LazyVGrid(columns: ShelfGrid.columns(), spacing: MuseSpacing.sm) {
                        ForEach(ShelfFixtures.fmRest) { thought in
                            ShelfTile(
                                title: thought.words,
                                foot: thought.foot,
                                voice: thought.hasVoice,
                                titleSize: ShelfMetrics.fmTileWords,
                                lines: 5,
                                height: ShelfMetrics.fmTileHeight
                            )
                        }
                    }
                }
                .padding(.horizontal, ShelfMetrics.gutter)
                .padding(.bottom, ShelfMetrics.footRoom)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var first: some View {
        let thought = ShelfFixtures.fmFirst
        return VStack(alignment: .leading, spacing: MuseSpacing.md) {
            Text(thought.words)
                .font(MuseFont.lora(ShelfMetrics.fmWords))
                .lineSpacing(MuseType.serifLineSpacing)
                .foregroundStyle(MuseColor.ink)
                .frame(maxWidth: ShelfMetrics.fmWordsWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: MuseSpacing.md) {
                DuoGlassCircle("play.fill", label: "listen")
                DuoDottedWave(seed: thought.id, ink: MuseColor.ink55)
                    .frame(width: ShelfMetrics.fmWave, height: DuoMetrics.wave)
                Text(thought.foot)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .padding(.horizontal, MuseSpacing.xxs)
    }
}
#endif
