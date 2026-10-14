import SwiftUI

/// The home's muses: the streaming card while the ring streams, then the shelf of tiles two up,
/// by day (newest or oldest) or in one run (longest, shortest), then "that's everything.".
/// While searching, the hits best first under one rule ("4 muses").
///
/// Its own view so a ring status tick (sync progress, the battery, the waiting count) only
/// redraws the title and the chrome. `HomeView` hands it plain values and it skips its body
/// unless one of them changed, or a muse did. The grid is lazy, so only the tiles on screen
/// are drawn, however long the library gets.
struct HomeLibrary: View, Equatable {
    /// The ring is streaming, or the take just ended and its muse hasn't landed yet.
    let showsStreamingCard: Bool
    /// When the take on the streaming card began.
    let streamSince: Date?
    /// When the take ended (the card holds as "keeping it"). Nil while still listening.
    let streamEndedAt: Date?
    /// Something above already wears the page's clay mark (the ring icon when the ring
    /// needs something: nearly full, low battery).
    let clayBlocked: Bool
    /// The home is in front with nothing full height over it (`ArrivalTracker`).
    let isVisible: Bool
    /// Off for the first render, so nothing animates in when the home opens.
    let animates: Bool
    let arrivals: ArrivalTracker
    let filter: LibraryFilter
    let sort: LibrarySort
    /// Search hits, best first, or nil while not searching.
    let hits: [UUID]?
    /// "try all." under an empty pill.
    var onShowAll: () -> Void = {}
    /// A copy from a tile's menu, with its line for the toast ("words copied.").
    var onCopied: (String) -> Void = { _ in }
    /// "delete" from a tile's menu. The home asks first.
    var onDelete: (Muse) -> Void = { _ in }

    @Environment(MuseStore.self) private var store
    @Environment(MusePipeline.self) private var pipeline
    @Environment(\.museLiveWords) private var liveWords
    @Environment(AppRouter.self) private var router
    @Environment(\.museZoomSpace) private var zoomSpace
    @Environment(\.museLibraryNow) private var pinnedNow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The closures are left out on purpose: they only set the home's own state, so an
    /// older copy does what a newer one would.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showsStreamingCard == rhs.showsStreamingCard && lhs.streamSince == rhs.streamSince
            && lhs.streamEndedAt == rhs.streamEndedAt && lhs.clayBlocked == rhs.clayBlocked
            && lhs.isVisible == rhs.isVisible && lhs.animates == rhs.animates
            && lhs.arrivals === rhs.arrivals && lhs.filter == rhs.filter
            && lhs.sort == rhs.sort && lhs.hits == rhs.hits
    }

    var body: some View {
        let shelf = makeShelf()
        let allIDs = store.muses.map(\.id)
        VStack(alignment: .leading, spacing: 0) {
            if showsStreamingCard {
                StreamingMuseCard(
                    since: streamSince ?? .now,
                    endedAt: streamEndedAt,
                    heard: liveWords?.heard ?? "",
                    hearing: liveWords?.hearing ?? ""
                )
                    .padding(.bottom, hits == nil && store.muses.isEmpty ? 0 : MuseSpacing.lg)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            content(shelf)
        }
        // Innermost wins when several change at once: an arrival drifts in, and every tile
        // after it moves along with it.
        .animation(arrivalAnimation, value: allIDs)
        .animation(arrivalAnimation, value: showsStreamingCard)
        .animation(changeAnimation, value: filter)
        .animation(changeAnimation, value: sort)
        .animation(changeAnimation, value: hits)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ shelf: Shelf) -> some View {
        if let hits {
            if hits.isEmpty || shelf.isEmpty {
                LibraryMiss(kind: .search)
            } else {
                grid(shelf)
            }
        } else if store.muses.isEmpty {
            // Only the streaming card: the first muse is on its way.
            EmptyView()
        } else if shelf.isEmpty {
            LibraryMiss(kind: .filter, onShowAll: onShowAll)
        } else {
            grid(shelf)
            Text("that's everything.")
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink55)
                .frame(maxWidth: .infinity)
                .padding(.top, MuseSpacing.sectionLabel)
        }
    }

    private func grid(_ shelf: Shelf) -> some View {
        let pool = shelf.muses.map(\.id)
        let clayID = clayBlocked ? nil : shelf.muses.first { $0.transcriptionState == .failed }?.id
        let first = shelf.sections.first?.id
        return LazyVGrid(columns: columns, alignment: .leading, spacing: MuseSpacing.lg) {
            ForEach(shelf.sections) { section in
                if let title = section.title {
                    Section {
                        ForEach(section.muses) { muse in
                            tile(muse, pool: pool, clayID: clayID)
                        }
                    } header: {
                        DayRule(title)
                            .padding(.top, section.id == first ? 0 : MuseSpacing.sm)
                    }
                } else {
                    ForEach(section.muses) { muse in
                        tile(muse, pool: pool, clayID: clayID)
                    }
                }
            }
        }
    }

    /// Two up; one wide at the accessibility text sizes, so three lines of title still read.
    private var columns: [GridItem] {
        let column = GridItem(.flexible(), spacing: MuseSpacing.sm, alignment: .top)
        return dynamicTypeSize.isAccessibilitySize ? [column] : [column, column]
    }

    // MARK: Tile

    private func tile(_ muse: Muse, pool: [UUID], clayID: UUID?) -> some View {
        Button {
            MuseHaptics.play(.soft)
            router.open(muse: muse.id, among: pool)
        } label: {
            MuseTile(
                muse: muse,
                ink: arrivals.mode(for: muse, visible: isVisible, enabled: AppConfig.typesNewWords),
                isNoting: pipeline.noting.contains(muse.id),
                failsInClay: muse.id == clayID,
                onTyped: { arrivals.finished(muse.id) }
            )
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous))
        .contextMenu {
            MuseExportActions(muse: muse, onCopied: onCopied)
            Divider()
            Button(role: .destructive) {
                onDelete(muse)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
        .modifier(MuseTileZoomSource(id: muse.id, space: zoomSpace))
        .transition(reduceMotion ? .opacity : .museArrival)
    }

    // MARK: Shelf

    /// What's on the shelf right now, in on-screen order.
    private struct Shelf {
        var sections: [Run]
        var muses: [Muse] { sections.flatMap(\.muses) }
        var isEmpty: Bool { sections.allSatisfy(\.muses.isEmpty) }

        /// A day of muses under its rule, or the whole shelf in one run.
        struct Run: Identifiable {
            let id: String
            /// The rule above it; nil for one run without rules.
            let title: String?
            let muses: [Muse]
        }
    }

    private func makeShelf() -> Shelf {
        if let hits {
            let byID = Dictionary(store.muses.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let found = hits.compactMap { byID[$0] }
            let count = found.count == 1 ? "1 muse" : "\(found.count) muses"
            return Shelf(sections: [.init(id: "hits", title: count, muses: found)])
        }
        let shown = sort.ordered(store.muses.filter(filter.includes))
        guard sort.usesDayRules else {
            return Shelf(sections: [.init(id: "all", title: nil, muses: shown)])
        }
        // `shown` is already in day order (newest or oldest first), so days follow in turn.
        let calendar = Calendar.current
        let now = pinnedNow ?? .now
        var sections: [Shelf.Run] = []
        var day: Date?
        var run: [Muse] = []
        func close() {
            guard let day, !run.isEmpty else { return }
            sections.append(.init(id: "\(day.timeIntervalSinceReferenceDate)", title: DayRule.title(for: day, now: now), muses: run))
        }
        for muse in shown {
            let start = calendar.startOfDay(for: muse.createdAt)
            if start != day {
                close()
                day = start
                run = []
            }
            run.append(muse)
        }
        close()
        return Shelf(sections: sections)
    }

    // MARK: Motion

    /// Nothing animates on the first render; after that, arrivals drift in.
    private var arrivalAnimation: Animation? {
        animates ? MuseMotion.adaptive(MuseMotion.drift, reduceMotion: reduceMotion) : nil
    }

    /// A pill, a sort or a search reflowing the shelf.
    private var changeAnimation: Animation? {
        animates ? MuseMotion.snappy : nil
    }
}

// MARK: - Zoom source

/// Lets the muse page zoom out of its tile when the home is given a namespace.
private struct MuseTileZoomSource: ViewModifier {
    let id: UUID
    let space: Namespace.ID?

    func body(content: Content) -> some View {
        if let space {
            content.matchedTransitionSource(id: id, in: space) { source in
                source.clipShape(RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous))
            }
        } else {
            content
        }
    }
}
