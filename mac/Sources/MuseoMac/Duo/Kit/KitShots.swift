#if DEBUG
import SwiftUI

/// The foundation's own shots: `kit-proof`, every shared piece on one window.
enum KitShots {
    static var all: [DuoShot] {
        [
            DuoShot("kit-proof") { DuoKitProof() },
        ]
    }
}

/// The proof: the dune, four glass tiles, three rows (one selected), the listen capsule
/// and "send to…", the large halftone ring, every ring pill state, the corner and search.
struct DuoKitProof: View {
    var body: some View {
        DuoWindow(current: .yours) {
            VStack(spacing: MuseSpacing.xl) {
                DuoPageTitle("your thoughts", count: PocketFixtures.yoursCount)
                    .padding(.top, MuseSpacing.sectionLabel)
                HStack(alignment: .top, spacing: MuseSpacing.section) {
                    left
                    states
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MuseSpacing.sectionLabel)
        }
    }

    private var left: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xl) {
            HStack(spacing: MuseSpacing.sm) {
                DuoTile(title: PocketFixtures.window.title)
                DuoTile(title: PocketFixtures.dentist.title, foot: PocketFixtures.dentist.foot, footDot: MuseColor.moss600)
                DuoTile(title: PocketFixtures.shop.title, foot: PocketFixtures.shop.foot, footDot: MuseColor.moss600)
                DuoTile(title: PocketFixtures.printShop.title, foot: PocketFixtures.printShop.foot, footDot: MuseColor.moss600, ink: .receding)
            }
            HStack(alignment: .top, spacing: MuseSpacing.section) {
                VStack(spacing: MuseSpacing.xxs) {
                    DuoThoughtRow(title: PocketFixtures.window.title, foot: PocketFixtures.window.time)
                    DuoThoughtRow(title: PocketFixtures.dentist.title, foot: PocketFixtures.dentist.foot, selected: true)
                    DuoThoughtRow(title: PocketFixtures.supper.title, foot: PocketFixtures.supper.foot, ink: .receding)
                }
                .frame(width: DuoProofMetrics.rows)
                VStack(alignment: .leading, spacing: MuseSpacing.xl) {
                    HStack(spacing: MuseSpacing.sm) {
                        DuoListenCapsule(length: PocketFixtures.dentist.length, seed: PocketFixtures.dentist.id)
                            .frame(width: DuoProofMetrics.listen)
                        DuoQuietButton("send to…")
                    }
                    PocketHalftoneRing(size: DuoProofMetrics.ring)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var states: some View {
        VStack(spacing: MuseSpacing.xs) {
            ForEach(PocketFixtures.ringStates, id: \.self) { state in
                DuoRingPill(state: state)
            }
        }
        .frame(width: DuoMetrics.cornerWidth)
    }
}

private nonisolated enum DuoProofMetrics {
    static let rows: CGFloat = 280
    static let listen: CGFloat = 300
    static let ring: CGFloat = 170
}
#endif
