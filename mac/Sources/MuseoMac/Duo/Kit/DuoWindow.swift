#if DEBUG
import SwiftUI

/// How the dune closes over a page at the window's foot.
nonisolated enum DuoFade: Hashable, Sendable {
    /// A band across the whole foot, as on the iphone.
    case foot
    /// Nothing: the page keeps its own foot clear (a glass sidebar, a panel).
    case none
}

/// One window of museo for mac in the duo language: the dune edge to edge, the page, a
/// soft fade so nothing reads behind the corner, `DuoCorner` pinned bottom left and an
/// optional glass search circle bottom right, each `DuoMetrics.margin` from the edges.
/// The content gets the whole window; leave `DuoMetrics.cornerRoom` at its foot.
///
/// ```swift
/// DuoWindow(current: .yours) {
///     ScrollView { … }.scrollIndicators(.hidden)
/// }
/// ```
struct DuoWindow<Content: View>: View {
    let current: PocketTabID
    var ring: PocketRingState
    var search: Bool
    var chrome: Bool
    var fade: DuoFade
    let content: Content

    init(
        current: PocketTabID,
        ring: PocketRingState = PocketFixtures.ring,
        search: Bool = true,
        chrome: Bool = true,
        fade: DuoFade = .foot,
        @ViewBuilder content: () -> Content
    ) {
        self.current = current
        self.ring = ring
        self.search = search
        self.chrome = chrome
        self.fade = fade
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if fade == .foot {
                    DuoFootFade()
                }
            }
            .overlay(alignment: .bottomLeading) {
                DuoCorner(current: current, ring: ring)
                    .padding(DuoMetrics.margin)
            }
            .overlay(alignment: .bottomTrailing) {
                if search {
                    DuoGlassCircle("magnifyingglass", label: "search")
                        .padding(DuoMetrics.margin)
                }
            }
            .overlay(alignment: .topLeading) {
                if chrome {
                    DuoWindowChrome()
                }
            }
            .background { PocketGround() }
            .preferredColorScheme(.light)
    }
}

/// The dune drawn once more over the page's foot and faded in, so a row never sits
/// legibly behind the corner. It is the same picture as the ground, so no seam shows.
struct DuoFootFade: View {
    var body: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1)
            PocketGround()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 1 - DuoMetrics.fadeEnd / height),
                            .init(color: .black, location: 1 - DuoMetrics.fadeSolid / height),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The three window buttons as quiet dots, top left, so a render reads as a mac window.
/// Decorative: the real window draws its own.
struct DuoWindowChrome: View {
    var body: some View {
        HStack(spacing: DuoMetrics.chromeGap) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(MuseColor.ink.opacity(DuoMetrics.chromeInk))
                    .frame(width: DuoMetrics.chromeDot, height: DuoMetrics.chromeDot)
            }
        }
        .padding(.leading, DuoMetrics.margin)
        .frame(height: DuoMetrics.chromeHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
