#if DEBUG
import SwiftUI

// What the tabs, the pushed pages, the sheets and the two shells agree on: how much room
// the floating chrome needs, the dune's fade under it, the signal that hides it, a sheet
// that hugs what it holds, and words that break evenly.

/// The floating chrome's measures. Both shells already claim their own height through the
/// safe area (the system bar and its accessory in shell a, the dock's `safeAreaBar` in
/// shell b), so a tab adds only the room below its last row.
nonisolated enum PocketChrome {
    /// Under a tab's last row, past the chrome: the last tile clears the fade.
    static let bottomRoom: CGFloat = MuseSpacing.section
    /// How far above the chrome the dune starts to close over the page.
    static let fadeLead: CGFloat = MuseSpacing.xs
    /// How long the fade takes to turn the page into dune.
    static let fadeRamp: CGFloat = 40
    /// The fade under the status bar: how long it is, and how far it reaches below the
    /// safe area's top edge (less than `top`, so a resting page's first row stays whole).
    static let topRamp: CGFloat = MuseSpacing.xl
    static let topReach: CGFloat = MuseSpacing.xxs
    /// Where every page's top row starts under the status bar: the settings circle on a
    /// tab, the back circle on a pushed page.
    static let top: CGFloat = MuseSpacing.xs
}

// MARK: - A tab's scroll

extension View {
    /// On a tab's `ScrollView`: the shared room under the last row, no indicators, and the
    /// dune closing softly over whatever scrolls under the ring pill and the navigation.
    func pocketTabScroll() -> some View {
        self
            .contentMargins(.bottom, PocketChrome.bottomRoom, for: .scrollContent)
            .scrollIndicators(.hidden)
            .pocketChromeFade()
    }

    /// The dune, drawn again over the foot of the page and faded in from just above the
    /// chrome, so nothing legible sits behind the pill or the dock (and the same, shorter,
    /// under the status bar). It is the same ground
    /// in the same place, so the page seems to sink into it.
    ///
    /// A tab's own fade sees the system tab bar (shell a). It does not see shell b's dock:
    /// a `safeAreaBar` outside a `NavigationStack` insets the scroll but not what a
    /// `GeometryReader` inside it reads. So shell b lays the same fade over its page.
    func pocketChromeFade() -> some View {
        overlay {
            GeometryReader { proxy in
                let chrome = proxy.safeAreaInsets.bottom
                let solid = max(chrome - (PocketChrome.fadeRamp - PocketChrome.fadeLead), 0)
                PocketGround()
                    .mask {
                        VStack(spacing: 0) {
                            // The top: the page has no navigation bar, so the dune also
                            // closes over what scrolls up under the clock.
                            Color.black
                                .frame(height: max(proxy.safeAreaInsets.top - PocketChrome.topRamp + PocketChrome.topReach, 0))
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: PocketChrome.topRamp)
                            Color.clear
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.55), location: 0.5),
                                    .init(color: .black, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: PocketChrome.fadeRamp)
                            Color.black
                                .frame(height: solid)
                        }
                        .ignoresSafeArea()
                    }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Hiding the chrome

/// True while a tab shows a pushed page. Shell b reads it and takes its dock and pill away
/// (those pages bring their own bottom bars); shell a's pushed pages hide the system bar
/// themselves with `pocketPushedPage()`.
nonisolated struct PocketChromeHiddenKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// On a tab's `NavigationStack`: `pocketChromeHidden(!path.isEmpty)`.
    func pocketChromeHidden(_ hidden: Bool) -> some View {
        preference(key: PocketChromeHiddenKey.self, value: hidden)
    }

    /// On every pushed page: no navigation bar (the page draws its own back circle) and no
    /// system tab bar.
    func pocketPushedPage() -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .toolbarVisibility(.hidden, for: .tabBar)
    }
}

// MARK: - A sheet that hugs what it holds

extension View {
    /// On a sheet's content: the sheet rests at the height of what it holds, with the
    /// grabber, on paper. At the largest text sizes the content scrolls instead of growing
    /// past the screen.
    func pocketFittedSheet() -> some View {
        modifier(PocketFittedSheet())
    }
}

private struct PocketFittedSheet: ViewModifier {
    @State private var height: CGFloat = PocketFittedSheet.first

    func body(content: Content) -> some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    height = newValue
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(MuseColor.raised)
    }

    /// Before the first measure: about a medium sheet.
    private static let first: CGFloat = 420
}

// MARK: - Words that break evenly

/// Sets one block of words in the narrowest width that keeps its line count, so the last
/// line never holds a word alone. The block keeps the full width it was offered and sits at
/// its leading edge.
nonisolated struct PocketBalanced: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let words = subviews.first else { return .zero }
        let width = proposal.width ?? words.sizeThatFits(.unspecified).width
        let height = words.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let words = subviews.first else { return }
        let height = words.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        var low = bounds.width * Self.narrowest
        var high = bounds.width
        for _ in 0..<Self.steps {
            let middle = (low + high) / 2
            let tall = words.sizeThatFits(ProposedViewSize(width: middle, height: nil)).height
            if tall <= height + 0.5 {
                high = middle
            } else {
                low = middle
            }
        }
        words.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: high.rounded(.up), height: height)
        )
    }

    /// Never narrower than this share of the width offered.
    private static let narrowest: CGFloat = 0.55
    /// Halvings: fine enough to land within a point or two.
    private static let steps = 8
}
#endif
