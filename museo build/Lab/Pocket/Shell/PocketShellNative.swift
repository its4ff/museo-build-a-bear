#if DEBUG
import SwiftUI
import UIKit

/// Shell a, native: a real iOS 26 `TabView`. The three places to be sit in the system's
/// glass capsule, search is pulled out as its own circle at the trailing end, the ring pill
/// is the bottom accessory and tucks inline when the bar shrinks on scroll. No chrome of
/// our own: what we give the bar is outline symbols, Satoshi words and the moss.
///
/// Each tab brings its own `NavigationStack` and its own dune (`PocketGround`), so a tab can
/// push a page with the zoom transition and still stand alone behind a lab sheet. The shell
/// adds neither.
struct PocketShellNative: View {
    @State private var tab: PocketShellNativeTab
    @State private var showsRing = false

    init(start: PocketTabID) {
        _tab = State(initialValue: .page(start))
        // Satoshi on the bar's words, before the bar exists.
        PocketTabBarWords.apply()
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(value: PocketShellNativeTab.page(.yours)) {
                PocketYoursTab()
            } label: {
                PocketTabLabel(tab: .yours)
            }
            Tab(value: PocketShellNativeTab.page(.places)) {
                PocketPlacesTab()
            } label: {
                PocketTabLabel(tab: .places)
            }
            Tab(value: PocketShellNativeTab.page(.fm)) {
                PocketFMTab()
            } label: {
                PocketTabLabel(tab: .fm)
            }
            Tab(value: PocketShellNativeTab.search, role: .search) {
                PocketSearchPage()
            }
        }
        .tint(MuseColor.moss)
        .tabViewBottomAccessory {
            PocketRingAccessory(state: PocketFixtures.ring) { showsRing = true }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: tab) { MuseHaptics.play(.selection) }
        .sheet(isPresented: $showsRing) {
            PocketRingSheet(state: PocketFixtures.ring)
                .pocketFittedSheet()
        }
    }
}

/// The native shell's tabs: the three places to be, and search.
nonisolated enum PocketShellNativeTab: Hashable, Sendable {
    case page(PocketTabID)
    case search
}

// MARK: - What both shells share

extension PocketTabID {
    /// The calmest outline for each place: a grid for the library, one tray for places, a
    /// dot sending for museo.fm. (The kit's `symbol` has two trays; one is quieter.)
    var shellSymbol: String {
        switch self {
        case .yours: "square.grid.2x2"
        case .places: "tray"
        case .fm: "dot.radiowaves.left.and.right"
        }
    }
}

nonisolated enum PocketShellMetrics {
    /// The tab bar's words.
    static let tabWord: CGFloat = 10
}

/// A tab's word and symbol. The bar fills symbols by default, which reads heavy on the
/// dune; the outline stays light under the glass, selected or not.
private struct PocketTabLabel: View {
    let tab: PocketTabID

    var body: some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(systemName: tab.shellSymbol)
                .environment(\.symbolVariants, .none)
        }
    }
}

/// The tab bar's words in Satoshi, ink70 at rest and moss when selected. SwiftUI has no
/// hook for a tab's font, so this goes through UIKit's appearance, once (museo dune's way).
/// The bar's glass itself takes no tint on iOS 26.
private enum PocketTabBarWords {
    private static var applied = false

    static func apply() {
        guard !applied else { return }
        applied = true
        let font = UIFont(name: MuseFont.name(.satoshiMedium), size: PocketShellMetrics.tabWord)
            ?? UIFont.systemFont(ofSize: PocketShellMetrics.tabWord, weight: .medium)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(MuseColor.ink70)
        item.normal.titleTextAttributes = [.font: font, .foregroundColor: UIColor(MuseColor.ink70)]
        item.selected.iconColor = UIColor(MuseColor.moss)
        item.selected.titleTextAttributes = [.font: font, .foregroundColor: UIColor(MuseColor.moss)]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Search

/// Search: finds a thought by what was said. The fixture thoughts as a quiet list, filtered
/// by the words typed. Shell a shows it in the search tab (the bar becomes the field); shell
/// b opens it from the glass circle.
struct PocketSearchPage: View {
    @State private var query = ""

    private var found: [PocketThought] {
        let words = query.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return PocketFixtures.thoughts }
        return PocketFixtures.thoughts.filter {
            $0.title.localizedCaseInsensitiveContains(words) || $0.body.localizedCaseInsensitiveContains(words)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(found) { thought in
                        NavigationLink {
                            PocketThoughtPage(thought: thought)
                        } label: {
                            row(thought)
                        }
                        .buttonStyle(.plain)
                    }
                    if found.isEmpty {
                        Text("nothing you said sounds like that.")
                            .font(MuseType.body)
                            .foregroundStyle(MuseColor.ink55)
                            .padding(.top, MuseSpacing.sectionLabel)
                    }
                }
                .padding(.horizontal, PocketGrid.gutter)
            }
            .scrollIndicators(.hidden)
            .background { PocketGround() }
            .searchable(text: $query, prompt: "what you said")
        }
    }

    private func row(_ thought: PocketThought) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(thought.title)
                .font(MuseType.headline)
                .foregroundStyle(thought.ink.title)
                .multilineTextAlignment(.leading)
            Text("\(thought.day) · \(thought.time)")
                .font(MuseType.meta)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MuseSpacing.row)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
#endif
