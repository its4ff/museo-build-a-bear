#if DEBUG
import SwiftUI

/// museo.fm: a collection of human thoughts from rings around the world. One thought is
/// given room at the top, its words straight on the dune; the rest are the same quiet grid
/// as the library. No names, no counts, nothing to follow.
struct PocketFMTab: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var zoom
    @State private var isPlaying = false
    @State private var path: [PocketFMThought] = []

    private let thoughts = PocketFixtures.fmThoughts

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    PocketPageTitle("museo.fm", count: "thoughts from rings around the world", leading: {
                        PocketGlassCircle("gearshape", label: "settings")
                    })
                    .padding(.horizontal, PocketGrid.gutter)

                    if let featured = thoughts.first {
                        self.featured(featured)
                            .padding(.top, PocketFMMetrics.air)
                            .padding(.bottom, PocketFMMetrics.air)
                    }

                    LazyVGrid(
                        columns: PocketGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize),
                        spacing: PocketGrid.spacing
                    ) {
                        ForEach(thoughts.dropFirst()) { thought in
                            tile(thought)
                        }
                    }
                    .padding(.horizontal, PocketGrid.gutter)

                    if let mine = thoughts.first(where: \.isYours) {
                        yoursLine(mine)
                            .padding(.top, MuseSpacing.section)
                    }
                }
                .padding(.top, PocketChrome.top)
            }
            .pocketTabScroll()
            .background { PocketGround() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PocketFMThought.self) { thought in
                PocketFMThoughtPage(thought: thought)
                    .navigationTransition(.zoom(sourceID: thought.id, in: zoom))
            }
        }
        .pocketChromeHidden(!path.isEmpty)
    }

    // MARK: - The one given room

    /// Words on paper, a lot of air: no card, the dune under the type.
    private func featured(_ thought: PocketFMThought) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
            NavigationLink(value: thought) {
                VStack(alignment: .leading, spacing: MuseSpacing.row) {
                    PocketBalanced {
                        Text(thought.words)
                            .font(MuseType.title)
                            .tracking(MuseType.titleTracking)
                            .lineSpacing(MuseType.serifLineSpacing)
                            .foregroundStyle(MuseColor.ink)
                            .multilineTextAlignment(.leading)
                    }
                    Text(thought.foot)
                        .font(MuseType.body)
                        .monospacedDigit()
                        .foregroundStyle(MuseColor.ink55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .matchedTransitionSource(id: thought.id, in: zoom)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))

            if thought.hasVoice {
                HStack(spacing: MuseSpacing.row) {
                    PocketGlassCircle(isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "pause" : "listen") {
                        isPlaying.toggle()
                    }
                    PocketFMWaveform(seed: thought.id, progress: isPlaying ? PocketFMMetrics.heard : 0)
                        .frame(height: PocketFMMetrics.waveHeight)
                        .museAnimation(MuseMotion.gentle, value: isPlaying)
                }
            }
        }
        .padding(.horizontal, PocketFMMetrics.inset)
    }

    // MARK: - The rest

    private func tile(_ thought: PocketFMThought) -> some View {
        NavigationLink(value: thought) {
            PocketFMTile(thought: thought)
            .matchedTransitionSource(id: thought.id, in: zoom) {
                $0.clipShape(RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous))
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(thought.hasVoice ? "with a voice" : "")
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
    }

    /// "3 of yours are here": the way to the ones you gave, and to taking one back.
    private func yoursLine(_ mine: PocketFMThought) -> some View {
        NavigationLink(value: mine) {
            Text(PocketFixtures.fmYoursLine)
                .font(MuseType.meta)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
                .frame(maxWidth: .infinity, minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
    }
}

// MARK: - Metrics

/// museo.fm's own measures, where no house token fits.
nonisolated enum PocketFMMetrics {
    /// The air above and below the thought given room: more than a section, so it reads
    /// as a page of its own.
    static let air: CGFloat = 58
    /// The featured words sit a step inside the grid's gutter, like the mac note's margin.
    static let inset: CGFloat = MuseSpacing.page + MuseSpacing.xs
    /// The dotted waveform's height beside the play circle.
    static let waveHeight: CGFloat = 32
    /// A tile here holds a whole sentence or two, so it stands a little taller than the
    /// library's and may take one more line. With the air above, the first row ends just
    /// above the ring pill and the second starts under it.
    static let tileHeight: CGFloat = 200
    static let tileLines = 6
    /// The tiny mark on a tile whose thought has a voice.
    static let voiceMark: CGFloat = 11
    /// One dot, and the step from dot to dot.
    static let dot: CGFloat = 2.5
    static let pitch: CGFloat = 5
    /// How far the mock has played once listening starts.
    static let heard: Double = 0.38
}

// MARK: - The tile

/// A thought in the collection. The shared tile's paddings, glass and foot, with the words
/// a step smaller (Lora 17) so a whole thought fits without being cut mid word.
private struct PocketFMTile: View {
    let thought: PocketFMThought

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = PocketFMMetrics.tileHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(thought.words)
                .font(MuseType.serif)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(PocketFMMetrics.tileLines)
                .multilineTextAlignment(.leading)
            Spacer(minLength: MuseSpacing.xs)
            // The shared tile's foot: a dot and one line. The tiny mark at the far end is
            // the voice, when they gave it.
            HStack(spacing: MuseSpacing.xs) {
                Circle()
                    .fill(MuseColor.moss600)
                    .frame(width: PocketGrid.footDot, height: PocketGrid.footDot)
                    .accessibilityHidden(true)
                Text(thought.foot)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
                    .lineLimit(1)
                if thought.isYours {
                    Spacer(minLength: MuseSpacing.xs)
                    Text("yours")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.moss600)
                } else if thought.hasVoice {
                    Spacer(minLength: MuseSpacing.xs)
                    Image(systemName: "waveform")
                        .museSymbol(PocketFMMetrics.voiceMark, weight: .medium)
                        .foregroundStyle(MuseColor.ink55)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, PocketGrid.tilePaddingH)
        .padding(.vertical, PocketGrid.tilePaddingV)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .pocketTileGlass()
    }
}

// MARK: - The dotted waveform

/// A voice drawn as columns of dots, the same halftone as the ring. Made from `seed`, so a
/// thought always draws the same shape. Dots up to `progress` take full ink.
struct PocketFMWaveform: View {
    let seed: String
    var progress: Double = 0

    var body: some View {
        let start = seed.unicodeScalars.reduce(UInt64(7)) { ($0 &* 31) &+ UInt64($1.value) }
        let heardInk = MuseColor.ink
        let restInk = MuseColor.ink55
        Canvas { context, size in
            let pitch = PocketFMMetrics.pitch
            let dot = PocketFMMetrics.dot
            let columns = max(Int(size.width / pitch), 1)
            let half = max(Int((size.height / 2) / pitch), 1)
            var state = start
            for column in 0..<columns {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let random = Double((state >> 33) % 1000) / 1000
                // Speech comes in phrases: a slow swell under the noise, soft at both ends.
                let place = Double(column) / Double(max(columns - 1, 1))
                let edge = min(place, 1 - place) * 6
                let swell = 0.35 + 0.65 * abs(((place * 5.3).truncatingRemainder(dividingBy: 1)) - 0.5) * 2
                let level = min(edge, 1) * swell * (0.35 + 0.65 * random)
                let reach = Int((level * Double(half)).rounded())
                let ink = place < progress ? heardInk : restInk
                let x = (CGFloat(column) + 0.5) * pitch
                for row in -reach...reach {
                    let y = size.height / 2 + CGFloat(row) * pitch
                    let rect = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(ink))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
#endif
