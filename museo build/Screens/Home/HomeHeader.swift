import Foundation
import SwiftUI
import MuseoKit

// The top of the home: the chrome row (build and how museo works on the left, the one ring
// icon on the right),
// then the title with its quiet count, sort and search at the end of that row, and one
// status line from the ring under it.

// MARK: - Chrome row

/// Pinned above the library: the hammer opens build, the question mark the cheat card, the
/// ring icon the ring sheet.
struct HomeChrome: View {
    let status: RingStatus
    let ringStyle: AppConfig.RingButtonStyle
    let onBuild: () -> Void
    let onHowItWorks: () -> Void
    let onRing: () -> Void

    /// Chrome circles sit inside 44pt targets; pull the row out so the circles, not the
    /// targets, line up with the page gutter.
    static let gutter = MuseSpacing.page - (MuseTopChrome.hitTarget - MuseTopChrome.circle) / 2

    var body: some View {
        HStack(alignment: .center, spacing: MuseSpacing.sm) {
            // A pair, like sort and search: the 44pt targets touch, the circles sit 6pt apart.
            HStack(spacing: 0) {
                MuseChromeIcon("hammer", label: "build", action: onBuild)
                MuseChromeIcon("questionmark", label: "how museo works", action: onHowItWorks)
            }
            Spacer(minLength: MuseSpacing.sm)
            RingButton(status: status, style: ringStyle, action: onRing)
        }
        .frame(minHeight: MuseTopChrome.hitTarget)
        .padding(.horizontal, Self.gutter)
        // Right under the status bar; a breath below before the title.
        .padding(.bottom, MuseSpacing.xxs)
    }
}

// MARK: - Title and status

/// "museo." in Lora 40 with a quiet count beside it ("12 · 3 today"), the library's
/// controls at the end of that row, and right under it one line from the ring: "ring
/// linked", "listening…", "bringing in 3". Before the ring is set up the line asks for that
/// instead.
struct HomeHeader<Controls: View>: View {
    let status: RingStatus
    /// "12 · 3 today". Nil hides it (nothing to count yet).
    var count: String?
    /// The empty home before setup says it bigger, so the line steps aside there.
    var showsStatus: Bool = true
    /// The island already says what the ring is doing, so beside it the line only shows
    /// what the island doesn't: what to do next.
    var ringStyle: AppConfig.RingButtonStyle = AppConfig.ringButtonStyle
    let onRing: () -> Void
    @ViewBuilder let controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                title
                Spacer(minLength: MuseSpacing.xs)
                controls
                    // The circles, not their 44pt targets, meet the gutter.
                    .padding(.trailing, -(MuseTopChrome.hitTarget - MuseTopChrome.circle) / 2)
            }
            if showsStatus, HomeStatusLine.line(for: status, besideIsland: ringStyle == .island) != nil {
                HomeStatusLine(status: status, besideIsland: ringStyle == .island, action: onRing)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
            Text(verbatim: "\(AppConfig.appName).")
                .font(MuseType.display)
                .tracking(MuseType.displayTracking)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            if let count {
                Text(verbatim: count)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(.numericText())
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension HomeHeader where Controls == EmptyView {
    init(status: RingStatus, count: String? = nil, showsStatus: Bool = true, onRing: @escaping () -> Void) {
        self.init(status: status, count: count, showsStatus: showsStatus, onRing: onRing, controls: { EmptyView() })
    }
}

/// The one line under the title. The dot is moss while linked, and breathes while a muse
/// streams in or a sync runs (the dot is moss: clay is only for consequence). Quiet ink
/// otherwise. Tapping it opens the ring sheet. A nearly full ring says so here, with a
/// chevron: the ring sheet has the one thing that makes room.
///
/// Beside the island it says only what the island can't: set up, make room, how to wake
/// a ring that's away, turn bluetooth on. Otherwise it steps aside (`line` is nil).
struct HomeStatusLine: View {
    let status: RingStatus
    var besideIsland = false
    let action: () -> Void

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                MuseLiveDot(color: dotColor, size: 7, pulses: pulses)
                Text(line)
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink70)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                if asksForSetUp || asksForRoom {
                    Image(systemName: "chevron.right")
                        .museSymbol(11, weight: .semibold)
                        .foregroundStyle(MuseColor.ink55)
                        .accessibilityHidden(true)
                }
            }
            // The line sits tight under the title; its hit area still reaches 44pt.
            .contentShape(Rectangle().inset(by: -MuseSpacing.sm))
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .museAnimation(MuseMotion.dissolve, value: line)
        .accessibilityLabel(line.replacingOccurrences(of: " · ", with: ", "))
        .accessibilityHint("opens your ring")
        .accessibilityInputLabels([Text("your ring"), Text("ring")])
    }

    private var asksForSetUp: Bool { status.link == .notSetUp && !status.isFirmwareUpdating }

    /// Linked, nearly full and idle: the line says so until there's room again.
    private var asksForRoom: Bool { status.room != nil && !status.isSyncing }

    var line: String { Self.line(for: status, besideIsland: besideIsland) ?? "" }

    /// "ring linked", "listening…", "bringing in 3", "ring nearly full · about 22 min left",
    /// "set up your ring to begin". Beside the island, nil unless there's something to do.
    static func line(for status: RingStatus, besideIsland: Bool) -> String? {
        let asksForSetUp = status.link == .notSetUp && !status.isFirmwareUpdating
        let asksForRoom = status.room != nil && !status.isSyncing
        if asksForSetUp { return "set up your ring to begin" }
        if asksForRoom, let storage = status.storageLine { return "ring \(storage)" }
        guard besideIsland else { return status.shortLine }
        guard !status.isFirmwareUpdating else { return nil }
        switch status.link {
        case .away: return status.headline
        case .bluetoothOff: return status.deviceLine
        case .notSetUp, .joining, .linked: return nil
        }
    }

    private var dotColor: Color {
        status.isLive || status.isLinked ? MuseColor.moss600 : MuseColor.ink55
    }

    /// Breathes while something is happening: a muse streaming in, or a sync.
    private var pulses: Bool {
        status.isLive || (status.isLinked && status.isSyncing)
    }
}

// MARK: - Previews

#Preview("home header") {
    @Previewable @State var sort = LibrarySort.newest
    VStack(alignment: .leading, spacing: MuseSpacing.xl) {
        HomeChrome(status: .linked, ringStyle: .island, onBuild: {}, onHowItWorks: {}, onRing: {})
        HomeHeader(status: .linked, count: "12 · 3 today", onRing: {}) {
            LibraryControls(sort: $sort, searchOpen: false) {}
        }
        HomeHeader(status: .live, count: "1 muse", onRing: {})
        HomeHeader(status: .syncing, onRing: {})
        HomeHeader(status: .nearlyFull, onRing: {})
        HomeHeader(status: .notSetUp, onRing: {})
    }
    .padding(.horizontal, MuseSpacing.page)
    .frame(maxHeight: .infinity, alignment: .top)
    .background { MuseShelfBackground() }
}
