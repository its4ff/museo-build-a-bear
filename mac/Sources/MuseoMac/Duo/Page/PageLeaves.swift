#if DEBUG
import SwiftUI

// MARK: - A thought

/// One thought as a true page: the mono line, the huge title, a thin player line, the
/// words with air, then what is kept and the keys. The four actions wait top right, faint.
struct PageThoughtLeaf: View {
    let thought: PocketThought
    var showsActions = true

    var body: some View {
        PageColumn {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    PageMono(RoomFixtures.dateLine(thought))
                    PageTitle(thought.title)
                }
                PagePlayerLine(length: thought.length, seed: thought.id)
                Text(thought.body)
                    .font(MuseFont.lora(PageMetrics.words))
                    .lineSpacing(PageMetrics.wordsLeading)
                    .foregroundStyle(MuseColor.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let reply = thought.reply {
                    aside(reply)
                }
                PageFoot(
                    left: "\(DuoWords.kept) · \(RoomFixtures.model)",
                    keys: DuoWords.thoughtKeys
                )
                .padding(.top, MuseSpacing.xs)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsActions {
                PageActions(actions: RoomAction.thought)
            }
        }
    }

    /// What a place sent back: a ruled aside, never acted on. Under it, why it went there.
    private func aside(_ reply: PocketReply) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                Text(reply.lead)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                Text(reply.text)
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink)
            }
            .padding(.leading, MuseSpacing.md)
            .padding(.vertical, MuseSpacing.xxs)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(MuseColor.moss300)
                    .frame(width: PageMetrics.rule)
                    .accessibilityHidden(true)
            }
            if let filed = thought.filedLine {
                Text(filed)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
    }
}

/// Room's capsule of actions, glyph for glyph and in the same order (copy, listen, save,
/// send to, delete in clay), top right. Page's one difference: it rests faint and comes
/// back under the pointer.
struct PageActions: View {
    let actions: [RoomAction]

    @State private var isHovered = false

    var body: some View {
        RoomActions(actions: actions)
            .opacity(isHovered ? 1 : PageMetrics.actionsRest)
            .onHover { isHovered = $0 }
            .museAnimation(MuseMotion.dissolve, value: isHovered)
            .padding(DuoMetrics.margin)
    }
}

// MARK: - A place

/// One place as a page: its name large, its sentence, where it sends as a line of words,
/// the last sends, then what it holds as a typeset list.
struct PagePlaceLeaf: View {
    let place: PocketPlace
    var lines: [PageFixtures.Line] = PageFixtures.claudeLines

    var body: some View {
        PageColumn {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                    PageTitle(place.name)
                    Text(place.sentence)
                        .font(MuseFont.lora(PageMetrics.sentence))
                        .foregroundStyle(MuseColor.ink70)
                }
                sendTo
                // One list: what the place holds, and beside each how its send went.
                VStack(alignment: .leading, spacing: MuseSpacing.row) {
                    PageEyebrow("\(place.count) thoughts")
                    ForEach(lines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                            Text(line.when)
                                .font(MuseType.caption)
                                .monospacedDigit()
                                .foregroundStyle(MuseColor.ink55)
                                .frame(width: PageMetrics.when - MuseSpacing.sm, alignment: .leading)
                            Text(line.words)
                                .font(MuseFont.lora(PageMetrics.listLine))
                                .foregroundStyle(line.ink.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let send = PageFixtures.send(for: line, in: place) {
                                if send.state == .failed {
                                    DuoSendAgain()
                                }
                                Text(send.line)
                                    .font(MuseType.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(MuseColor.ink55)
                                    .fixedSize()
                            }
                        }
                    }
                }
                PageFoot(left: DuoWords.kept, keys: DuoWords.placeKeys)
                    .padding(.top, MuseSpacing.xs)
            }
        }
        .overlay(alignment: .topTrailing) {
            PageActions(actions: RoomAction.place)
        }
    }

    /// "send to" as a line of words between two hairlines: where, and that it is on.
    private var sendTo: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
            Text("send to")
                .foregroundStyle(MuseColor.ink55)
            Text(place.destination.label)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: 0)
            Text(place.sends ? "sending" : "off")
                .foregroundStyle(place.sends ? MuseColor.moss600 : MuseColor.ink55)
        }
        .font(MuseType.body)
        .padding(.vertical, MuseSpacing.row)
        .overlay(alignment: .top) { PageHairline() }
        .overlay(alignment: .bottom) { PageHairline() }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - museo.fm

/// Someone's thought, set large, with its city and its hour. No name.
struct PageFMLeaf: View {
    let thought: PocketFMThought

    var body: some View {
        PageColumn {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                PageMono("\(thought.foot) · museo.fm")
                Text(thought.words)
                    .font(MuseFont.lora(PageMetrics.fmWords))
                    .tracking(PageMetrics.fmTracking)
                    .lineSpacing(PageMetrics.fmLeading)
                    .foregroundStyle(MuseColor.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if thought.hasVoice {
                    PagePlayerLine(length: RoomFixtures.fmLength, seed: thought.id)
                        .padding(.top, MuseSpacing.xs)
                }
                PageFoot(left: DuoWords.given(in: thought.city), keys: DuoWords.fmKeys)
                    .padding(.top, MuseSpacing.xs)
            }
        }
        .overlay(alignment: .topTrailing) {
            PageActions(actions: RoomAction.fm)
        }
    }
}
#endif
