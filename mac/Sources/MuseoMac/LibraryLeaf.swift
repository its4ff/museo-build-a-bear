import SwiftUI

// The pieces every page in the library is set from: the reading column, the mono line, the
// large title, the foot with its keys, the thin player line, and the glass capsule of
// actions top right. A page draws no ground of its own: the window's dune shows through.

// MARK: - The column

/// The reading column: one measure, centered on the page, with empty paper above it.
struct LeafColumn<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .frame(maxWidth: LibraryMetrics.measure, alignment: .leading)
            .padding(.horizontal, MuseSpacing.sectionLabel)
            .padding(.top, LibraryMetrics.top)
            .padding(.bottom, MuseSpacing.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Type

/// One mono line: when and how a muse came in.
struct LeafMono: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MuseFont.mono(.caption))
            .foregroundStyle(MuseColor.ink55)
            .lineLimit(1)
    }
}

/// The large Lora title. `quiet` sets it in italic ink55, for a title still being written.
struct LeafTitle: View {
    let text: String
    var quiet = false

    init(_ text: String, quiet: Bool = false) {
        self.text = text
        self.quiet = quiet
    }

    private var isLong: Bool { text.count > LibraryMetrics.titleLongAfter }
    private var size: CGFloat { isLong ? LibraryMetrics.titleLong : LibraryMetrics.title }

    var body: some View {
        Text(text)
            .font(quiet ? MuseFont.loraItalic(size) : MuseFont.lora(size))
            .tracking(isLong ? LibraryMetrics.titleLongTracking : LibraryMetrics.titleTracking)
            .lineSpacing(LibraryMetrics.titleLeading)
            .foregroundStyle(quiet ? MuseColor.ink55 : MuseColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Their words, with air between the lines.
struct LeafWords: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MuseFont.lora(LibraryMetrics.words))
            .lineSpacing(LibraryMetrics.wordsLeading)
            .foregroundStyle(MuseColor.ink)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A hairline across whatever it is given.
struct LeafHairline: View {
    var body: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: LibraryMetrics.hair)
            .accessibilityHidden(true)
    }
}

/// The page's last line: a hairline, what is true on the left, the keys on the right.
struct LeafFoot: View {
    let left: String
    let keys: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(1)
            Spacer(minLength: MuseSpacing.md)
            Text(keys)
                .font(MuseFont.mono(.caption2))
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.top, MuseSpacing.md)
        .overlay(alignment: .top) { LeafHairline() }
    }
}

// MARK: - The player

/// The player as one thin line on the paper: a play glyph, the recording's own shape as
/// dots (the played part in moss), its length. No capsule.
struct LeafPlayerLine: View {
    let player: MacPlayer
    let length: String

    var body: some View {
        HStack(spacing: MuseSpacing.row) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(MuseFont.symbol(LibraryMetrics.play))
                    .foregroundStyle(MuseColor.moss)
                    .frame(width: LibraryMetrics.playBox, height: LibraryMetrics.playBox, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle())
            .disabled(!player.canPlay)
            .help(player.isPlaying ? "pause" : "listen")
            .accessibilityLabel(player.isPlaying ? "pause" : "listen")
            LeafWave(peaks: player.peaks, progress: player.progress)
                .frame(height: LibraryMetrics.wave)
            LeafMono(length)
                .monospacedDigit()
        }
    }
}

/// The recording as columns of dots, taller where the voice was. An even low line until
/// the audio has been read.
private struct LeafWave: View {
    let peaks: [Double]
    let progress: Double

    var body: some View {
        let peaks = peaks
        let progress = progress
        Canvas { context, size in
            let dot = DuoMetrics.waveDot
            let pitch = dot + DuoMetrics.waveGap
            let columns = max(Int((size.width + DuoMetrics.waveGap) / pitch), 1)
            let rows = max(Int((size.height + DuoMetrics.waveGap) / pitch), 1)
            let inset = (size.width - (CGFloat(columns) * pitch - DuoMetrics.waveGap)) / 2
            let played = GraphicsContext.Shading.color(MuseColor.moss600)
            let rest = GraphicsContext.Shading.color(MuseColor.ink.opacity(LibraryMetrics.waveRest))
            for column in 0..<columns {
                let at = Double(column) / Double(columns)
                let level = peaks.isEmpty ? 0 : peaks[min(peaks.count - 1, Int(at * Double(peaks.count)))]
                let lit = max(1, min(rows, Int((level * Double(rows)).rounded())))
                let top = (size.height - (CGFloat(lit) * pitch - DuoMetrics.waveGap)) / 2
                for row in 0..<lit {
                    let rect = CGRect(x: inset + CGFloat(column) * pitch, y: top + CGFloat(row) * pitch, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: at < progress ? played : rest)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - The actions

/// The glass capsule of actions, top right of a page. Its glyphs rest quiet and come up
/// under the pointer.
struct LeafActions<Content: View>: View {
    let content: Content

    @State private var isHovered = false

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        HStack(spacing: MuseSpacing.xxs / 2) {
            content
        }
        .opacity(isHovered ? 1 : LibraryMetrics.actionsRest)
        .padding(.horizontal, MuseSpacing.xxs)
        .frame(height: LibraryMetrics.capsule)
        .duoControlGlass()
        .onHover { isHovered = $0 }
        .museAnimation(MuseMotion.snappy, value: isHovered)
        .padding(DuoMetrics.margin)
    }
}

/// One action in the capsule. `label` is its tooltip and what VoiceOver says, lowercase.
struct LeafAction: View {
    let symbol: String
    let label: String
    var tint: Color = MuseColor.ink70
    let run: () -> Void

    init(_ symbol: String, _ label: String, tint: Color = MuseColor.ink70, run: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.tint = tint
        self.run = run
    }

    var body: some View {
        Button(action: run) {
            Image(systemName: symbol)
                .font(MuseFont.symbol(LibraryMetrics.actionSymbol))
                .foregroundStyle(tint)
                .frame(width: LibraryMetrics.action.width, height: LibraryMetrics.action.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
