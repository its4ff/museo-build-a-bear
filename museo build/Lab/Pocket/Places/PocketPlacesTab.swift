#if DEBUG
import SwiftUI

/// The middle tab: places. A place is a name, one plain sentence and an optional "send to",
/// so this one list stands in for folders, tags, webhooks and integrations. The places sit
/// in three quiet groups, parted by space alone: the ones that fill by themselves, the ones
/// that also send, and museo.fm. Under them, one suggestion at a time.
struct PocketPlacesTab: View {
    @State private var path: [PocketPlace] = []
    @State private var isAdding = false
    @State private var suggestion: PocketSuggestion? = PocketFixtures.suggestion

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: MuseSpacing.section) {
                    PocketPageTitle("places", count: PocketFixtures.placesCount, leading: {
                        PocketGlassCircle("gearshape", label: "settings")
                    }, trailing: {
                        PocketGlassCircle("plus", label: "new place") { isAdding = true }
                    })
                    VStack(spacing: MuseSpacing.md) {
                        ForEach(Self.groups, id: \.self) { group in
                            PocketPlaceGroup(places: group) { path.append($0) }
                        }
                        if let suggestion {
                            PocketSuggestionRow(suggestion: suggestion) {
                                isAdding = true
                            } notNow: {
                                self.suggestion = nil
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, PocketGrid.gutter)
                .padding(.top, PocketChrome.top)
                .museAnimation(MuseMotion.smooth, value: suggestion)
            }
            .pocketTabScroll()
            .background { PocketGround() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PocketPlace.self) { place in
                PocketPlacePage(place: place)
            }
        }
        .pocketChromeHidden(!path.isEmpty)
        .sheet(isPresented: $isAdding) {
            PocketNewPlace()
                .pocketFittedSheet()
        }
    }

    /// Fills by itself, then sends, then museo.fm. No headers: the space says it.
    private static let groups: [[PocketPlace]] = {
        let all = PocketFixtures.places
        let fm = all.filter { $0.destination == .fm }
        let sending = all.filter(\.sends)
        let kept = all.filter { !$0.sends && $0.destination != .fm }
        return [kept, sending, fm].filter { !$0.isEmpty }
    }()
}

// MARK: - A group of places

/// A few places on one sheet of glass, a hairline between them.
private struct PocketPlaceGroup: View {
    let places: [PocketPlace]
    let open: (PocketPlace) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(places) { place in
                Button {
                    MuseHaptics.play(.soft)
                    open(place)
                } label: {
                    PocketPlaceRow(place: place)
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.98))
                if place.id != places.last?.id {
                    Rectangle()
                        .fill(MuseColor.hairline)
                        .frame(height: 1)
                        .padding(.horizontal, MuseSpacing.card)
                        .accessibilityHidden(true)
                }
            }
        }
        .pocketTileGlass()
    }
}

/// One place: its name in Lora, its sentence under it, the count at the far edge, and a
/// small moss arrow only when it sends somewhere.
private struct PocketPlaceRow: View {
    let place: PocketPlace

    var body: some View {
        HStack(alignment: .center, spacing: MuseSpacing.sm) {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                Text(place.name)
                    .font(MuseType.headline)
                    .foregroundStyle(MuseColor.ink)
                Text(place.sentence)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
            .lineLimit(1)
            Spacer(minLength: MuseSpacing.xs)
            if place.sends {
                Image(systemName: "arrow.up.right")
                    .museSymbol(PocketPlacesMetrics.mark, weight: .semibold)
                    .foregroundStyle(MuseColor.moss600)
            }
            Text(place.count.formatted())
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink55)
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: PocketPlacesMetrics.rowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        let sends = place.sends ? ", sends to \(place.destination.label)" : ""
        return "\(place.name), \(place.sentence), \(place.count) thoughts\(sends)"
    }
}

// MARK: - The suggestion

/// "5 thoughts about the window. make it a place?" Quieter than a place: no glass, a
/// dashed edge, two word answers. Suggest, never create.
private struct PocketSuggestionRow: View {
    let suggestion: PocketSuggestion
    let make: () -> Void
    let notNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(suggestion.line)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
                .padding(.top, MuseSpacing.row)
            HStack(spacing: MuseSpacing.lg) {
                answer("make it", color: MuseColor.moss, action: make)
                answer("not now", color: MuseColor.ink55, action: notNow)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.bottom, MuseSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous)
                .strokeBorder(
                    MuseColor.ink.opacity(PocketPlacesMetrics.dashInk),
                    style: StrokeStyle(lineWidth: 1, dash: PocketPlacesMetrics.dash)
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func answer(_ words: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            Text(words)
                .font(MuseType.label)
                .foregroundStyle(color)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Sizes only this tab needs: no token fits them.
private nonisolated enum PocketPlacesMetrics {
    /// A row's least height: two lines and their air. Six of them, the title and the one
    /// suggestion end just above the ring pill in both shells.
    static let rowHeight: CGFloat = 60
    /// The "it sends" arrow: tiny, beside the count.
    static let mark: CGFloat = 11
    /// The suggestion's dashed edge.
    static let dash: [CGFloat] = [5, 5]
    static let dashInk: Double = 0.2
}

#Preview {
    PocketPlacesTab()
}
#endif
