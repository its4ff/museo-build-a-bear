import SwiftUI

/// "your words.": what the library adds up to, today, this week or all time. One big number,
/// three small ones, how muses came in (white for streamed, amber from the ring), the words
/// said most, and the commands run most. It takes the muse pane's place while it's open.
struct StatsPane: View {
    @State private var library = MacLibrary.shared
    @State private var tally = CommandTally.shared
    @State private var span = LibraryStats.Span.all

    var body: some View {
        ScrollView {
            page
        }
        .scrollIndicators(.hidden)
        .background { MuseBackground() }
    }

    #if DEBUG
    /// The page without its scroll view, for `ScreenSheet` (scroll views don't draw offscreen).
    func still(_ span: LibraryStats.Span = .all) -> some View {
        StatsPage(stats: LibraryStats(library.muses, span: span), commands: tally.top(span), span: .constant(span))
            .frame(maxHeight: .infinity, alignment: .top)
            .background { MuseBackground() }
    }
    #endif

    private var page: some View {
        StatsPage(stats: LibraryStats(library.muses, span: span), commands: tally.top(span), span: $span)
    }
}

/// The page's content, given its numbers.
private struct StatsPage: View {
    let stats: LibraryStats
    let commands: [LibraryStats.Count]
    @Binding var span: LibraryStats.Span

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.section) {
            HStack(alignment: .center) {
                Text("your words.")
                    .font(MuseType.title)
                    .tracking(MuseType.titleTracking)
                    .foregroundStyle(MuseColor.ink)
                Spacer(minLength: MuseSpacing.md)
                spans
            }
            hero
            figures
            split
            Rectangle().fill(MuseColor.hairline).frame(height: 1)
            HStack(alignment: .top, spacing: MuseSpacing.sectionLabel) {
                list("you say a lot", stats.topWords, serif: true, empty: "none yet.")
                list("commands", commands, serif: false, empty: "none yet. they're counted from here on.")
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sectionLabel)
        .padding(.top, 72)
        .padding(.bottom, MuseSpacing.sectionLabel)
        .frame(maxWidth: .infinity)
        .museAnimation(MuseMotion.snappy, value: span)
    }

    // MARK: - Pieces

    /// today · this week · all time.
    private var spans: some View {
        HStack(spacing: 2) {
            ForEach(LibraryStats.Span.allCases, id: \.self) { each in
                let on = each == span
                Button {
                    span = each
                } label: {
                    Text(each.title)
                        .font(MuseType.captionMedium)
                        .foregroundStyle(on ? MuseColor.ground : MuseColor.ink70)
                        .padding(.horizontal, MuseSpacing.sm)
                        .frame(height: 24)
                        .background(on ? AnyShapeStyle(MuseColor.primaryGradient) : AnyShapeStyle(.clear), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
    }

    /// The words, big, and what they add up to.
    private var hero: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            Text(stats.words.formatted())
                .font(MuseFont.lora(68))
                .tracking(-1.4)
                .foregroundStyle(MuseColor.ink)
                .contentTransition(.numericText())
            Text(heroLine)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
        }
        .accessibilityElement(children: .combine)
    }

    private var heroLine: String {
        if stats.words == 0 { return span == .all ? "words said · nothing yet" : "words said · nothing yet \(span.title)" }
        return [stats.words == 1 ? "word said" : "words said", stats.likeness].compactMap { $0 }.joined(separator: " · ")
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: MuseSpacing.md) {
            figure(stats.talking.museStatTime, "talking")
            figure(stats.muses.formatted(), stats.muses == 1 ? "muse" : "muses")
            figure(stats.savedOverTyping.museStatTime, "saved over typing")
                .help("about: typing the same words at \(Int(LibraryStats.typingWordsPerMinute)) a minute, less the time it took to say them, muse by muse")
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(MuseFont.satoshi(20, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(MuseColor.moss)
                .contentTransition(.numericText())
            Text(label)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Streamed in white, from the ring in amber, by how many muses.
    @ViewBuilder
    private var split: some View {
        if stats.muses > 0 {
            let streamed = Int((stats.streamedShare * 100).rounded())
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                GeometryReader { bar in
                    HStack(spacing: 0) {
                        Rectangle().fill(MuseColor.composer).frame(width: bar.size.width * stats.streamedShare)
                        Rectangle().fill(MuseColor.ochre)
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
                .accessibilityHidden(true)
                HStack(spacing: MuseSpacing.md) {
                    legend("streamed \(streamed)%", MuseColor.composer)
                    legend("from the ring \(100 - streamed)%", MuseColor.ochre)
                }
            }
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(MuseColor.ink.opacity(0.2), lineWidth: 0.75))
            Text(title)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink70)
        }
    }

    /// A short list with its counts: their words in Lora, commands in Satoshi.
    private func list(_ title: String, _ counts: [LibraryStats.Count], serif: Bool, empty: String) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            MuseEyebrow(title)
            if counts.isEmpty {
                Text(empty)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                    ForEach(counts, id: \.name) { each in
                        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                            Text(each.name)
                                .font(serif ? MuseFont.lora(16) : MuseType.metaMedium)
                                .foregroundStyle(MuseColor.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(each.count.formatted())
                                .font(MuseType.captionMedium)
                                .monospacedDigit()
                                .foregroundStyle(MuseColor.moss)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The chart button beside library settings: opens your stats in place of the muse.
struct StatsButton: View {
    @State private var library = MacLibrary.shared
    @State private var isHovered = false

    var body: some View {
        let on = library.showsStats
        Button {
            library.showsStats.toggle()
        } label: {
            Image(systemName: "chart.bar")
                .font(MuseFont.symbol(12))
                .foregroundStyle(on ? MuseColor.moss : MuseColor.ink55)
                .frame(width: 28, height: 28)
                .background(on || isHovered ? MuseColor.moss.opacity(0.1) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(on ? "back to the muse" : "your stats")
        .accessibilityLabel("your stats")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
