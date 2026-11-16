import AppKit
import MuseoKit
import SwiftUI

/// The menu bar icon: the museo ring as print (`DotRingCells`), in color by state.
///
/// - not linked: faint ink, the menu bar's own color
/// - linked: the ring in the menu bar's ink; a tick for a second after words are typed.
///   (Nothing for recordings waiting: the panel's ring row shows those when you open it.)
/// - holding: a forest pill with the ring in linen and your voice in cells beside it
/// - recording on the ring: the pill with the ring in amber and the time running
/// - charging: the ring with a still bolt of cells in its opening, until it's full
/// - bringing it in: moss dots filling amber, clockwise
struct MenuIcon: View {
    private let voice = MenuVoice.shared
    private let watch = RingWatch.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let status = RingModel.shared.status
        Image(nsImage: DotRingIcon.image(for: state(status)))
            .accessibilityLabel(status.accessibilityLabel)
            // Always on screen, so it lends the dock icon a way to open the library.
            .onAppear { LibraryOpener.take(openWindow) }
    }

    private func state(_ status: RingStatus) -> DotRingIcon.State {
        switch status.link {
        case .notSetUp, .away, .bluetoothOff: return .faint
        case .joining: return .faint
        case .linked:
            if status.isLive { return .holding(voice.levels) }
            if status.isRecordingOnRing, let since = watch.recordingSince {
                return .recording(watch.now.timeIntervalSince(since))
            }
            if status.isSyncing { return .syncing(status.syncProgress ?? 0) }
            if status.showsCharging, !watch.typedFlash { return .charging }
            return .linked(typed: watch.typedFlash)
        }
    }
}

/// Draws the icon's states. Each image draws itself when the menu bar does, so it can read
/// the menu bar's appearance and pick the light or dark set.
enum DotRingIcon {
    enum State {
        case faint
        case linked(typed: Bool)
        case charging
        case holding([Double])
        case recording(TimeInterval)
        case syncing(Double)
    }


    private static let height: CGFloat = 18

    static func image(for state: State) -> NSImage {
        switch state {
        case .faint:
            // Gray: the menu bar's own ink at 40%.
            return template { cg in
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: 1, colors: [NSColor.black.withAlphaComponent(0.4)])
            }

        case .linked(let typed):
            // Linked: a template at full strength, so macOS paints it solid white on a dark or
            // tinted menu bar and solid black on a light one, like the icons beside it.
            return template { cg in
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: 1, colors: [.black])
                if typed { fill(cells: tick, in: cg, at: .zero, scale: 1, colors: [.black]) }
            }

        case .charging:
            // Like linked, a template, with the bolt where the tick goes.
            return template { cg in
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: 1, colors: [.black])
                fill(cells: bolt, in: cg, at: .zero, scale: 1, colors: [.black])
            }

        case .holding(let levels):
            return draw(width: 34) { cg, _ in
                pill(in: cg, width: 34)
                fill(cells: DotRingCells.all, in: cg, at: CGPoint(x: 4, y: 4), scale: 10 / 18, colors: [NSColor(MuseColor.ground)])
                voiceCells(levels, in: cg, from: 17)
            }

        case .recording(let elapsed):
            let text = elapsed.museDuration as NSString
            let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(MuseColor.ground)]
            let textWidth = ceil(text.size(withAttributes: attributes).width)
            let width = 19 + textWidth + 7
            return draw(width: width) { cg, _ in
                pill(in: cg, width: width)
                fill(cells: DotRingCells.all, in: cg, at: CGPoint(x: 4, y: 4), scale: 10 / 18, colors: amber)
                text.draw(at: CGPoint(x: 18, y: 2.5), withAttributes: attributes)
            }

        case .syncing(let progress):
            let reach = max(0.08, min(1, progress)) * 360
            return draw(width: height) { cg, dark in
                fill(cells: DotRingCells.all.filter { $0.angle > reach }, in: cg, at: .zero, scale: 1, colors: [ink(dark)])
                fill(cells: DotRingCells.all.filter { $0.angle <= reach }, in: cg, at: .zero, scale: 1, colors: amber)
            }
        }
    }

    // MARK: - Drawing

    /// A template image: macOS colors it to match the menu bar (white, black, or tinted).
    private static func template(_ paint: @escaping (CGContext) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: height, height: height), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            paint(cg)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The menu bar's own ink, for full-color states: white on dark, near black on light.
    private static func ink(_ dark: Bool) -> NSColor {
        dark ? .white : NSColor.black.withAlphaComponent(0.85)
    }

    /// A full-color image `width` points wide, drawn with the menu bar's appearance.
    private static func draw(width: CGFloat, _ paint: @escaping (CGContext, Bool) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            paint(cg, dark)
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Fills square cells, with a diagonal gradient when given more than one color (lit from
    /// the top left, like the orb).
    private static func fill(cells: [Cell], in cg: CGContext, at origin: CGPoint, scale: CGFloat, colors: [NSColor]) {
        guard !cells.isEmpty else { return }
        let path = CGMutablePath()
        for cell in cells {
            let side = cell.side * scale
            path.addRect(CGRect(x: origin.x + cell.x * scale - side / 2, y: origin.y + cell.y * scale - side / 2, width: side, height: side))
        }
        cg.saveGState()
        cg.addPath(path)
        if colors.count == 1 {
            cg.setFillColor(colors[0].cgColor)
            cg.fillPath()
        } else {
            cg.clip()
            let span = DotRingCells.size * scale
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: origin.x + span * 0.1, y: origin.y),
                    end: CGPoint(x: origin.x + span * 0.85, y: origin.y + span),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }
        cg.restoreGState()
    }

    /// The forest pill behind the holding and recording states.
    private static func pill(in cg: CGContext, width: CGFloat) {
        let rect = CGRect(x: 0, y: 1, width: width, height: 16)
        cg.saveGState()
        cg.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        cg.clip()
        let colors = [NSColor(MuseColor.moss600).cgColor, NSColor(MuseColor.moss900).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: nil) {
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: width * 0.2, y: 1),
                end: CGPoint(x: width * 0.8, y: 17),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        cg.restoreGState()
    }

    /// Five columns of cells, as tall as the last five readings of your voice.
    private static func voiceCells(_ levels: [Double], in cg: CGContext, from x: CGFloat) {
        cg.setFillColor(NSColor(MuseColor.orbHighlight).cgColor)
        for (column, level) in levels.enumerated() {
            let count = max(1, min(5, Int((level * 5).rounded(.up))))
            let left = x + CGFloat(column) * 2.6
            let top = 9 - CGFloat(count) * 1.2
            for row in 0..<count {
                cg.fill(CGRect(x: left, y: top + CGFloat(row) * 2.4, width: 1.6, height: 1.6))
            }
        }
    }

    // MARK: - The notch island's ring

    enum Look { case linen, tick, amber, moss, charging, faint }

    /// The ring small: linen, tick and amber for the notch island's left ear (on black),
    /// moss and faint for the panel (on paper).
    static func small(_ look: Look, size: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            let scale = size / DotRingCells.size
            switch look {
            case .linen:
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: scale, colors: [NSColor(MuseColor.ground)])
            case .tick:
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: scale, colors: [NSColor(MuseColor.ground)])
                fill(cells: tick, in: cg, at: .zero, scale: scale, colors: [NSColor(MuseColor.orbHighlight)])
            case .amber:
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: scale, colors: amber)
            case .moss:
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: scale, colors: moss(false))
            case .charging:
                fill(cells: DotRingCells.all + bolt, in: cg, at: .zero, scale: scale, colors: moss(false))
            case .faint:
                fill(cells: DotRingCells.all, in: cg, at: .zero, scale: scale, colors: [NSColor(MuseColor.ink55).withAlphaComponent(0.5)])
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Colors and marks

    private static func moss(_ dark: Bool) -> [NSColor] {
        dark
            ? [NSColor(MuseColor.orbHighlight), NSColor(MuseColor.moss300), NSColor(MuseColor.orbMid)]
            : [NSColor(MuseColor.orbMid), NSColor(MuseColor.moss600), NSColor(MuseColor.moss900)]
    }

    private static let amber = [NSColor(MuseColor.ochre), NSColor(MuseColor.ringAmber)]

    /// A tick of cells in the ring's opening.
    private static let tick: [Cell] = [
        (6.1, 9.1), (7.3, 10.3), (8.5, 11.5), (9.7, 10.3), (10.9, 9.1), (12.1, 7.9), (13.3, 6.7),
    ].map { Cell(x: $0.0, y: $0.1, side: 0.95, angle: 0) }

    /// A bolt of cells in the ring's opening, two wide so it reads at 18 points: down to the
    /// left, across, and down to the left again.
    private static let bolt: [Cell] = [
        (6, [10, 11]), (7, [9, 10]), (8, [8, 9]), (9, [7, 8, 9, 10, 11]), (10, [9, 10]), (11, [8, 9]), (12, [7, 8]),
    ].flatMap { row, columns in
        columns.map { Cell(x: CGFloat($0), y: CGFloat(row), side: 0.86, angle: 0) }
    }
}

extension RingStatus {
    /// On the charger and not full yet: the bolt shows. Full on the charger reads as linked.
    var showsCharging: Bool {
        isLinked && isCharging && (battery ?? 0) < 100
    }
}
