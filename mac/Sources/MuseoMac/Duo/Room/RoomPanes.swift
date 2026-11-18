#if DEBUG
import SwiftUI

// MARK: - A thought

/// The reading pane, as today: the mono line, the title, what heard it, the player, the
/// words, then what stays and the keys.
struct RoomThoughtPane: View {
    let thought: PocketThought

    var body: some View {
        RoomPage {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                RoomMonoLine(RoomFixtures.dateLine(thought))
                RoomTitle(thought.title)
                Text(RoomFixtures.heardLine(thought))
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
            }
            DuoListenCapsule(length: thought.length, seed: thought.id)
            Text(thought.body)
                .font(MuseFont.lora(RoomMetrics.words))
                .foregroundStyle(MuseColor.ink)
                .lineSpacing(MuseSpacing.xs)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let reply = thought.reply {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    RoomAside(lead: reply.lead, text: reply.text)
                    if let filed = thought.filedLine {
                        Text(filed)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                    }
                }
            }
            RoomFoot(kept: DuoWords.kept, keys: DuoWords.thoughtKeys)
        }
    }
}

// MARK: - A place

/// A place's page: its name, its sentence, where it sends, the last sends, its thoughts.
struct RoomPlacePane: View {
    let place: PocketPlace

    var body: some View {
        RoomPage {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                Text("a place · \(place.count) thoughts")
                    .font(MuseType.caption)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                RoomTitle(place.name)
                Text(place.sentence)
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink70)
            }
            sendTo
            section("last sends") {
                ForEach(place.recentSends) { send in
                    RoomLine(title: send.title, trailing: send.line, again: send.state == .failed)
                }
            }
            section("its thoughts") {
                ForEach(RoomFixtures.claudeThoughts, id: \.title) { thought in
                    RoomLine(title: thought.title, trailing: thought.when)
                }
            }
            RoomFoot(kept: DuoWords.kept, keys: DuoWords.placeKeys)
        }
    }

    /// Where this place sends, and whether it does.
    private var sendTo: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text("send to")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
            Text(place.destination.label)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
            Spacer()
            // A switch greys out in a window that isn't key, so the state is said in words.
            Circle()
                .fill(MuseColor.moss600)
                .frame(width: RoomMetrics.dot, height: RoomMetrics.dot)
                .accessibilityHidden(true)
            Text(place.sendsOn ? "sending" : "paused")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink70)
        }
        .frame(height: RoomMetrics.line + MuseSpacing.xs)
        .overlay(alignment: .top) { RoomHair() }
        .overlay(alignment: .bottom) { RoomHair() }
    }

    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(title)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { rows() }
        }
    }
}

// MARK: - A thought from museo.fm

/// Someone's thought, read large: where and when, the words, their voice if they gave it.
struct RoomFMPane: View {
    let thought: PocketFMThought

    var body: some View {
        RoomPage {
            VStack(alignment: .leading, spacing: MuseSpacing.md) {
                RoomMonoLine("\(thought.foot) · museo.fm")
                Text(thought.words)
                    .font(MuseType.title)
                    .tracking(MuseType.titleTracking)
                    .lineSpacing(MuseSpacing.xs)
                    .foregroundStyle(MuseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if thought.hasVoice {
                DuoListenCapsule(length: RoomFixtures.fmLength, seed: thought.id)
            }
            RoomFoot(kept: DuoWords.given(in: thought.city), keys: DuoWords.fmKeys)
        }
    }
}

// MARK: - Pieces

/// The reading column: one comfortable measure, started where today's page starts.
struct RoomPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xl) {
            content
        }
        .frame(maxWidth: RoomMetrics.measure, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sectionLabel)
        .padding(.top, RoomMetrics.pageTop)
        .frame(maxWidth: .infinity)
    }
}

/// The one mono line on a thought.
struct RoomMonoLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(MuseFont.mono(.caption))
            .foregroundStyle(MuseColor.ink55)
    }
}

/// The huge Lora title.
struct RoomTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(MuseType.display)
            .tracking(MuseType.displayTracking)
            .foregroundStyle(MuseColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// An answer, set apart by a rule.
struct RoomAside: View {
    let lead: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(lead)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Text(text)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
        }
        .padding(.leading, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.xxs)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(MuseColor.moss300)
                .frame(width: RoomMetrics.rule)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One line on a place's page: the words in Lora, a quiet fact at the right.
struct RoomLine: View {
    let title: String
    let trailing: String
    /// A send that failed offers one quiet word. Moss, not clay: the trash is the
    /// window's one clay mark.
    var again = false

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(title)
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
            Spacer(minLength: MuseSpacing.sm)
            if again {
                DuoSendAgain()
            }
            Text(trailing)
                .font(MuseType.caption)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(height: RoomMetrics.line)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MuseColor.divider).frame(height: RoomMetrics.hair)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RoomHair: View {
    var body: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: RoomMetrics.hair)
            .accessibilityHidden(true)
    }
}

/// The page's foot: what stays, and the keys.
struct RoomFoot: View {
    let kept: String
    let keys: String

    var body: some View {
        HStack {
            Text(kept)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Spacer()
            Text(keys)
                .font(MuseFont.mono(.caption2))
                .foregroundStyle(MuseColor.ink55)
        }
        .padding(.top, MuseSpacing.md)
        .overlay(alignment: .top) { RoomHair() }
    }
}
#endif
