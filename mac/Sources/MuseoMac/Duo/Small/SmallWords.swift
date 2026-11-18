#if DEBUG
import SwiftUI

/// "your words." in the duo language: the span as plain words, one enormous numeral, three
/// quiet figures, how the thoughts came in (white for streamed, amber from the ring), and
/// the two lists as typeset rows. On the dune, with no corner: this is a page to look at.
struct SmallWords: View {
    nonisolated enum Span: String, CaseIterable, Sendable {
        case today, week = "this week", all = "all time"
    }

    private nonisolated struct Count: Identifiable, Sendable {
        let name: String
        let count: Int
        var id: String { name }
    }

    var span: Span = .all

    private static let streamedShare = 0.83
    private static let said = [
        Count(name: "window", count: 41), Count(name: "thread", count: 28), Count(name: "slow", count: 22),
        Count(name: "shop", count: 19), Count(name: "thursday", count: 14),
    ]
    private static let commands = [
        Count(name: "send", count: 142), Count(name: "hey claude", count: 64), Count(name: "scratch that", count: 38),
        Count(name: "switch tab", count: 21), Count(name: "new line", count: 9),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("your words.")
                    .font(MuseType.title)
                    .tracking(MuseType.titleTracking)
                    .foregroundStyle(MuseColor.ink)
                Spacer(minLength: MuseSpacing.md)
                spans
            }
            hero
                .padding(.top, MuseSpacing.xs)
            figures
                .padding(.top, MuseSpacing.section + MuseSpacing.xxs)
            split
                .padding(.top, MuseSpacing.section)
            HStack(alignment: .top, spacing: MuseSpacing.sectionLabel + MuseSpacing.md) {
                list("you say a lot", Self.said, serif: true)
                list("commands", Self.commands, serif: false)
            }
            .padding(.top, MuseSpacing.sectionLabel)
        }
        .frame(width: SmallMetrics.wordsColumn, alignment: .leading)
        .padding(.top, SmallMetrics.wordsTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topLeading) { DuoWindowChrome() }
        .background { PocketGround() }
        .preferredColorScheme(.light)
    }

    // MARK: - Pieces

    /// today · this week · all time, as words: the current one in ink.
    private var spans: some View {
        HStack(spacing: SmallMetrics.spanGap) {
            ForEach(Span.allCases, id: \.self) { each in
                let on = each == span
                Button {} label: {
                    Text(each.rawValue)
                        .font(on ? MuseType.label : MuseType.body)
                        .foregroundStyle(on ? MuseColor.ink : MuseColor.ink55.opacity(0.75))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("7,181")
                .font(MuseFont.lora(SmallMetrics.numeral))
                .tracking(SmallMetrics.numeralTracking)
                .foregroundStyle(MuseColor.ink)
                .padding(.vertical, SmallMetrics.numeralTrim)
                .padding(.leading, SmallMetrics.numeralTracking)
            Text("words said · about a long essay")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink55)
                .padding(.top, MuseSpacing.lg)
        }
        .accessibilityElement(children: .combine)
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: MuseSpacing.md) {
            figure("48m", "talking")
            figure("212", "thoughts")
            figure("2h 12m", "saved over typing")
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
            Text(value)
                .font(MuseFont.satoshi(SmallMetrics.figure, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(MuseColor.moss)
            Text(label)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Streamed in white, from the ring in amber with the pill's grain.
    private var split: some View {
        let streamed = Int((Self.streamedShare * 100).rounded())
        return VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            GeometryReader { bar in
                HStack(spacing: 0) {
                    // Clean white, no grain: on linen any speckle turns it grey.
                    Rectangle()
                        .fill(MuseColor.composer)
                        .frame(width: bar.size.width * Self.streamedShare)
                    Rectangle()
                        .fill(LinearGradient(colors: [SmallColor.amberFoot, SmallColor.amberHead], startPoint: .leading, endPoint: .trailing))
                        .overlay {
                            PocketGrain.fineDark
                                .resizable(resizingMode: .tile)
                                .interpolation(.none)
                                .opacity(0.28)
                                .blendMode(.multiply)
                        }
                        .overlay {
                            PocketGrain.fineLight
                                .resizable(resizingMode: .tile)
                                .interpolation(.none)
                                .opacity(0.6)
                                .blendMode(.screen)
                        }
                }
            }
            .frame(height: SmallMetrics.barHeight)
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(MuseColor.hairline, lineWidth: 1) }
            .museElevation(.e1)
            .accessibilityHidden(true)
            HStack(spacing: MuseSpacing.lg) {
                legend("streamed \(streamed)%", MuseColor.composer)
                legend("from the ring \(100 - streamed)%", SmallColor.amberHead)
            }
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: MuseSpacing.xxs + MuseSpacing.xxs / 2) {
            Circle()
                .fill(color)
                .frame(width: SmallMetrics.legendDot, height: SmallMetrics.legendDot)
                .overlay { Circle().strokeBorder(MuseColor.ink.opacity(0.18), lineWidth: 1) }
            Text(title)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink70)
        }
    }

    /// A short list with its counts: their words in Lora, commands in Satoshi, a hairline
    /// under each row.
    private func list(_ title: String, _ counts: [Count], serif: Bool) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            MuseEyebrow(title)
            VStack(spacing: 0) {
                ForEach(counts) { each in
                    HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                        Text(each.name)
                            .font(serif ? MuseFont.lora(SmallMetrics.listWord) : MuseType.label)
                            .foregroundStyle(MuseColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(each.count.formatted())
                            .font(MuseType.metaMedium)
                            .monospacedDigit()
                            .foregroundStyle(MuseColor.moss600)
                    }
                    .frame(height: SmallMetrics.listRow)
                    .overlay(alignment: .bottom) {
                        if each.id != counts.last?.id {
                            Rectangle().fill(MuseColor.divider).frame(height: 1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
