#if DEBUG
import Foundation
import SwiftUI

/// One thought, on the dune with no card around it: a mono line, the title, their words,
/// the short notes for a long one, what came back as an aside, and where it is filed.
/// Listening and "send to…" float at the bottom as glass.
struct PocketThoughtPage: View {
    let thought: PocketThought

    @Environment(\.dismiss) private var dismiss
    @State private var isFiled = true
    @State private var isPlaying = false
    @State private var showsSend = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    PocketGlassCircle("chevron.left", label: "back") { dismiss() }
                    heading
                }
                if let said {
                    words(said)
                }
                if thought.hasNotes, !thought.notes.isEmpty {
                    notes
                }
                if let reply = thought.reply {
                    aside(reply)
                }
                if isFiled, let line = thought.filedLine {
                    filed(line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, PocketChrome.top)
            .padding(.bottom, MuseSpacing.sectionLabel)
            .museAnimation(MuseMotion.smooth, value: isFiled)
        }
        .scrollIndicators(.hidden)
        .pocketChromeFade()
        .safeAreaBar(edge: .bottom) { bottomBar }
        .background { PocketGround() }
        .pocketPushedPage()
        .sheet(isPresented: $showsSend) {
            PocketSendSheet(thought: thought)
                .pocketFittedSheet()
        }
    }

    // MARK: - Words

    private var heading: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            Text(thought.meta)
                .font(MuseType.code)
                .foregroundStyle(MuseColor.ink55)
            Text(thought.title)
                .font(MuseType.display)
                .tracking(MuseType.displayTracking)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// What they said after the title. The title is the thought's opening words, so the
    /// body picks up where it stops; when nothing follows, the title is the whole thought.
    private var said: String? {
        let body = thought.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.lowercased().hasPrefix(thought.title.lowercased()) else {
            return body.isEmpty ? nil : body
        }
        let rest = body.dropFirst(thought.title.count)
            .drop { $0.isWhitespace || $0.isPunctuation }
        return rest.isEmpty ? nil : String(rest)
    }

    private func words(_ said: String) -> some View {
        Text(said)
            .font(MuseType.headline)
            .lineSpacing(PocketThoughtMetrics.wordsLeading)
            .foregroundStyle(MuseColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The short notes, set in from the words and a step quieter.
    private var notes: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            ForEach(thought.notes, id: \.self) { note in
                HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                    Circle()
                        .fill(MuseColor.ink55)
                        .frame(width: PocketThoughtMetrics.bullet, height: PocketThoughtMetrics.bullet)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] + PocketThoughtMetrics.bulletLift }
                        .accessibilityHidden(true)
                    Text(note)
                        .font(MuseType.serif)
                        .lineSpacing(MuseType.serifLineSpacing)
                        .foregroundStyle(MuseColor.ink70)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, MuseSpacing.xs)
    }

    /// What a place sent back: shown, never acted on. Not their words, so the sans.
    private func aside(_ reply: PocketReply) -> some View {
        HStack(alignment: .top, spacing: MuseSpacing.row) {
            Capsule()
                .fill(MuseColor.moss600.opacity(PocketThoughtMetrics.ruleOpacity))
                .frame(width: PocketThoughtMetrics.rule)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                Text(reply.lead)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                Text(reply.text)
                    .font(MuseType.body)
                    .lineSpacing(MuseType.bodyLineSpacing)
                    .foregroundStyle(MuseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, MuseSpacing.xxs)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, MuseSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    /// Where it is filed and why. Tap to take it out.
    private func filed(_ line: String) -> some View {
        Button {
            MuseHaptics.play(.soft)
            isFiled = false
        } label: {
            HStack(spacing: MuseSpacing.xs) {
                Text(line)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                Image(systemName: "xmark")
                    .museSymbol(PocketThoughtMetrics.remove, weight: .medium)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: MuseTopChrome.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .accessibilityLabel(line)
        .accessibilityHint("take it out")
        .transition(.opacity)
    }

    // MARK: - Bottom glass

    private var bottomBar: some View {
        GlassEffectContainer(spacing: MuseSpacing.sm) {
            HStack(spacing: MuseSpacing.sm) {
                listen
                send
            }
        }
        .padding(.horizontal, MuseSpacing.page)
        .padding(.bottom, MuseSpacing.xs)
    }

    private var listen: some View {
        Button {
            MuseHaptics.play(.soft)
            isPlaying.toggle()
        } label: {
            HStack(spacing: MuseSpacing.sm) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .museSymbol(PocketGlassMetrics.symbol, weight: .medium)
                    .foregroundStyle(MuseColor.moss)
                    .frame(width: MuseSpacing.xl)
                PocketDottedWave(seed: thought.id)
                    .frame(height: PocketThoughtMetrics.wave)
                Text(thought.length)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
            }
            .padding(.horizontal, MuseSpacing.card)
            .frame(maxWidth: .infinity)
            .frame(height: PocketRingPillMetrics.height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pocketControlGlass()
        .accessibilityLabel(isPlaying ? "pause" : "listen")
        .accessibilityValue(thought.length)
    }

    private var send: some View {
        Button {
            MuseHaptics.play(.soft)
            showsSend = true
        } label: {
            Text("send to…")
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink70)
                .padding(.horizontal, MuseSpacing.card)
                .frame(height: PocketRingPillMetrics.height)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pocketControlGlass()
    }
}

// MARK: - The dotted waveform

/// The recording as columns of dots, taller where the voice was. Made up from the
/// thought's id, so each thought keeps its own shape.
private struct PocketDottedWave: View {
    let seed: String

    var body: some View {
        let ink = MuseColor.moss600
        let phase = Double(seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 97)
        Canvas { context, size in
            let dot = PocketThoughtMetrics.waveDot
            let pitch = dot + PocketThoughtMetrics.waveGap
            let columns = max(Int((size.width + PocketThoughtMetrics.waveGap) / pitch), 1)
            let rows = max(Int((size.height + PocketThoughtMetrics.waveGap) / pitch), 1)
            let inset = (size.width - (CGFloat(columns) * pitch - PocketThoughtMetrics.waveGap)) / 2
            for column in 0..<columns {
                let t = Double(column) + phase
                let swell = abs(sin(t * 0.23)) * abs(cos(t * 0.071 + 1.3))
                let jitter = abs(sin(t * 1.7))
                let level = 0.12 + 0.88 * (0.65 * swell + 0.35 * jitter)
                let lit = max(1, min(rows, Int((level * Double(rows)).rounded())))
                let top = (size.height - (CGFloat(lit) * pitch - PocketThoughtMetrics.waveGap)) / 2
                for row in 0..<lit {
                    let rect = CGRect(
                        x: inset + CGFloat(column) * pitch,
                        y: top + CGFloat(row) * pitch,
                        width: dot,
                        height: dot
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(ink))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Metrics

private nonisolated enum PocketThoughtMetrics {
    /// Their words read with more air than the house serif spacing: 19pt Lora at about 1.4.
    static let wordsLeading: CGFloat = 7
    /// A note's bullet, and how far it sits above the baseline.
    static let bullet: CGFloat = 4
    static let bulletLift: CGFloat = 5
    /// The aside's rule.
    static let rule: CGFloat = 2
    static let ruleOpacity: Double = 0.45
    /// The small x on the filed line.
    static let remove: CGFloat = 10
    /// The waveform: its height, one dot, the gap between dots.
    static let wave: CGFloat = 25
    static let waveDot: CGFloat = 2.5
    static let waveGap: CGFloat = 2.5
}

#Preview {
    NavigationStack {
        PocketThoughtPage(thought: PocketFixtures.dentist)
    }
}
#endif
