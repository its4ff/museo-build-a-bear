#if DEBUG
import SwiftUI

/// The kit's proof (`pocket.pill`): every pill state stacked on the dune with its name,
/// the halftone ring linked, in memory and streaming, and three tiles in the grid.
struct PocketPillProof: View {
    var body: some View {
        ScrollView {
            VStack(spacing: MuseSpacing.xl) {
                HStack(spacing: MuseSpacing.lg) {
                    PocketHalftoneRing(size: PocketPillProofMetrics.ring)
                    PocketHalftoneRing(size: PocketPillProofMetrics.ring, light: .amber)
                    PocketHalftoneRing(size: PocketPillProofMetrics.ring, light: .white)
                }
                .padding(.top, MuseSpacing.xs)
                VStack(spacing: MuseSpacing.xs) {
                    ForEach(PocketFixtures.ringStates, id: \.self) { state in
                        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                            Text(state.name)
                                .font(MuseType.caption)
                                .foregroundStyle(MuseColor.ink55)
                                .padding(.leading, MuseSpacing.md)
                            PocketRingPill(state: state)
                        }
                    }
                }
                LazyVGrid(columns: PocketGrid.columns(), spacing: PocketGrid.spacing) {
                    PocketTile(title: PocketFixtures.window.title)
                    PocketTile(
                        title: PocketFixtures.dentist.title,
                        foot: PocketFixtures.dentist.foot,
                        footDot: MuseColor.moss600
                    )
                    PocketTile(
                        title: PocketFixtures.printShop.title,
                        foot: PocketFixtures.printShop.foot,
                        footDot: MuseColor.ochre,
                        ink: .receding
                    )
                    PocketTile(title: PocketFixtures.walk.title, ink: .far)
                }
            }
            .padding(.horizontal, PocketGrid.gutter)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .background { PocketGround() }
    }
}

private nonisolated enum PocketPillProofMetrics {
    static let ring: CGFloat = 96
}
#endif
