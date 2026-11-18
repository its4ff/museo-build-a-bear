#if DEBUG
import SwiftUI

/// Room's own measures. Everything else comes from `DuoMetrics` and the house tokens.
nonisolated enum RoomMetrics {
    /// The sidebar, as wide as today's.
    static let sidebar: CGFloat = 310
    /// The glass column's gap from the window's edge, and its inner gutter.
    static let inset: CGFloat = MuseSpacing.xs
    /// The row the window dots and the three glyphs share.
    static let topRow: CGFloat = 30
    /// One glyph button, and its symbol.
    static let glyph: CGFloat = 28
    static let glyphSymbol: CGFloat = 13
    /// The small arrow before "all" when it is the way back.
    static let backSymbol: CGFloat = 9
    /// The search field.
    static let field: CGFloat = 34
    /// A source row ("places", "museo.fm").
    static let source: CGFloat = 28
    static let sourceGlyph: CGFloat = 18
    /// A row's words, and a place's name.
    static let rowTitle: CGFloat = 15
    static let placeName: CGFloat = 17
    /// The list dissolves over this much above the ring pill.
    static let listFade: CGFloat = 32
    /// The reading column and where it starts.
    static let measure: CGFloat = 620
    static let pageTop: CGFloat = 84
    /// The words on a thought's page.
    static let words: CGFloat = 21
    /// The action capsule and one action in it.
    static let capsule: CGFloat = 40
    static let action: CGFloat = 36
    static let actionSymbol: CGFloat = 14
    /// Hairlines, the reply's rule, small dots.
    static let hair: CGFloat = 1
    static let rule: CGFloat = 2
    static let dot: CGFloat = 6
    /// One line row on a place's page.
    static let line: CGFloat = 38
}

nonisolated enum RoomColor {
    /// The paper well under the source the sidebar is looking at.
    static let well = MuseColor.ink.opacity(0.07)
}

/// Where the sidebar is looking.
nonisolated enum RoomSource: Hashable, Sendable {
    case yours, places, fm
}

/// The library window: a glass column of thoughts, the reading pane, the glass capsule of
/// actions top right. Today's mac, on the dune.
struct RoomWindow<List: View, Pane: View>: View {
    let source: RoomSource
    let actions: [RoomAction]
    @ViewBuilder var list: List
    @ViewBuilder var pane: Pane

    var body: some View {
        HStack(spacing: 0) {
            RoomSidebar(source: source) { list }
                .frame(width: RoomMetrics.sidebar - RoomMetrics.inset)
                .padding([.leading, .vertical], RoomMetrics.inset)
            pane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .topTrailing) {
                    RoomActions(actions: actions)
                        .padding(DuoMetrics.margin)
                }
        }
        .overlay(alignment: .topLeading) {
            DuoWindowChrome()
                .padding(.top, MuseSpacing.xxs)
        }
        .background { PocketGround() }
        .preferredColorScheme(.light)
    }
}

// MARK: - The action capsule

/// One glyph in the floating capsule.
nonisolated struct RoomAction: Identifiable, Hashable, Sendable {
    let symbol: String
    let label: String
    var isConsequence = false

    var id: String { symbol }

    static let copy = RoomAction(symbol: "square.on.square", label: "copy the words")
    static let listen = RoomAction(symbol: "waveform", label: "show the audio in finder")
    static let save = RoomAction(symbol: "bookmark", label: "save this thought")
    static let send = RoomAction(symbol: "arrow.up.right", label: "send to a place")
    static let delete = RoomAction(symbol: "trash", label: "delete this thought", isConsequence: true)

    static let thought = [copy, listen, save, send, delete]
    static let fm = [copy, listen, save]
    static let place = [
        RoomAction(symbol: "plus", label: "new place"),
        RoomAction(symbol: "pencil", label: "rename this place"),
        RoomAction(symbol: "trash", label: "delete this place", isConsequence: true),
    ]
}

/// The glass capsule of actions, top right. Its trash is the window's one clay mark.
struct RoomActions: View {
    let actions: [RoomAction]

    var body: some View {
        HStack(spacing: MuseSpacing.xxs / 2) {
            ForEach(actions) { action in
                Button {} label: {
                    Image(systemName: action.symbol)
                        .font(MuseFont.symbol(RoomMetrics.actionSymbol))
                        .foregroundStyle(action.isConsequence ? MuseColor.clay : MuseColor.ink70)
                        .frame(width: RoomMetrics.action, height: RoomMetrics.action)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(action.label)
                .accessibilityLabel(action.label)
            }
        }
        .padding(.horizontal, MuseSpacing.xs)
        .frame(height: RoomMetrics.capsule)
        .duoControlGlass()
    }
}
#endif
