#if DEBUG
import SwiftUI

/// `shelf-places`: the same shelf with places on it. Three that keep, then the two that
/// send, museo.fm last, and the one suggestion as a dashed line.
struct ShelfPlaces: View {
    var body: some View {
        ShelfWindow(current: .places, keys: ["↑↓←→ move", "↩ open", "⌘N new place", "⌘F search"]) {
            ScrollView {
                VStack(spacing: MuseSpacing.section) {
                    DuoPageTitle("places", count: PocketFixtures.placesCount)
                        .padding(.top, MuseSpacing.section)
                    VStack(spacing: MuseSpacing.sm) {
                        LazyVGrid(columns: ShelfGrid.columns(ShelfMetrics.placeColumns), spacing: MuseSpacing.sm) {
                            ForEach(PocketFixtures.places) { place in
                                ShelfPlaceTile(place: place)
                            }
                        }
                        ShelfSuggestion(suggestion: PocketFixtures.suggestion)
                    }
                }
                .padding(.horizontal, ShelfMetrics.gutter)
                .padding(.bottom, ShelfMetrics.footRoom)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// A place: its name in Lora, its sentence, and how many it holds. A small arrow marks
/// the ones that send.
struct ShelfPlaceTile: View {
    let place: PocketPlace

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(place.name)
                .font(MuseFont.lora(ShelfMetrics.placeName))
                .foregroundStyle(MuseColor.ink)
            Text(place.sentence)
                .font(MuseFont.satoshi(ShelfMetrics.placeSentence))
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: 0)
            HStack(spacing: MuseSpacing.xs) {
                Spacer(minLength: 0)
                if place.sends {
                    Image(systemName: "arrow.up.right")
                        .museSymbol(ShelfMetrics.glyph, weight: .medium)
                        .foregroundStyle(MuseColor.moss600)
                        .accessibilityLabel("sends")
                }
                Text("\(place.count)")
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .padding(.horizontal, MuseSpacing.lg)
        .padding(.vertical, MuseSpacing.card)
        .frame(maxWidth: .infinity, minHeight: ShelfMetrics.placeHeight, maxHeight: ShelfMetrics.placeHeight, alignment: .topLeading)
        .duoTileGlass()
        .accessibilityElement(children: .combine)
    }
}

/// "5 thoughts about the window. make it a place?" with its two answers, on a dashed
/// outline: an offer, not yet a thing.
struct ShelfSuggestion: View {
    let suggestion: PocketSuggestion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous)
        HStack(spacing: MuseSpacing.xl) {
            Text(suggestion.line)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
            Spacer(minLength: 0)
            Button("make it") {}
                .font(MuseType.label)
                .foregroundStyle(MuseColor.moss)
            Button("not now") {}
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink55)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MuseSpacing.card)
        .frame(height: DuoMetrics.bar + MuseSpacing.sm)
        .overlay {
            shape.strokeBorder(MuseColor.ink55.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: ShelfMetrics.dash))
        }
    }
}
#endif
