#if DEBUG
import AppKit
import SwiftUI

/// The menu bar panel in the duo language, hanging under a slice of menu bar. Everything
/// today's panel has, in the same order: the ring (now the pill, with a small glyph beside
/// it opening disconnect, rename and forget), the four rows, the commands, "talk to", two recents and
/// the foot. Warm paper on a quiet dune; type and space do the dividing.
struct SmallPanelShot: View {
    var body: some View {
        VStack(spacing: 0) {
            SmallMenuBar(height: SmallMetrics.slimBar) {
                SmallBarGlyph("wifi")
                SmallBarGlyph("battery.75percent")
                Image(nsImage: DotRingIcon.small(.linen, size: SmallMetrics.barIcon))
                    .padding(.horizontal, MuseSpacing.xs)
                    .frame(height: SmallMetrics.slimBar - MuseSpacing.xxs)
                    .background(SmallColor.pale.opacity(0.16), in: RoundedRectangle(cornerRadius: SmallMetrics.keyCapRadius, style: .continuous))
                SmallBarGlyph("magnifyingglass")
            }
            SmallPanel()
                .padding(.top, MuseSpacing.xs)
                .padding(.horizontal, SmallMetrics.panelDesk)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background { SmallDesk() }
        .preferredColorScheme(.light)
    }
}

/// The panel itself, at its real width.
struct SmallPanel: View {
    var ring: PocketRingState = PocketFixtures.ring

    private static let shape = RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: MuseSpacing.xxs) {
                DuoRingPill(state: ring)
                    .contextMenu { ringMenu }
                // The same menu, in sight: nothing about the ring is right click only.
                Menu {
                    ringMenu
                } label: {
                    Image(systemName: "ellipsis")
                        .museSymbol(SmallMetrics.more, weight: .semibold)
                        .foregroundStyle(MuseColor.ink70)
                        .frame(width: SmallMetrics.moreBox, height: DuoMetrics.bar)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("rename, disconnect, forget")
                .accessibilityLabel("ring options")
            }
            .padding(.trailing, -MuseSpacing.xs)
            .padding(.bottom, MuseSpacing.sm)
            rows
            SmallCommands()
                .padding(.top, MuseSpacing.xxs)
            SmallTalkTo()
                .padding(.top, MuseSpacing.md)
            recent
                .padding(.top, MuseSpacing.lg)
            foot
                .padding(.top, MuseSpacing.sm)
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.top, MuseSpacing.sm)
        .padding(.bottom, MuseSpacing.xs)
        .frame(width: SmallMetrics.panelWidth)
        .background {
            PocketGround(strength: SmallMetrics.panelDune)
                .clipShape(Self.shape)
        }
        .overlay { Self.shape.strokeBorder(DuoColor.edge, lineWidth: 1) }
        .compositingGroup()
        .museElevation(.e2)
    }

    /// What the ring can be told, for the visible glyph and for a right click.
    @ViewBuilder
    private var ringMenu: some View {
        Button("bring in everything") {}
        Button("rename") {}
        Button("disconnect") {}
        Button("forget this ring") {}
    }

    // MARK: - Rows

    private var rows: some View {
        VStack(spacing: 0) {
            row("type into apps") { SmallSwitch(isOn: true, label: "type into apps") }
            row("speech") { choice("parakeet ultra", symbol: "chevron.up.chevron.down", label: "speech, parakeet ultra") }
            row("your words") { choice("museo, Claude, +3", symbol: "chevron.right", label: "your words") }
            row("voice commands") { SmallSwitch(isOn: true, label: "voice commands") }
        }
    }

    private func row(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(title)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: SmallMetrics.rowHeight)
    }

    /// A row's current choice as plain words and one small glyph: no box round it.
    private func choice(_ value: String, symbol: String, label: String) -> some View {
        Button {} label: {
            HStack(spacing: MuseSpacing.xxs + MuseSpacing.xxs / 2) {
                Text(value)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink70)
                Image(systemName: symbol)
                    .museSymbol(SmallMetrics.chevron, weight: .semibold)
                    .foregroundStyle(MuseColor.ink55)
            }
            .frame(height: SmallMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Recent

    private var recent: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            MuseEyebrow("recent")
            // Newest first.
            thought(PocketFixtures.window, went: "into your note", words: PocketFixtures.streamingWords)
            thought(PocketFixtures.dentist, went: "sent to claude")
        }
    }

    private func thought(_ thought: PocketThought, went: String?, words: String? = nil) -> some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
                Text([thought.time, "streamed", went].compactMap { $0 }.joined(separator: " · "))
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                Text(words ?? thought.title)
                    .font(MuseFont.lora(SmallMetrics.recentWords))
                    .foregroundStyle(MuseColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Foot

    private var foot: some View {
        VStack(spacing: 0) {
            MuseHairline()
            HStack(spacing: MuseSpacing.sm) {
                footWord("open museo")
                Text("·")
                    .font(MuseType.metaMedium)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
                footWord("new note")
                Spacer(minLength: 0)
                Button {} label: {
                    Image(systemName: "power")
                        .museSymbol(SmallMetrics.power, weight: .medium)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(width: SmallMetrics.rowHeight, height: SmallMetrics.rowHeight, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("quit museo")
            }
            .frame(height: SmallMetrics.rowHeight + MuseSpacing.xs)
        }
    }

    private func footWord(_ title: String) -> some View {
        Button {} label: {
            Text(title)
                .font(MuseType.metaMedium)
                .foregroundStyle(MuseColor.moss600)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice commands

/// The commands two to a row: what it presses in a key cap, what you say in Lora, a dot
/// for each other way to say it. Then the hint and "add".
private struct SmallCommands: View {
    private nonisolated struct Command: Identifiable, Sendable {
        let keys: String
        let say: String
        let others: Int
        var id: String { say }
    }

    private static let commands: [Command] = [
        Command(keys: "↩", say: "send", others: 3),
        Command(keys: "⇧↩", say: "new line", others: 1),
        Command(keys: "⌃⇥", say: "switch tab", others: 1),
        Command(keys: "⌘⇥", say: "switch app", others: 1),
        Command(keys: "⌘Z", say: "undo", others: 1),
        Command(keys: "⌘T", say: "new tab", others: 0),
        Command(keys: "⌘W", say: "close tab", others: 0),
        Command(keys: "app", say: "open claude", others: 1),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 0, alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: 0
            ) {
                ForEach(Self.commands) { command in
                    cell(command)
                }
            }
            SmallHintLine(hint: "end any hold with “send” to send it", addLabel: "add a voice command")
        }
    }

    private func cell(_ command: Command) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            SmallKeyCap(command.keys)
            HStack(alignment: .top, spacing: MuseSpacing.xxs) {
                Text("“\(command.say)”")
                    .font(MuseFont.lora(SmallMetrics.phrase))
                    .foregroundStyle(MuseColor.ink)
                    .lineLimit(1)
                    .fixedSize()
                HStack(spacing: SmallMetrics.alternateGap) {
                    ForEach(0..<command.others, id: \.self) { _ in
                        Circle()
                            .fill(MuseColor.moss300)
                            .frame(width: SmallMetrics.alternateDot, height: SmallMetrics.alternateDot)
                    }
                }
                .padding(.top, MuseSpacing.xxs)
                .accessibilityHidden(true)
            }
        }
        .frame(height: SmallMetrics.commandRow)
        .accessibilityElement(children: .combine)
        .accessibilityHint(command.others > 0 ? "\(command.others) more ways to say it" : "")
    }
}

/// What a command presses: a small paper key with a soft lower edge.
struct SmallKeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    private static let shape = RoundedRectangle(cornerRadius: SmallMetrics.keyCapRadius, style: .continuous)

    var body: some View {
        Text(text)
            .font(MuseType.captionMedium)
            .foregroundStyle(MuseColor.ink70)
            .lineLimit(1)
            .frame(width: SmallMetrics.keyCapWidth, height: SmallMetrics.keyCapHeight)
            .background(DuoColor.paper.opacity(0.9), in: Self.shape)
            .overlay { Self.shape.strokeBorder(MuseColor.hairline, lineWidth: 1) }
    }
}

/// The quiet line under a section: what to say, and "add" at its end.
private struct SmallHintLine: View {
    let hint: String
    let addLabel: String

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(hint)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: 0)
            Button {} label: {
                Text("add")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(addLabel)
        }
        .frame(height: SmallMetrics.keyCapHeight + MuseSpacing.xxs)
    }
}

// MARK: - Talk to

/// The apps a hold can start a chat in: the app's icon, what you say, what it does.
private struct SmallTalkTo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
            MuseEyebrow("talk to")
                .padding(.bottom, MuseSpacing.xxs)
            agent("claude", symbol: "sparkle")
            agent("cursor", symbol: "cube")
            SmallHintLine(hint: "say “hey claude…” and your prompt.", addLabel: "talk to another app")
        }
    }

    private func agent(_ name: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: MuseSpacing.xs) {
            icon(name, symbol: symbol)
                .frame(width: SmallMetrics.keyCapWidth, alignment: .center)
            HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                Text("“hey \(name)”")
                    .font(MuseFont.lora(SmallMetrics.phrase))
                    .foregroundStyle(MuseColor.ink)
                Text("new chat")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .frame(height: SmallMetrics.commandRow)
        .accessibilityElement(children: .combine)
    }

    /// The app's own icon when it is on this mac, else a quiet tile.
    @ViewBuilder
    private func icon(_ name: String, symbol: String) -> some View {
        if let url = AgentHandoff.appURL(name) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: SmallMetrics.appIcon + MuseSpacing.xxs, height: SmallMetrics.appIcon + MuseSpacing.xxs)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbol)
                .museSymbol(SmallMetrics.chevron + MuseSpacing.xxs / 2, weight: .medium)
                .foregroundStyle(MuseColor.ground)
                .frame(width: SmallMetrics.appIcon, height: SmallMetrics.appIcon)
                .background(MuseColor.ink, in: RoundedRectangle(cornerRadius: SmallMetrics.appIconRadius, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
#endif
