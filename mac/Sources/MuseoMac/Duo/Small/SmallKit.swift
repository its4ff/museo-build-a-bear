#if DEBUG
import SwiftUI

// What the four small surfaces share: their measures, the desk they hang over in a
// render (a slice of dark menu bar on a wallpaper neutral ground), and a few quiet pieces.

nonisolated enum SmallMetrics {
    // MARK: The desk

    /// The menu bar's height on a mac with a notch.
    static let menuBar: CGFloat = 32
    /// The menu bar over a panel: the plain one.
    static let slimBar: CGFloat = 26
    /// The dot ring in the menu bar.
    static let barIcon: CGFloat = 17
    /// A status glyph in the menu bar.
    static let barGlyph: CGFloat = 12
    /// How much of the pale ink a status glyph carries.
    static let barInk: Double = 0.78

    // MARK: The panel

    static let panelWidth: CGFloat = 310
    static let panelHeight: CGFloat = 706
    /// Desk showing either side of the panel, and under it.
    static let panelDesk: CGFloat = 22
    /// How much of the dune's color the panel's paper carries.
    static let panelDune: Double = 0.42
    static let rowHeight: CGFloat = 32
    static let switchWidth: CGFloat = 30
    static let switchHeight: CGFloat = 18
    static let switchKnob: CGFloat = 14
    static let keyCapHeight: CGFloat = 20
    static let keyCapWidth: CGFloat = 34
    static let keyCapRadius: CGFloat = 6
    static let phrase: CGFloat = 14.5
    static let alternateDot: CGFloat = 3
    static let alternateGap: CGFloat = 2.5
    static let commandRow: CGFloat = 28
    static let appIcon: CGFloat = 20
    static let appIconRadius: CGFloat = 5
    static let recentWords: CGFloat = 15
    static let chevron: CGFloat = 9
    static let power: CGFloat = 13
    /// The ring's quiet "more" glyph beside the pill, and its hit box.
    static let more: CGFloat = 13
    static let moreBox: CGFloat = 28

    // MARK: The island

    static let islandShot = CGSize(width: 900, height: 300)
    static let notch = CGSize(width: 204, height: 32)
    static let restEar: CGFloat = 40
    static let wideEar: CGFloat = 150
    static let noteEar: CGFloat = 132
    static let islandLine: CGFloat = 38
    static let islandWords: CGFloat = 16
    static let islandMark: CGFloat = 18
    static let islandMarkDots = 17
    static let islandTop: CGFloat = 12
    static let islandBottom: CGFloat = 18
    static let islandRestBottom: CGFloat = 12
    static let chipHeight: CGFloat = 20
    static let voiceBar: CGFloat = 3
    static let voiceGap: CGFloat = 2.5
    static let voiceReach: CGFloat = 13
    static let forming: Double = 0.42

    // MARK: The note

    static let noteShot = CGSize(width: 900, height: 600)
    static let noteType: CGFloat = 26
    static let noteLine: CGFloat = 44
    static let noteColumn: CGFloat = 580
    static let noteDune: Double = 0.3
    static let tick = CGSize(width: 10, height: 2)
    /// Lora sits low in its line: the tick meets the words' middle.
    static let tickDrop: CGFloat = 3

    // MARK: Your words

    static let wordsColumn: CGFloat = 760
    static let wordsTop: CGFloat = 64
    static let numeral: CGFloat = 148
    static let numeralTracking: CGFloat = -5
    /// Lora's line box is taller than its figures: pull the neighbors in.
    static let numeralTrim: CGFloat = -22
    static let figure: CGFloat = 22
    static let barHeight: CGFloat = 12
    static let legendDot: CGFloat = 7
    static let listWord: CGFloat = 18
    static let listRow: CGFloat = 30
    static let spanGap: CGFloat = 22
}

nonisolated enum SmallColor {
    /// A wallpaper that takes no side: warm grey, lighter at the top.
    static let deskTop = MuseColor.shelf.mix(with: MuseColor.ink55, by: 0.2)
    static let deskFoot = MuseColor.shelf.mix(with: MuseColor.ink55, by: 0.34)
    /// The menu bar, dark over that wallpaper.
    static let menuBar = MuseColor.moss900.mix(with: .black, by: 0.55).opacity(0.86)
    /// Pale ink on black: the island's words and the ring's print.
    static let pale = PocketColor.printSand
    /// The notch, and the island that continues it.
    static let notch = Color.black
    /// The ring's amber on the bar.
    static let amberFoot = PocketColor.pillAmber
    static let amberHead = MuseColor.ringAmber
}

/// Two runs of one line, each in its own ink: settled words, then the ones still forming.
func smallInk(_ first: String, _ firstInk: Color, then second: String, _ secondInk: Color) -> AttributedString {
    var head = AttributedString(first)
    head.foregroundColor = firstInk
    var tail = AttributedString(second)
    tail.foregroundColor = secondInk
    return head + tail
}

/// The desk a small surface is drawn over, so it reads in context: neutral wallpaper.
struct SmallDesk: View {
    var body: some View {
        LinearGradient(colors: [SmallColor.deskTop, SmallColor.deskFoot], startPoint: .top, endPoint: .bottom)
            .accessibilityHidden(true)
    }
}

/// A slice of dark menu bar. `content` sits at its trailing end.
struct SmallMenuBar<Content: View>: View {
    var height: CGFloat = SmallMetrics.menuBar
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: MuseSpacing.md) {
            Spacer(minLength: 0)
            content
        }
        .padding(.horizontal, MuseSpacing.md)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(SmallColor.menuBar)
        .accessibilityHidden(true)
    }
}

/// One status glyph in the menu bar, in pale ink.
struct SmallBarGlyph: View {
    let systemName: String

    init(_ systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: systemName)
            .museSymbol(SmallMetrics.barGlyph, weight: .medium)
            .foregroundStyle(SmallColor.pale.opacity(SmallMetrics.barInk))
    }
}

/// A switch at the panel's size: moss when on, a white knob. Drawn, so it never borrows
/// the system's green.
struct SmallSwitch: View {
    let isOn: Bool
    let label: String

    var body: some View {
        Capsule()
            .fill(isOn ? AnyShapeStyle(MuseColor.primaryGradient) : AnyShapeStyle(MuseColor.ink.opacity(0.14)))
            .frame(width: SmallMetrics.switchWidth, height: SmallMetrics.switchHeight)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(MuseColor.composer)
                    .frame(width: SmallMetrics.switchKnob, height: SmallMetrics.switchKnob)
                    .padding(.horizontal, (SmallMetrics.switchHeight - SmallMetrics.switchKnob) / 2)
                    .museElevation(.e1)
            }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "on" : "off")
            .accessibilityAddTraits(.isButton)
    }
}
#endif
