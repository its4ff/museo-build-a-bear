import AppKit
import MuseoKit
import SwiftUI

/// The first run, on the real ring: hello, wake your ring, let museo type, one first hold.
/// Shown once, the first time museo opens on this mac (`-welcome YES` shows it again).
struct WelcomeWindow: View {
    static let id = "welcome"
    private static let doneKey = "museo.mac.welcomed"

    /// The first run has been finished, or put off, on this mac.
    static var isDone: Bool {
        UserDefaults.standard.bool(forKey: doneKey) && !UserDefaults.standard.bool(forKey: "welcome")
    }

    @State private var step = WelcomeStep.hello
    @State private var canType = TextInserter.canType
    @State private var said: String?
    @Environment(\.dismissWindow) private var dismissWindow
    private let dictation = Dictation.shared
    private let watch = RingWatch.shared
    private let local = LocalSpeech.shared
    /// The model the first run brings down: the accurate one.
    private let kind = LocalSpeech.Kind.parakeet
    private var ring: RingStatus { RingModel.shared.status }

    var body: some View {
        WelcomePage(
            step: step,
            ring: PocketRingState(ring),
            ringName: RingNames.shared.nickname(for: ring.advertisedName) ?? ring.advertisedName,
            canType: canType,
            model: local.states[kind] ?? .missing,
            said: said,
            action: action,
            isReady: isReady,
            next: advance,
            skip: skip
        )
        // No `ignoresSafeArea` here: the page keeps its size under the hidden title bar and
        // its ground alone runs up behind it. (With it, a bare strip showed at the foot.)
        .frame(width: WelcomeMetrics.window.width, height: WelcomeMetrics.window.height)
        .museAnimation(MuseMotion.smooth, value: step)
        .museAnimation(MuseMotion.smooth, value: said)
        .onAppear { DockPresence.opened() }
        .onDisappear { DockPresence.closed() }
        // macos doesn't say when accessibility is switched on: look once a second.
        .task {
            while !Task.isCancelled {
                canType = TextInserter.canType
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: local.states) { _, states in
            // It landed: it's the one that hears from the next hold, as when picked in the panel.
            guard local.wanted == kind, states[kind] == .ready else { return }
            local.wanted = nil
            MacSpeech.model = MacSpeech.Model(kind)
            Task { await MacSpeech.prepare() }
        }
        .onChange(of: dictation.lastWords) { _, words in
            if step == .firstHold, !words.isEmpty { said = words }
        }
    }

    // MARK: - Each page's button

    private var action: String? {
        switch step {
        case .typing: canType ? "next" : nil
        case .firstHold: said == nil ? "done" : nil
        default: nil
        }
    }

    /// The ring page waits for the ring; the last page for a first hold.
    private var isReady: Bool {
        switch step {
        case .ring: ring.isLinked
        case .model: local.isReady(kind)
        case .firstHold: said != nil
        default: true
        }
    }

    /// A way past a page that is waiting: the ring isn't here, or settings can come later.
    private var skip: (() -> Void)? {
        switch step {
        case .ring where !ring.isLinked: { go(to: .typing) }
        case .typing where !canType: { go(to: .model) }
        // The download carries on behind; apple's dictation hears until it lands.
        case .model where !local.isReady(kind): { go(to: .firstHold) }
        case .firstHold where said == nil: { finish() }
        default: nil
        }
    }

    private func advance() {
        switch step {
        case .hello:
            // Started now, so it is mostly here by the page that shows it.
            if !local.isReady(kind) { local.download(kind) }
            go(to: .ring)
        case .ring: go(to: .typing)
        case .typing:
            if canType { go(to: .model) } else { TextInserter.askToType() }
        case .model: go(to: .firstHold)
        case .firstHold: finish()
        }
    }

    private func go(to next: WelcomeStep) {
        step = next
        guard next == .ring, !ring.isLinked else { return }
        // The same two things the panel's words do: set a ring up, or look for the one it knows.
        if ring.link == .notSetUp {
            watch.setUp()
        } else {
            RingActions.live(openFirmware: {}).lookForIt()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        UserDefaults.standard.removeObject(forKey: "welcome")
        dismissWindow(id: Self.id)
    }
}
