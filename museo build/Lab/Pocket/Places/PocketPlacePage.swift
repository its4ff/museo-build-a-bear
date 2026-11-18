#if DEBUG
import SwiftUI

/// One place's page: its name, its sentence (edited where it sits), the one "send to" row
/// that is the consent, the last few sends when it sends, and the thoughts in it as the
/// shared grid. A place is a view of the library, never a move.
struct PocketPlacePage: View {
    let place: PocketPlace

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sentence: String
    @State private var destination: PocketDestination
    @State private var sends: [PocketSend]
    @State private var opened: PocketThought?

    init(place: PocketPlace) {
        self.place = place
        _sentence = State(initialValue: place.sentence)
        _destination = State(initialValue: place.sendsOn ? place.destination : (place.destination == .fm ? .fm : .none))
        _sends = State(initialValue: Array(place.recentSends.prefix(PocketPlacePageMetrics.sendsShown)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    PocketGlassCircle("chevron.left", label: "back") { dismiss() }
                    head
                }
                .padding(.horizontal, PocketGrid.gutter)
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    sendTo
                    if sendsBySelf, !sends.isEmpty {
                        recent
                    }
                }
                .padding(.horizontal, PocketGrid.gutter)
                grid
            }
            .padding(.top, PocketChrome.top)
            .padding(.bottom, MuseSpacing.sectionLabel)
            .museAnimation(MuseMotion.smooth, value: destination)
        }
        .scrollIndicators(.hidden)
        .pocketChromeFade()
        .scrollDismissesKeyboard(.interactively)
        .background { PocketGround() }
        .pocketPushedPage()
        .navigationDestination(item: $opened) { thought in
            PocketThoughtPage(thought: thought)
        }
    }

    private static let prompt = "say what belongs here"

    private var sendsBySelf: Bool { destination != .none && destination != .fm }

    // MARK: The name and its sentence

    private var head: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(place.name)
                .font(MuseType.display)
                .tracking(MuseType.displayTracking)
                .foregroundStyle(MuseColor.ink)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                // The hidden words size the field, so the pencil sits right after them.
                Text(sentence.isEmpty ? Self.prompt : sentence)
                    .font(MuseType.headline)
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay(alignment: .leading) {
                        TextField(Self.prompt, text: $sentence, axis: .vertical)
                            .font(MuseType.headline)
                            .foregroundStyle(MuseColor.ink70)
                            .tint(MuseColor.moss)
                            .textInputAutocapitalization(.never)
                            .accessibilityLabel("its sentence")
                    }
                Image(systemName: "pencil")
                    .museSymbol(PocketPlacePageMetrics.pencil, weight: .regular)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Send to (the consent)

    private var sendTo: some View {
        Menu {
            Picker("send to", selection: $destination) {
                ForEach(choices, id: \.self) { choice in
                    Text(place.sendWords(choice)).tag(choice)
                }
            }
        } label: {
            HStack(spacing: MuseSpacing.sm) {
                Text("send to")
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: MuseSpacing.xs)
                Text(place.sendWords(destination))
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .museSymbol(PocketPlacePageMetrics.chevron, weight: .medium)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MuseSpacing.card)
            .frame(maxWidth: .infinity, minHeight: PocketPlacePageMetrics.rowHeight)
            .contentShape(Rectangle())
            .pocketTileGlass()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("send to, \(place.sendWords(destination))")
    }

    /// museo.fm only ever asks; every other place picks one way out, or none.
    private var choices: [PocketDestination] {
        place.destination == .fm ? [.fm] : [.none, .files, .webAddress, .agent]
    }

    // MARK: The last few sends

    private var recent: some View {
        VStack(spacing: 0) {
            ForEach(sends) { send in
                PocketSendLine(send: send, lead: "for \(place.name), ") { sendAgain(send) }
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .transition(.opacity)
    }

    private func sendAgain(_ send: PocketSend) {
        guard let index = sends.firstIndex(of: send) else { return }
        MuseHaptics.play(.soft)
        sends[index] = PocketSend(id: send.id, title: send.title, state: .trying)
    }

    // MARK: The thoughts in it

    private var grid: some View {
        LazyVGrid(
            columns: PocketGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize),
            spacing: PocketGrid.spacing
        ) {
            ForEach(thoughts) { thought in
                Button {
                    MuseHaptics.play(.soft)
                    opened = thought
                } label: {
                    PocketTile(
                        title: thought.title,
                        foot: thought.reply?.lead ?? thought.why,
                        footDot: MuseColor.moss600,
                        ink: thought.ink
                    )
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.98))
            }
        }
        .padding(.horizontal, PocketGrid.gutter)
    }

    /// The fixtures file one thought under claude and name two more only as sends. Those
    /// two join the grid here so the page reads as a place with things in it.
    private var thoughts: [PocketThought] {
        let filed = PocketFixtures.thoughts(in: place)
        let known = Set(filed.map(\.title))
        let why = filed.first?.why ?? "you said \u{201C}\(place.name)\u{201D}"
        let sent = place.recentSends
            .filter { !known.contains($0.title) }
            .map { send in
                PocketThought(
                    id: "sent-\(send.id)", title: send.title, body: send.title,
                    day: "yesterday", time: "4:20p", origin: .streamed, length: "0:09",
                    place: place.name, why: why
                )
            }
        return filed + sent
    }
}

// MARK: - Words for where it sends

extension PocketPlace {
    /// The "send to" row, in words: what happens to what this place gathers.
    func sendWords(_ destination: PocketDestination) -> String {
        switch destination {
        case .none: "nowhere, just kept together"
        case .files: "files · museo folder"
        case .webAddress: "a web address"
        case .agent: "an agent · \(self.destination == .agent ? name : "claude")"
        case .fm: "ask me each time"
        }
    }
}

// MARK: - One send

/// What was sent, and how it went: a dot and a few words. A failed one is the page's one
/// clay mark, and its words are the way to try again.
private struct PocketSendLine: View {
    let send: PocketSend
    /// The spoken name the place already says: dropped, so the line starts with the thought.
    let lead: String
    let again: () -> Void

    var body: some View {
        if send.state == .failed {
            // The whole line is the way to try again.
            Button(action: again) {
                line(state("send again", color: MuseColor.clay, words: MuseColor.clay))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title). didn't send. send again")
        } else {
            line(state(
                send.line,
                color: send.state == .delivered ? MuseColor.moss600 : MuseColor.ochre,
                words: MuseColor.ink55
            ))
            .accessibilityElement(children: .combine)
        }
    }

    private var title: String {
        send.title.hasPrefix(lead) ? String(send.title.dropFirst(lead.count)) : send.title
    }

    /// The thought whole on its own line, how it went under it: nothing is cut short.
    private func line(_ state: some View) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(title)
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink70)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            state
        }
        .frame(maxWidth: .infinity, minHeight: PocketPlacePageMetrics.sendHeight, alignment: .leading)
    }

    private func state(_ line: String, color: Color, words: Color) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: PocketGrid.footDot, height: PocketGrid.footDot)
                .accessibilityHidden(true)
            Text(line)
                .font(MuseType.meta)
                .foregroundStyle(words)
        }
        .fixedSize()
    }
}

/// Sizes only this page needs: no token fits them.
private nonisolated enum PocketPlacePageMetrics {
    /// The "send to" row.
    static let rowHeight: CGFloat = 56
    /// One send line.
    static let sendHeight: CGFloat = 54
    /// How many sends the page keeps in view.
    static let sendsShown = 3
    /// The pencil after the sentence, and the row's chevrons.
    static let pencil: CGFloat = 13
    static let chevron: CGFloat = 11
}

#Preview {
    NavigationStack {
        PocketPlacePage(place: PocketFixtures.claude)
    }
}
#endif
