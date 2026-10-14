import Foundation
import SwiftUI
import MuseoKit

// MARK: - Environment the home reads

extension EnvironmentValues {
    /// Pull to refresh on the home: bring in recordings waiting on the ring. `RootView` sets
    /// it to `Museo.manager?.startOfflineSyncIfNeeded()`; lab screens and previews keep the
    /// no-op.
    @Entry var museSyncNow: () -> Void = {}
    /// The empty home's "set up your ring". Nil opens the ring sheet instead.
    @Entry var museSetUpRing: (() -> Void)? = nil
    /// When set, muse tiles are zoom sources and the muse page zooms out of its tile
    /// (`RootView` owns the namespace).
    @Entry var museZoomSpace: Namespace.ID? = nil
    /// The clock the library reads relative times and day rules against ("52m ago",
    /// "today"). Nil is the real clock; lab screens pin it to 9:41a so shots stay the same.
    @Entry var museLibraryNow: Date? = nil
}

// MARK: - Home

/// The library: the title with a quiet count, how the ring is, pills
/// to narrow it (all, streamed, memory, long, typed), sort and search, then every muse as a
/// tile on the shelf, two up, by day. New muses arrive here: a streaming card while the ring
/// streams, then the muse itself settling in as the first tile, its title typing in once
/// its words land.
///
/// Tap a tile for its page (and swipe through the ones on screen); long press to copy, share
/// or delete. Everything comes from the environment (`MuseStore`, `RingModel`,
/// `MusePipeline`, `AppRouter`), so the lab can show it with fixtures.
struct HomeView: View {
    @Environment(MuseStore.self) private var store
    @Environment(MusePipeline.self) private var pipeline
    @Environment(RingModel.self) private var ring
    @Environment(AppRouter.self) private var router
    @Environment(\.museSyncNow) private var syncNow
    @Environment(\.museSetUpRing) private var setUpRing
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var arrivals = ArrivalTracker()
    /// Off for the first render, so nothing animates in when the home opens.
    @State private var hasAppeared = false
    @State private var isOnScreen = false
    /// The visible height of the page, and of the title block, so the empty home can fill
    /// what's left.
    @State private var viewport: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    /// When the take on the streaming card began, and when it ended (the card holds as
    /// "keeping it" until its muse lands, a few seconds at most).
    @State private var streamSince: Date?
    @State private var streamEndedAt: Date?
    @State private var toast: String?
    /// The muse whose delete is being confirmed.
    @State private var deleting: Muse?
    @State private var confirmsDelete = false

    // Narrowing and order.
    @State private var filter: LibraryFilter
    /// The sort, remembered between launches.
    @AppStorage("museo.library.sort") private var savedSort = LibrarySort.newest
    /// A sort that isn't saved (lab screens), so a screenshot never changes the next one.
    @State private var heldSort: LibrarySort?

    // Search.
    @State private var searchOpen: Bool
    @State private var query: String
    /// Hits, best first; nil while not searching.
    @State private var hits: [UUID]?
    @FocusState private var searchFocused: Bool

    // Scrolling.
    @State private var position = ScrollPosition(idType: UUID.self)
    @State private var showsJump = false

    /// How long the streaming card waits for its muse after the take ends.
    private static let landingHold: Duration = .seconds(3)

    /// - Parameters:
    ///   - filter: the pill it opens on.
    ///   - sort: an order that isn't remembered (lab screens). Nil reads the saved one.
    ///   - query: opens with search open on these words (lab screens).
    init(filter: LibraryFilter = .all, sort: LibrarySort? = nil, query: String? = nil) {
        _filter = State(initialValue: filter)
        _heldSort = State(initialValue: sort)
        _searchOpen = State(initialValue: query != nil)
        _query = State(initialValue: query ?? "")
    }

    var body: some View {
        let status = ring.status
        let muses = store.muses
        let isEmpty = muses.isEmpty && !showsStreamingCard

        ZStack {
            background(isEmpty: isEmpty)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    top(status: status, muses: muses, isEmpty: isEmpty)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    if isEmpty {
                        HomeEmpty(
                            status: status,
                            minHeight: max(0, viewport - headerHeight),
                            onSetUp: setUp,
                            onSamples: { pipeline.loadSamples() }
                        )
                        .transition(.opacity)
                    } else {
                        library(status: status)
                            .padding(.top, MuseSpacing.card)
                            .padding(.bottom, MuseSpacing.sectionLabel)
                    }
                }
                .padding(.horizontal, MuseSpacing.page)
                // The first muse or the streaming card replaces the empty home in the same
                // drift. The library animates its own tiles (`HomeLibrary`).
                .animation(arrivalAnimation, value: isEmpty)
                .animation(MuseMotion.adaptive(MuseMotion.snappy, reduceMotion: reduceMotion), value: searchOpen)
                .background(alignment: .top) { viewportProbe }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .scrollPosition($position)
            .museJumpTracking($showsJump)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top, spacing: 0) {
                HomeChrome(
                    status: status,
                    ringStyle: AppConfig.ringButtonStyle,
                    onBuild: { router.open(.build()) },
                    onHowItWorks: { router.open(.howItWorks) },
                    onRing: { router.open(.ring) }
                )
            }
            .museBottomBlur(wash: isEmpty ? MuseColor.ground : MuseColor.shelf)
            .refreshable { await refresh() }
        }
        .museJumpToTop($position, visible: showsJump && toast == nil && !isEmpty)
        .museToast($toast)
        .confirmationDialog(
            "delete this muse?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible,
            presenting: deleting
        ) { muse in
            Button("delete", role: .destructive) { store.remove(muse.id) }
            Button("keep it", role: .cancel) {}
        } message: { _ in
            Text("its words, notes and audio are gone for good.")
        }
        .onChange(of: confirmsDelete) { _, asking in
            if !asking { deleting = nil }
        }
        .onAppear {
            isOnScreen = true
            if status.isLive { streamSince = status.liveSince ?? .now }
        }
        .onDisappear { isOnScreen = false }
        .task { hasAppeared = true }
        .onChange(of: status.isLive) { _, streaming in streamingChanged(streaming) }
        .onChange(of: muses.map(\.id)) { old, new in musesChanged(from: old, to: new) }
        .onChange(of: LibraryFilter.available(in: muses)) { _, available in
            if !available.contains(filter) { filter = .all }
        }
        .onChange(of: muses.isEmpty) { _, empty in
            if empty { closeSearch() }
        }
        .onChange(of: sort) { _, _ in MuseHaptics.play(.selection) }
        // Only an open search pays for the fingerprint; ring ticks redraw this body often.
        .onChange(of: SearchRequest(open: searchOpen, query: query, filter: filter, muses: searchOpen ? fingerprint(muses) : 0), initial: true) {
            search()
        }
        .task(id: searchOpen) { await warmSearch() }
        .task(id: streamEndedAt) {
            guard streamEndedAt != nil else { return }
            try? await Task.sleep(for: Self.landingHold)
            guard !Task.isCancelled else { return }
            streamEndedAt = nil
            streamSince = nil
        }
    }

    /// The library sits on the dotted shelf; the empty home keeps the plain linen wash.
    @ViewBuilder
    private func background(isEmpty: Bool) -> some View {
        ZStack {
            if isEmpty {
                MuseBackground()
                    .transition(.opacity)
            } else {
                MuseShelfBackground()
                    .transition(.opacity)
            }
        }
        .animation(arrivalAnimation, value: isEmpty)
    }

    /// Measures the page's visible height (the scroll view less its bars and safe areas),
    /// without taking part in the layout.
    private var viewportProbe: some View {
        Color.clear
            .frame(width: 0)
            .containerRelativeFrame(.vertical)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
            .accessibilityHidden(true)
    }

    // MARK: Top

    private func top(status: RingStatus, muses: [Muse], isEmpty: Bool) -> some View {
        let hasMuses = !muses.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            HomeHeader(
                status: status,
                count: hasMuses ? count(muses) : nil,
                showsStatus: !(isEmpty && status.link == .notSetUp),
                onRing: { router.open(.ring) }
            ) {
                if hasMuses {
                    LibraryControls(sort: sortBinding, searchOpen: searchOpen, onSearch: toggleSearch)
                        .transition(.opacity)
                }
            }
            if hasMuses {
                LibraryFilterBar(filters: LibraryFilter.available(in: muses), selection: $filter)
                    .padding(.top, MuseSpacing.sm)
                    .transition(.opacity)
                if searchOpen {
                    LibrarySearchField(query: $query, focus: $searchFocused)
                        .padding(.top, MuseSpacing.xs)
                        // Under Reduce Motion it only fades in.
                        .transition(reduceMotion ? AnyTransition.opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    /// "12 · 3 today", or "12 muses" on a day with none yet.
    private func count(_ muses: [Muse]) -> String {
        let calendar = Calendar.current
        let today = muses.prefix { calendar.isDateInToday($0.createdAt) || $0.createdAt > .now }.count
        let total = muses.count.formatted()
        if today > 0 { return "\(total) · \(today) today" }
        return muses.count == 1 ? "1 muse" : "\(total) muses"
    }

    // MARK: Library

    /// Every muse on the shelf. Takes plain values only, so a ring status tick that changes
    /// none of them skips the library's body (and the whole shelf's regrouping with it).
    private func library(status: RingStatus) -> some View {
        HomeLibrary(
            showsStreamingCard: showsStreamingCard,
            streamSince: showsStreamingCard ? streamSince ?? status.liveSince : nil,
            streamEndedAt: streamEndedAt,
            // The ring icon's clay (nearly full, low battery) is the page's one clay mark
            // then. Streaming isn't: the status dot is moss, so a failed muse keeps its clay.
            clayBlocked: status.needsAttention || status.isLowBattery,
            isVisible: isVisible,
            animates: hasAppeared,
            arrivals: arrivals,
            filter: filter,
            sort: sort,
            hits: hits,
            onShowAll: { filter = .all },
            onCopied: { toast = $0 },
            onDelete: askToDelete
        )
        .equatable()
    }

    // MARK: State

    private var sort: LibrarySort { heldSort ?? savedSort }

    private var sortBinding: Binding<LibrarySort> {
        Binding {
            heldSort ?? savedSort
        } set: { newSort in
            if heldSort != nil { heldSort = newSort } else { savedSort = newSort }
        }
    }

    /// On screen and in front, with no sheet over it or one at half height (the ring
    /// sheet opens there, and the top of the home still shows above it). At full height
    /// fresh words wait for the home, so they don't use up their typing behind a sheet.
    private var isVisible: Bool {
        isOnScreen && scenePhase == .active
            && (router.sheet == nil || router.sheetDetent == .medium)
    }

    private var showsStreamingCard: Bool {
        ring.status.isLive || streamEndedAt != nil
    }

    /// Nothing animates on the first render; after that, arrivals drift in.
    private var arrivalAnimation: Animation? {
        hasAppeared ? MuseMotion.adaptive(MuseMotion.drift, reduceMotion: reduceMotion) : nil
    }

    // MARK: Search

    /// What a search depends on. A muse's words, title or notes landing, a rename, or one
    /// leaving runs it again.
    private struct SearchRequest: Equatable {
        let open: Bool
        let query: String
        let filter: LibraryFilter
        let muses: Int
    }

    /// Changes when a muse arrives, leaves, gets its words, or its title or notes change.
    /// It covers what `MuseSearch` reads (title, notes bullets, words), so an open search
    /// never ranks against text that has since changed.
    private func fingerprint(_ muses: [Muse]) -> Int {
        var hasher = Hasher()
        hasher.combine(muses.count)
        for muse in muses where muse.isTranscribed {
            hasher.combine(muse.id)
            hasher.combine(muse.title)
            hasher.combine(muse.notes?.bullets)
        }
        return hasher.finalize()
    }

    private func toggleSearch() {
        if searchOpen {
            closeSearch()
        } else {
            searchOpen = true
            searchFocused = true
        }
    }

    private func closeSearch() {
        searchOpen = false
        query = ""
        searchFocused = false
    }

    /// The current pill's muses closest to the query, best first. Two letters at least.
    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchOpen, trimmed.count > 1 else {
            if hits != nil { hits = nil }
            return
        }
        let pool = store.muses.filter(filter.includes)
        hits = MuseSearch.search(trimmed, in: pool, limit: max(pool.count, 1)).map(\.id)
    }

    /// Opening search starts embedding the muses that have no vector yet, then searches
    /// again once they're likely in, so the first query finds by meaning too.
    private func warmSearch() async {
        guard searchOpen else { return }
        MuseSearch.remember(store.muses)
        try? await Task.sleep(for: .seconds(1.2))
        guard !Task.isCancelled else { return }
        search()
    }

    // MARK: Events

    private func streamingChanged(_ streaming: Bool) {
        if streaming {
            streamEndedAt = nil
            streamSince = ring.status.liveSince ?? .now
            if hasAppeared, isVisible { MuseHaptics.play(.soft) }
        } else if streamSince != nil {
            // Already here (the muse beat the status change)? Then there's nothing to hold for.
            let landed = store.muses.contains { $0.origin == .stream && $0.isFresh(within: 2) }
            if landed {
                streamSince = nil
            } else {
                streamEndedAt = .now
            }
        }
    }

    private func musesChanged(from old: [UUID], to new: [UUID]) {
        let added = Set(new).subtracting(old)
        let removed = Set(old).subtracting(new)
        if !removed.isEmpty { arrivals.forget(removed) }
        guard !added.isEmpty else { return }
        let landed = store.muses.filter { added.contains($0.id) }
        // The streamed muse takes the streaming card's place in the same movement.
        if streamEndedAt != nil, landed.contains(where: { $0.origin == .stream }) {
            streamEndedAt = nil
            streamSince = nil
        }
        if hasAppeared, isVisible, landed.contains(where: { $0.origin.isRing }) {
            MuseHaptics.play(.received)
        }
    }

    private func askToDelete(_ muse: Muse) {
        MuseHaptics.play(.warning)
        deleting = muse
        confirmsDelete = true
    }

    private func setUp() {
        if let setUpRing {
            setUpRing()
        } else {
            router.open(.ring)
        }
    }

    /// Pull to refresh: bring in what's waiting on the ring.
    private func refresh() async {
        let status = ring.status
        guard status.isLinked else {
            toast = switch status.link {
            case .notSetUp: "set up your ring first"
            case .bluetoothOff: "bluetooth is off"
            default: "your ring is away · bring it close"
            }
            return
        }
        syncNow()
        try? await Task.sleep(for: .seconds(0.8))
    }
}

// MARK: - Previews

private extension View {
    func homePreview(_ muses: [Muse], ring: RingStatus) -> some View {
        let store = MuseStore.preview(muses)
        return self
            .environment(store)
            .environment(RingModel.preview(ring))
            .environment(MusePipeline.preview(store))
            .environment(AppRouter())
    }
}

#Preview("home · library") {
    HomeView().homePreview(SampleMuses.make(now: .now), ring: .linked)
}

#Preview("home · search") {
    HomeView(query: "window").homePreview(SampleMuses.make(now: .now), ring: .linked)
}

#Preview("home · streaming") {
    HomeView().homePreview(SampleMuses.make(now: .now), ring: .live)
}

#Preview("home · empty, not set up") {
    HomeView().homePreview([], ring: .notSetUp)
}

#Preview("home · empty, linked") {
    HomeView().homePreview([], ring: .linked)
}
