#if DEBUG
import SwiftUI

/// The library: your thoughts as the two column grid on the dune, a hairline and one word
/// between days, ink receding with age. Tap a tile and it zooms into the thought.
///
/// It brings its own `NavigationStack` (the shells do not), and draws no tab bar or pill.
struct PocketYoursTab: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var zoom
    @State private var path: [PocketThought] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: MuseSpacing.section) {
                    PocketPageTitle("your thoughts", count: PocketFixtures.yoursCount, leading: {
                        PocketGlassCircle("gearshape", label: "settings")
                    })
                    .padding(.horizontal, PocketGrid.gutter)

                    ForEach(PocketFixtures.days, id: \.day) { group in
                        day(group.day, thoughts: group.thoughts)
                    }
                }
                .padding(.top, PocketChrome.top)
            }
            .pocketTabScroll()
            .background { PocketGround() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PocketThought.self) { thought in
                PocketThoughtPage(thought: thought)
                    .navigationTransition(.zoom(sourceID: thought.id, in: zoom))
            }
        }
        .pocketChromeHidden(!path.isEmpty)
    }

    // MARK: - A day

    private func day(_ name: String, thoughts: [PocketThought]) -> some View {
        VStack(spacing: MuseSpacing.sm) {
            PocketDayBreak(name)
            LazyVGrid(
                columns: PocketGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize),
                spacing: PocketGrid.spacing
            ) {
                if name == "today", case .streaming(let words) = PocketFixtures.ring {
                    PocketStreamingTile(words: words)
                }
                ForEach(thoughts) { thought in
                    tile(thought)
                }
            }
        }
        .padding(.horizontal, PocketGrid.gutter)
    }

    private func tile(_ thought: PocketThought) -> some View {
        Button {
            MuseHaptics.play(.soft)
            path.append(thought)
        } label: {
            PocketTile(
                title: thought.title,
                foot: thought.foot,
                footDot: thought.foot == nil ? nil : MuseColor.moss600,
                ink: thought.ink
            )
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .matchedTransitionSource(id: thought.id, in: zoom) {
            $0.clipShape(RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous))
        }
    }
}

// MARK: - Day break

/// One word and a hairline: "yesterday" ────────
private struct PocketDayBreak: View {
    let day: String

    init(_ day: String) {
        self.day = day
    }

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(day)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(height: PocketYoursMetrics.hairline)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, MuseSpacing.xxs)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - The streaming tile

/// While the ring streams, the first tile is the one being said: the words arriving in
/// Lora, under the ring's white light.
private struct PocketStreamingTile: View {
    let words: String

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = PocketGrid.tileHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(words)
                .font(MuseType.headline)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(PocketGrid.titleLines)
                .truncationMode(.head)
                .multilineTextAlignment(.leading)
            Spacer(minLength: MuseSpacing.xs)
            HStack(spacing: MuseSpacing.xs) {
                Circle()
                    .fill(MuseColor.raised)
                    .frame(width: PocketGrid.footDot, height: PocketGrid.footDot)
                    .shadow(color: MuseColor.raised, radius: PocketGrid.footDot)
                    .accessibilityHidden(true)
                Text("streaming…")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink70)
            }
        }
        .padding(.horizontal, PocketGrid.tilePaddingH)
        .padding(.vertical, PocketGrid.tilePaddingV)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .pocketTileGlass()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metrics

private nonisolated enum PocketYoursMetrics {
    /// A day break's rule.
    static let hairline: CGFloat = 1
}

#Preview {
    PocketYoursTab()
}
#endif
