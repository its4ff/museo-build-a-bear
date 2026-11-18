#if DEBUG
import SwiftUI

/// The note window, kept as zen as it is: paper, the words in large Lora with older lines
/// fading back, the small tick at the eye line. The only duo in it is the paper itself
/// (the dune, very quiet). No ring pill here: the page stays words only.
struct SmallNote: View {

    /// A made-up note, set line by line so the last one rests on the eye line.
    private static let lines = [
        "the ring is best when you forget it's there. you",
        "hold, you say the thing, and it's kept. so the",
        "launch should feel the same. no countdown, no",
        "reveal. send it to the first rings of people, then",
        "their friends. not a big day. a slow, warm week",
    ]
    private static let last = "and every post is someone who"
    private static let forming = "already wears it"

    var body: some View {
        GeometryReader { geo in
            let eye = geo.size.height / 2
            let left = (geo.size.width - SmallMetrics.noteColumn) / 2
            ZStack(alignment: .topLeading) {
                page
                    .frame(width: SmallMetrics.noteColumn, height: eye + SmallMetrics.noteLine / 2, alignment: .bottomLeading)
                    .padding(.leading, left)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .mask { fade }
                Capsule()
                    .fill(MuseColor.moss600)
                    .frame(width: SmallMetrics.tick.width, height: SmallMetrics.tick.height)
                    .position(x: left - MuseSpacing.lg, y: eye + SmallMetrics.tickDrop)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) { DuoWindowChrome() }
        .background { PocketGround(strength: SmallMetrics.noteDune) }
        .preferredColorScheme(.light)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(MuseColor.ink)
                    .frame(height: SmallMetrics.noteLine)
            }
            Text(Self.last + " " + Self.forming)
                .foregroundStyle(MuseColor.ink)
                .frame(height: SmallMetrics.noteLine)
        }
        .font(MuseFont.lora(SmallMetrics.noteType))
        .lineLimit(1)
        .fixedSize()
    }

    /// The note's own fade: lines above the eye line thin toward the top.
    private var fade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0.04),
                .init(color: .black.opacity(0.14), location: 0.2),
                .init(color: .black.opacity(0.45), location: 0.4),
                .init(color: .black, location: 0.455),
                .init(color: .black, location: 0.86),
                .init(color: .black.opacity(0), location: 0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
#endif
