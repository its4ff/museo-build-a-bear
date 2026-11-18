#if DEBUG
import SwiftUI

/// Shell b, the corner: no system tab bar. Bottom left, one compact glass cluster holds the
/// three places to be (three outline glyphs, the current one on a lighter lozenge with its
/// word); the moss ring pill sits directly above it on the same edge, the same width; bottom
/// right, one glass circle for search. They share one `GlassEffectContainer` inside
/// `.safeAreaBar(edge: .bottom)`, so the page scrolls under them with the system's edge
/// effect, and tapping the pill morphs it into the ring panel (`glassEffectID`).
///
/// Like shell a, each tab brings its own `NavigationStack` and dune; the shell adds neither.
struct PocketShellCorner: View {
    @State private var tab: PocketTabID
    @State private var ringOpen = false
    @State private var searching = false
    /// A tab is showing a pushed page, which brings its own bottom bar.
    @State private var chromeHidden = false

    @Namespace private var glass
    @Namespace private var lozenge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ring = PocketFixtures.ring

    init(start: PocketTabID) {
        _tab = State(initialValue: start)
    }

    var body: some View {
        page
            .overlay {
                // The dune closes over the page behind the dock. A pushed page has no
                // dock over it, so no fade.
                if !chromeHidden {
                    Color.clear
                        .pocketChromeFade()
                        .transition(.opacity)
                }
            }
            .overlay {
                if ringOpen {
                    // The page steps back while the ring is open. Tap it to close.
                    MuseColor.ink.opacity(PocketCornerMetrics.scrim)
                        .ignoresSafeArea()
                        .onTapGesture { setRing(open: false) }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .onPreferenceChange(PocketChromeHiddenKey.self) { hidden in
                chromeHidden = hidden
            }
            .safeAreaBar(edge: .bottom) {
                if !chromeHidden {
                    dock
                        .transition(.opacity)
                }
            }
            .museAnimation(MuseMotion.select, value: chromeHidden)
            .sheet(isPresented: $searching) {
                PocketSearchPage()
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .yours: PocketYoursTab()
        case .places: PocketPlacesTab()
        case .fm: PocketFMTab()
        }
    }

    // MARK: - The dock

    /// Everything at the bottom. Its layout height never changes, so the page's inset
    /// doesn't either: the open ring panel grows upward, over the page.
    private var dock: some View {
        GlassEffectContainer(spacing: MuseSpacing.xs) {
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                if ringOpen {
                    panel
                }
                HStack(alignment: .bottom, spacing: MuseSpacing.sm) {
                    VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                        if !ringOpen {
                            pill
                        }
                        cluster
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    search
                }
            }
            .padding(.horizontal, PocketGrid.gutter)
            .padding(.bottom, MuseSpacing.xs)
            .frame(height: PocketCornerMetrics.dockHeight, alignment: .bottom)
        }
    }

    // MARK: - The ring pill

    /// The kit's pill content over its fill, on glass so it can morph into the panel.
    private var pill: some View {
        Button {
            MuseHaptics.play(.soft)
            setRing(open: true)
        } label: {
            PocketRingPillContent(state: ring)
                .frame(maxWidth: .infinity)
                .frame(height: PocketCornerMetrics.bar)
                .background {
                    PocketRingPillFill(state: ring)
                        .clipShape(Capsule())
                        .overlay { PocketPillEdge(onDark: ringIsDark) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(PocketCornerGlass(shape: Capsule(), tint: ringIsDark ? MuseColor.moss : nil, id: "ring", namespace: glass))
        .accessibilityHint("opens your ring")
    }

    private var ringIsDark: Bool {
        if case .linked = ring { return true }
        return false
    }

    // MARK: - The ring panel

    /// The ring sheet, in place: the pill's glass grown into a panel.
    private var panel: some View {
        PocketRingSheet(state: ring)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topTrailing) {
                Button {
                    MuseHaptics.play(.soft)
                    setRing(open: false)
                } label: {
                    Image(systemName: "xmark")
                        .museSymbol(PocketCornerMetrics.closeSymbol, weight: .medium)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(MuseSpacing.xs)
                .accessibilityLabel("close")
            }
            .modifier(PocketCornerGlass(
                shape: RoundedRectangle(cornerRadius: MuseRadius.sheet, style: .continuous),
                tint: MuseColor.raised.opacity(PocketCornerMetrics.panelTint),
                interactive: false,
                id: "ring",
                namespace: glass
            ))
            .accessibilityAddTraits(.isModal)
    }

    private func setRing(open: Bool) {
        withAnimation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion)) {
            ringOpen = open
        }
    }

    // MARK: - The three places to be

    private var cluster: some View {
        ZStack(alignment: .leading) {
            // Every place's wider state, unseen, so the cluster (and the pill above it)
            // keeps one width whichever place is current.
            ForEach(PocketTabID.allCases, id: \.self) { place in
                HStack(spacing: 0) {
                    ForEach(PocketTabID.allCases, id: \.self) { other in
                        placeLabel(other, isCurrent: other == place)
                    }
                }
                .hidden()
                .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                ForEach(PocketTabID.allCases, id: \.self) { place in
                    placeButton(place)
                    if place != PocketTabID.allCases.last {
                        // Slack when the pill above, or a longer word, is the wider.
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(PocketCornerMetrics.clusterInset)
        .frame(maxWidth: .infinity)
        .modifier(PocketCornerGlass(shape: Capsule(), id: "places", namespace: glass))
        .museAnimation(MuseMotion.select, value: tab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("places to be")
    }

    private func placeButton(_ place: PocketTabID) -> some View {
        let isCurrent = place == tab
        return Button {
            guard !isCurrent else { return }
            MuseHaptics.play(.selection)
            tab = place
        } label: {
            placeLabel(place, isCurrent: isCurrent)
                .background {
                    if isCurrent {
                        Capsule()
                            .fill(MuseColor.composer.opacity(PocketCornerMetrics.lozenge))
                            .overlay { Capsule().strokeBorder(MuseColor.hairline) }
                            .matchedGeometryEffect(id: "lozenge", in: lozenge)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place.title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// A place's glyph, with its word when it is the current one.
    private func placeLabel(_ place: PocketTabID, isCurrent: Bool) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            Image(systemName: place.shellSymbol)
                .museSymbol(PocketGlassMetrics.symbol, weight: .regular)
            if isCurrent {
                Text(place.title)
                    .font(MuseType.label)
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .foregroundStyle(isCurrent ? MuseColor.moss : MuseColor.ink70)
        .padding(.horizontal, isCurrent ? MuseSpacing.row : 0)
        .frame(minWidth: MuseTopChrome.hitTarget)
        .frame(height: MuseTopChrome.hitTarget)
    }

    // MARK: - Search

    private var search: some View {
        Button {
            MuseHaptics.play(.soft)
            searching = true
        } label: {
            Image(systemName: "magnifyingglass")
                .museSymbol(PocketGlassMetrics.symbol, weight: .regular)
                .foregroundStyle(MuseColor.ink70)
                .frame(width: PocketCornerMetrics.bar, height: PocketCornerMetrics.bar)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(PocketCornerGlass(shape: Circle(), id: "search", namespace: glass))
        .accessibilityLabel("search")
    }
}

/// Interactive glass with an identity, so the dock's shapes can morph into one another.
/// The kit's `pocketControlGlass` has no id to give; this is the same glass with one. Paper
/// and a hairline under Reduce Transparency.
private struct PocketCornerGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive = true
    let id: String
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(MuseColor.raised, in: shape)
                .overlay { shape.strokeBorder(MuseColor.hairline) }
        } else {
            content
                .glassEffect(.regular.tint(tint ?? PocketColor.tileTint).interactive(interactive), in: shape)
                .glassEffectID(id, in: namespace)
        }
    }
}

private nonisolated enum PocketCornerMetrics {
    /// The cluster's, the pill's and the search circle's height.
    static let bar: CGFloat = 52
    /// Around the cluster's 44pt buttons: (52 - 44) / 2.
    static let clusterInset: CGFloat = 4
    /// The dock's fixed height: pill, gap, cluster, foot.
    static let dockHeight: CGFloat = bar * 2 + MuseSpacing.xs * 2
    /// The lozenge under the current place.
    static let lozenge: Double = 0.72
    /// How far the page steps back under the open ring.
    static let scrim: Double = 0.16
    /// How much paper the open panel's glass carries, so its words stay crisp.
    static let panelTint: Double = 0.78
    /// The panel's close mark.
    static let closeSymbol: CGFloat = 13
}

#Preview {
    PocketShellCorner(start: .yours)
}
#endif
