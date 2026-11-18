#if DEBUG
import SwiftUI

extension PocketTabID {
    /// The calm outline for each place, the same three the iphone's corner draws.
    var duoSymbol: String {
        switch self {
        case .yours: "square.grid.2x2"
        case .places: "tray"
        case .fm: "dot.radiowaves.left.and.right"
        }
    }
}

/// The signature the mac shares with the iphone: the moss ring pill above one compact glass
/// cluster of the three places to be. The current place shows its glyph and its word on a
/// lighter lozenge; the others are glyphs. One fixed width (`DuoMetrics.cornerWidth`), so it
/// sits the same in every window. `DuoWindow` pins it bottom left.
///
/// ```swift
/// DuoCorner(current: .yours, ring: .linked(battery: 82))
/// ```
struct DuoCorner: View {
    let current: PocketTabID
    var ring: PocketRingState
    var onPlace: (PocketTabID) -> Void
    var onRing: () -> Void

    @Namespace private var lozenge

    init(
        current: PocketTabID,
        ring: PocketRingState = PocketFixtures.ring,
        onPlace: @escaping (PocketTabID) -> Void = { _ in },
        onRing: @escaping () -> Void = {}
    ) {
        self.current = current
        self.ring = ring
        self.onPlace = onPlace
        self.onRing = onRing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DuoMetrics.cornerGap) {
            DuoRingPill(state: ring, action: onRing)
            cluster
        }
        .frame(width: DuoMetrics.cornerWidth)
    }

    private var cluster: some View {
        HStack(spacing: 0) {
            ForEach(PocketTabID.allCases, id: \.self) { place in
                placeButton(place)
                if place != PocketTabID.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DuoMetrics.clusterInset)
        .frame(maxWidth: .infinity)
        .frame(height: DuoMetrics.bar)
        .duoControlGlass()
        .museAnimation(MuseMotion.select, value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("places to be")
    }

    private func placeButton(_ place: PocketTabID) -> some View {
        let isCurrent = place == current
        return Button {
            guard !isCurrent else { return }
            onPlace(place)
        } label: {
            HStack(spacing: MuseSpacing.xs) {
                Image(systemName: place.duoSymbol)
                    .museSymbol(DuoMetrics.symbol, weight: .regular)
                if isCurrent {
                    Text(place.title)
                        .font(MuseType.label)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(isCurrent ? MuseColor.moss : MuseColor.ink70)
            .padding(.horizontal, isCurrent ? MuseSpacing.row : 0)
            .frame(minWidth: DuoMetrics.bar + MuseSpacing.xs)
            .frame(height: DuoMetrics.bar - DuoMetrics.clusterInset * 2)
            .background {
                if isCurrent {
                    // Sage on the cream glass: it reads by its fill, with no outline.
                    Capsule()
                        .fill(DuoColor.lozenge)
                        .matchedGeometryEffect(id: "lozenge", in: lozenge)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place.title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
#endif
