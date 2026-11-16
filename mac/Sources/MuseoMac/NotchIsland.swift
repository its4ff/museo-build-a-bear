import AppKit
import Observation
import SwiftUI

/// The notch island: the black of the MacBook's notch grows to hold what you say. While you
/// hold the ring its ears open (the ring on the left, your voice on the right); when words
/// form it drops a line below; when they land it says where ("typed into Notes"), then folds
/// back into the notch. On a screen without a notch it hangs from the top center of the menu
/// bar. It never takes a click or focus, so typing goes on underneath.
///
/// The recipe follows the open source notch apps (DynamicNotchKit, boring.notch, NotchDrop,
/// VoiceInk): a fixed, click-through panel above the menu bar; the notch measured from the
/// screen's safe area; only the SwiftUI shape inside animates.
@MainActor
final class NotchIsland {
    static let shared = NotchIsland()

    private var panel: NotchPanel?
    private var hiding: Task<Void, Never>?
    private let model = NotchModel()

    /// The panel's fixed size: room for the widest island.
    fileprivate static let canvas = NSSize(width: 760, height: 140)

    func start() {
        follow()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { NotchIsland.shared.place() }
        }
    }

    // MARK: - Following the words

    private func follow() {
        withObservationTracking {
            _ = MenuIsland.shared.isOpen
        } onChange: {
            Task { @MainActor in
                NotchIsland.shared.openChanged()
                NotchIsland.shared.follow()
            }
        }
    }

    private func openChanged() {
        // A hold into a museo note shows its island in the note instead.
        if MenuIsland.shared.isOpen, !MenuIsland.shared.inNote {
            hiding?.cancel()
            let panel = self.panel ?? makePanel()
            self.panel = panel
            place()
            panel.orderFrontRegardless()
            model.isOpen = true
        } else {
            model.isOpen = false
            // Fold back into the notch, then step out of the way.
            hiding = Task {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled, !(MenuIsland.shared.isOpen && !MenuIsland.shared.inNote) else { return }
                panel?.orderOut(nil)
            }
        }
    }

    // MARK: - The panel

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(size: Self.canvas)
        panel.contentView = NSHostingView(rootView: NotchIslandView(model: model))
        return panel
    }

    /// Top center of the screen you're working on, flush with its top edge.
    private func place() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        model.notch = screen.notchSize ?? CGSize(width: 0, height: screen.menuBarHeight)
        model.hasNotch = screen.notchSize != nil
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - Self.canvas.width / 2, y: screen.frame.maxY - Self.canvas.height))
    }
}

/// What the island view needs beyond `MenuIsland`: open or folded, and the notch it grows from.
@MainActor
@Observable
private final class NotchModel {
    var isOpen = false
    var notch = CGSize(width: 200, height: 32)
    var hasNotch = true
}

/// Above the menu bar, on every space, never key, never in the way of a click.
private final class NotchPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = .mainMenu + 3
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

extension NSScreen {
    /// The camera notch, padded so its hardware edge never shows; nil on a screen without one.
    var notchSize: CGSize? {
        guard safeAreaInsets.top > 0, let left = auxiliaryTopLeftArea?.width, let right = auxiliaryTopRightArea?.width else { return nil }
        return CGSize(width: frame.width - left - right + 4, height: safeAreaInsets.top)
    }

    /// The menu bar's height (24 when it's hidden or can't be read).
    var menuBarHeight: CGFloat {
        let height = frame.maxY - visibleFrame.maxY
        return height > 0 ? height : 24
    }
}

// MARK: - The island

private struct NotchIslandView: View {
    let model: NotchModel
    private let island = MenuIsland.shared
    private let voice = MenuVoice.shared

    /// How far each ear reaches past the notch, and how far the line drops below it.
    private static let ear: CGFloat = 76
    /// Room for "typed into Notes" in the right ear.
    private static let noteEar: CGFloat = 132
    private static let wideEar: CGFloat = 150
    private static let line: CGFloat = 34

    var body: some View {
        let size = islandSize
        ZStack(alignment: .top) {
            NotchShape(top: model.isOpen ? 12 : 6, bottom: model.isOpen ? 18 : 12)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.isOpen ? 0.25 : 0), radius: 12, y: 6)
            content
                .frame(width: size.width - 2 * topRadius, height: size.height, alignment: .top)
                .opacity(model.isOpen ? 1 : 0)
                .animation(model.isOpen ? .easeOut(duration: 0.2).delay(0.09) : .easeIn(duration: 0.1), value: model.isOpen)
        }
        .frame(width: NotchIsland.canvas.width, height: NotchIsland.canvas.height, alignment: .top)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : (model.isOpen ? .spring(response: 0.42, dampingFraction: 0.8) : .spring(response: 0.45, dampingFraction: 1)), value: size)
        .environment(\.colorScheme, .dark)
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var topRadius: CGFloat { model.isOpen ? 12 : 6 }

    /// Folded: the notch itself. Listening: ears out. Words or a note: wider, and a line down.
    private var islandSize: CGSize {
        let notch = model.notch
        guard model.isOpen else { return CGSize(width: notch.width + 2 * 6, height: notch.height) }
        let ear = hasLine ? Self.wideEar : (island.isListening ? Self.ear : Self.noteEar)
        return CGSize(width: notch.width + 2 * ear + 2 * topRadius, height: notch.height + (hasLine ? Self.line : 0))
    }

    /// A line drops below the notch only for words forming. Where they went fits in an ear.
    private var hasLine: Bool {
        if island.ran != nil { return true }
        return island.isListening && (island.cue != nil || !island.words.heard.isEmpty || !island.words.hearing.isEmpty)
    }

    // MARK: - Contents

    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftEar
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: model.notch.width)
                rightEar
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, MuseSpacing.md)
            .frame(height: model.notch.height)
            if hasLine {
                line
                    .padding(.horizontal, MuseSpacing.lg)
                    .frame(height: Self.line - 6)
            }
        }
    }

    /// The dot ring: linen while you talk, a tick when the words land, amber from the ring.
    private var leftEar: some View {
        Image(nsImage: Self.ring(island.mark))
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var rightEar: some View {
        if island.isListening {
            // Five bars, louder in the middle, never flat: a quiet mic still reads as alive.
            HStack(spacing: 2.5) {
                ForEach(Array(voice.levels.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(MuseColor.orbHighlight)
                        .frame(width: 3, height: 3 + 13 * level * [0.55, 0.8, 1, 0.8, 0.55][index])
                }
            }
            .frame(height: 18)
        } else if let note = island.note {
            Text(note)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.ground.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// The words forming; a command as its keys, ready to run; words to be sent with a
    /// return chip after them.
    @ViewBuilder
    private var line: some View {
        switch island.cue ?? island.ran {
        case .command(let command, let said):
            HStack(spacing: MuseSpacing.xs) {
                chip(VoiceCommands.label(command))
                Text(said)
                    .font(MuseFont.lora(15))
                    .foregroundStyle(MuseColor.ground)
                    .lineLimit(1)
            }
            .transition(.opacity)
        case .ask(let agent, let text, let send):
            HStack(spacing: MuseSpacing.xs) {
                chip(agent.say)
                Text(text)
                    .font(MuseFont.lora(15))
                    .foregroundStyle(MuseColor.ground)
                    .lineLimit(1)
                    .truncationMode(.head)
                if send { chip("↩ send") }
            }
        case .typeThenSend(let kept):
            HStack(spacing: MuseSpacing.xs) {
                Text(kept)
                    .font(MuseFont.lora(15))
                    .foregroundStyle(MuseColor.ground)
                    .lineLimit(1)
                    .truncationMode(.head)
                chip("↩ send")
            }
        default:
            Text(words)
                .font(MuseFont.lora(15))
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    /// Keys, in a linen outline: what letting go will press.
    private func chip(_ text: String) -> some View {
        Text(text)
            .font(MuseType.captionMedium)
            .foregroundStyle(MuseColor.ground)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .overlay(Capsule().strokeBorder(MuseColor.ground.opacity(0.45), lineWidth: 1))
            .fixedSize()
    }

    /// Settled words in linen, the ones still forming fainter.
    private var words: AttributedString {
        var heard = AttributedString(island.words.heard)
        heard.foregroundColor = MuseColor.ground
        let gap = island.words.heard.isEmpty || island.words.hearing.isEmpty ? "" : " "
        var hearing = AttributedString(gap + island.words.hearing)
        hearing.foregroundColor = MuseColor.ground.opacity(0.5)
        return heard + hearing
    }

    /// The ring in cells, drawn once per look.
    private static func ring(_ mark: MenuIsland.Mark) -> NSImage {
        switch mark {
        case .voice: linenRing
        case .tick: tickRing
        }
    }

    private static let linenRing = DotRingIcon.small(.linen)
    private static let tickRing = DotRingIcon.small(.tick)
}

#if DEBUG
extension NotchIsland {
    /// A few island states for the README, each hanging from the top of a strip of linen.
    static func readmeImage() -> CGImage? {
        let model = NotchModel()
        model.notch = CGSize(width: 204, height: 32)
        model.isOpen = true
        let island = MenuIsland.shared
        var shots: [CGImage] = []
        func shot() {
            let view = NotchIslandView(model: model)
                .frame(width: 760, height: 120, alignment: .top)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let image = renderer.cgImage { shots.append(image) }
        }
        island.listen()
        island.update(HoldSpeech.Words(heard: "three things to settle before friday, the price card,", hearing: "the case photos"))
        shot()
        island.update(HoldSpeech.Words(heard: "Hey Claude, what's a good name for a ring app?", hearing: ""))
        shot()
        island.finish(note: "typed into Claude")
        shot()
        guard let first = shots.first,
              let context = CGContext(data: nil, width: first.width, height: first.height * shots.count, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // One sheet of linen behind them all, so the strips don't show seams.
        let paper = ImageRenderer(content: MuseBackground().frame(width: 760, height: CGFloat(120 * shots.count)))
        paper.scale = 2
        if let ground = paper.cgImage {
            context.draw(ground, in: CGRect(x: 0, y: 0, width: first.width, height: first.height * shots.count))
        }
        for (index, image) in shots.enumerated() {
            context.draw(image, in: CGRect(x: 0, y: (shots.count - 1 - index) * first.height, width: first.width, height: first.height))
        }
        return context.makeImage()
    }

    /// Every island state stacked into one png, on a menu-bar gray: folded, listening, words
    /// forming, typed. For checking without a ring (`ScreenSheet`).
    static func renderStates(to folder: URL) {
        let model = NotchModel()
        model.notch = CGSize(width: 204, height: 32)
        let island = MenuIsland.shared
        var shots: [CGImage] = []
        func shot() {
            let renderer = ImageRenderer(content: NotchIslandView(model: model).background(Color(white: 0.82)))
            renderer.scale = 2
            if let image = renderer.cgImage { shots.append(image) }
        }
        shot()
        model.isOpen = true
        island.listen()
        shot()
        island.update(HoldSpeech.Words(heard: "three things to settle before friday, the price card,", hearing: "the case photos"))
        shot()
        island.update(HoldSpeech.Words(heard: "Switch tab.", hearing: ""))
        shot()
        island.update(HoldSpeech.Words(heard: "Tell him I'll be ten minutes late,", hearing: "and send it."))
        shot()
        island.update(HoldSpeech.Words(heard: "Hey Claude, what's a good name for a ring app?", hearing: ""))
        shot()
        island.finish(note: "typed into Claude")
        shot()
        // A command that ran: its pill stays, with the tick.
        island.listen()
        island.update(HoldSpeech.Words(heard: "Switch tab.", hearing: ""))
        island.finish(note: nil, ran: VoiceCommands.shared.read("Switch tab."))
        shot()
        guard let first = shots.first,
              let context = CGContext(data: nil, width: first.width, height: first.height * shots.count, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        for (index, image) in shots.enumerated() {
            context.draw(image, in: CGRect(x: 0, y: (shots.count - 1 - index) * first.height, width: first.width, height: first.height))
        }
        if let sheet = context.makeImage() {
            try? NSBitmapImageRep(cgImage: sheet).representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("notch.png"))
            print("[museo][mac] wrote notch.png")
        }
    }
}
#endif

/// The notch's own outline: top corners that curve out into the menu bar, rounded bottom
/// corners. As wide as the island plus a top radius on each side.
struct NotchShape: Shape {
    var top: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(top, bottom) }
        set {
            top = newValue.first
            bottom = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top), control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY), control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom), control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
