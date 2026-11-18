#if DEBUG
import SwiftUI

/// museo pocket: the library of your thoughts, places and museo.fm, in two shells, with
/// the ring pill above the navigation. All made-up data (`PocketFixtures`), no ring.
extension LabRegistry {
    // MARK: Pocket

    static var pocket: [LabScreen] {
        [
            LabScreen("pocket.a.yours", title: "pocket a · yours", note: "the native tab view: your thoughts, the ring pill as the bottom accessory", settle: .seconds(2)) {
                PocketShellNative(start: .yours)
            },
            LabScreen("pocket.a.places", title: "pocket a · places", note: "the native tab view on the middle tab", settle: .seconds(2)) {
                PocketShellNative(start: .places)
            },
            LabScreen("pocket.a.fm", title: "pocket a · museo.fm", note: "the native tab view on museo.fm", settle: .seconds(2)) {
                PocketShellNative(start: .fm)
            },
            LabScreen("pocket.b.yours", title: "pocket b · yours", note: "the corner: a glass cluster bottom left, the moss pill above it, search bottom right", settle: .seconds(2)) {
                PocketShellCorner(start: .yours)
            },
            LabScreen("pocket.b.places", title: "pocket b · places", note: "the corner on the middle tab", settle: .seconds(2)) {
                PocketShellCorner(start: .places)
            },
            LabScreen("pocket.b.fm", title: "pocket b · museo.fm", note: "the corner on museo.fm", settle: .seconds(2)) {
                PocketShellCorner(start: .fm)
            },
            LabScreen("pocket.thought", title: "pocket · a thought", note: "one thought: its words, what came back, where it is filed", settle: .seconds(2)) {
                PocketThoughtPage(thought: PocketFixtures.dentist)
            },
            LabScreen("pocket.send", title: "pocket · send to", note: "the small sheet of places, over the library", settle: .seconds(2)) {
                pocketSheetStage { PocketSendSheet(thought: PocketFixtures.window) }
            },
            LabScreen("pocket.place", title: "pocket · a place", note: "a place's page: its sentence, its thoughts, where it sends", settle: .seconds(2)) {
                PocketPlacePage(place: PocketFixtures.claude)
            },
            LabScreen("pocket.place.new", title: "pocket · new place", note: "one sentence, a proposed name, where it sends", settle: .seconds(2)) {
                pocketSheetStage { PocketNewPlace() }
            },
            LabScreen("pocket.fm.give", title: "pocket · give to museo.fm", note: "what becomes public, with my voice or words only", settle: .seconds(2)) {
                pocketSheetStage { PocketGiveSheet(thought: PocketFixtures.supper) }
            },
            LabScreen("pocket.ring", title: "pocket · ring sheet", note: "the large halftone ring, state, battery, room left, the four gestures", settle: .seconds(2)) {
                pocketSheetStage { PocketRingSheet(state: PocketFixtures.ring) }
            },
            LabScreen("pocket.pill", title: "pocket · the kit", note: "every pill state on the dune, the halftone ring, the shared tile", settle: .seconds(3)) {
                PocketPillProof()
            },
        ]
    }

    /// A pocket sheet at rest over the dimmed library, at the height of what it holds
    /// (the app presents these with `pocketFittedSheet()`).
    private static func pocketSheetStage<Sheet: View>(@ViewBuilder sheet: () -> Sheet) -> some View {
        PocketLabSheet { sheet() }
    }
}

/// The house `LabSheet`, for a sheet that hugs its content: the page dimmed behind, the
/// paper raised over it with its grabber, as tall as what it holds plus the home indicator.
private struct PocketLabSheet<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PocketYoursTab()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            MuseColor.ink.opacity(Self.dim)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .background {
                    MuseColor.raised
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: MuseRadius.sheet,
                            topTrailingRadius: MuseRadius.sheet,
                            style: .continuous
                        ))
                        .museElevation(.e2)
                        .ignoresSafeArea(edges: .bottom)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(MuseColor.ink.opacity(Self.grabberInk))
                        .frame(width: Self.grabber.width, height: Self.grabber.height)
                        .padding(.top, Self.grabberTop)
                        .accessibilityHidden(true)
                }
        }
    }

    private static var dim: Double { 0.22 }
    private static var grabberInk: Double { 0.18 }
    private static var grabber: CGSize { CGSize(width: 36, height: 5) }
    private static var grabberTop: CGFloat { 5 }
}
#endif
