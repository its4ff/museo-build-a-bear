#if DEBUG
import SwiftUI

/// `shelf-thought`: a thought brought forward. The shelf stays where it was, dimmed and
/// softened, and the thought is one sheet of paper over it.
struct ShelfThought: View {
    var thought: PocketThought = PocketFixtures.dentist

    var body: some View {
        ShelfWindow(current: .yours, keys: ["esc back", "space listen", "⌘K send to…", "⌘C copy"]) {
            ShelfYoursPage(selected: thought.id)
                .blur(radius: ShelfMetrics.backBlur)
                .overlay { MuseColor.ground.opacity(ShelfMetrics.backDim) }
                .accessibilityHidden(true)
        }
        .overlay {
            ShelfThoughtPanel(thought: thought)
                .padding(.bottom, MuseSpacing.sectionLabel)
        }
    }
}

/// The thought's page as a panel: the one mono line, the title, the words, what came
/// back as a ruled aside, where it is filed, then listen and "send to…".
struct ShelfThoughtPanel: View {
    let thought: PocketThought

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.sheet, style: .continuous)
        VStack(alignment: .leading, spacing: MuseSpacing.xl) {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                Text(thought.meta)
                    .font(MuseType.code)
                    .foregroundStyle(MuseColor.ink55)
                Text(thought.title)
                    .font(MuseType.display)
                    .tracking(MuseType.displayTracking)
                    .foregroundStyle(MuseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(words)
                .font(MuseType.headline)
                .lineSpacing(MuseType.serifLineSpacing)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let reply = thought.reply {
                HStack(spacing: MuseSpacing.md) {
                    Capsule()
                        .fill(MuseColor.moss300)
                        .frame(width: ShelfMetrics.rule)
                    VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                        Text(reply.lead)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                        Text(reply.text)
                            .font(MuseType.body)
                            .foregroundStyle(MuseColor.ink)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, MuseSpacing.xs)
            }
            if let filed = thought.filedLine {
                HStack(spacing: MuseSpacing.xs) {
                    Text(filed)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                    Image(systemName: "xmark")
                        .museSymbol(ShelfMetrics.glyph, weight: .regular)
                        .foregroundStyle(MuseColor.ink55)
                        .accessibilityLabel("take it out of \(thought.place ?? "this place")")
                }
            }
            HStack(spacing: MuseSpacing.sm) {
                DuoListenCapsule(length: thought.length, seed: thought.id)
                DuoQuietButton("send to…")
            }
            .padding(.top, MuseSpacing.md)
        }
        .padding(ShelfMetrics.panelInset)
        .frame(width: ShelfMetrics.panelWidth, alignment: .leading)
        .background(DuoColor.paper, in: shape)
        .overlay { shape.strokeBorder(MuseColor.hairline) }
        .overlay(alignment: .topTrailing) {
            // Paper, so no glass: one quiet glyph in the corner. Esc does the same.
            Button {} label: {
                Image(systemName: "xmark")
                    .museSymbol(ShelfMetrics.close, weight: .medium)
                    .foregroundStyle(MuseColor.ink55)
                    .frame(width: ShelfMetrics.closeBox, height: ShelfMetrics.closeBox)
                    .background(MuseColor.divider, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("close")
            .accessibilityLabel("close")
            .padding(MuseSpacing.md)
        }
        .museElevation(.e2)
    }

    /// The words after the title, so the page does not say the title twice.
    private var words: String {
        let lead = thought.title + ". "
        return thought.body.hasPrefix(lead) ? String(thought.body.dropFirst(lead.count)) : thought.body
    }
}
#endif
