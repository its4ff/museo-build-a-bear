import SwiftUI

/// The first run, in five quiet pages on the dune: hello, your ring, letting museo type,
/// the speech model's one download, and one first hold. One thing to do on each. Drawn from what it is given, so the pages
/// can be pictured before they are wired to the ring.
nonisolated enum WelcomeStep: Int, CaseIterable, Sendable {
    case hello, ring, typing, model, firstHold

    var title: String {
        switch self {
        case .hello: "museo for mac."
        case .ring: "wake your ring."
        case .typing: "let museo type for you."
        case .model: "one download, once."
        case .firstHold: "hold, and say anything."
        }
    }

    var line: String {
        switch self {
        case .hello: "hold your ring and talk. the words land wherever you're working."
        case .ring: "click it once. museo finds it by itself."
        case .typing: "macos asks once. it's how your words land in other apps. what you say is turned into words on this mac."
        case .model: "parakeet ultra hears you best, and it stays on this mac. 650 mb."
        case .firstHold: "watch the notch while you talk. let go when you're done."
        }
    }

    var action: String {
        switch self {
        case .hello: "begin"
        case .ring: "next"
        case .typing: "open settings"
        case .model: "next"
        case .firstHold: "done"
        }
    }
}

nonisolated enum WelcomeMetrics {
    static let window = CGSize(width: 760, height: 540)
    static let mark: CGFloat = 132
    static let markDots = 45
    static let smallMark: CGFloat = 64
    static let smallMarkDots = 31
    static let title: CGFloat = 44
    static let titleTracking: CGFloat = -1.2
    static let measure: CGFloat = 420
    static let button = CGSize(width: 168, height: 44)
    static let pill: CGFloat = 268
    static let said: CGFloat = 28
    static let saidLeading: CGFloat = 8
    static let dot: CGFloat = 6
    static let bar = CGSize(width: 260, height: 4)
    static let check: CGFloat = 12
    /// The dune, a touch quieter than the library's: there is almost nothing on the page.
    static let dune = 0.55
    /// The button while the page waits on the ring or on macos.
    static let waiting = 0.45
}

struct WelcomePage: View {
    let step: WelcomeStep
    /// The ring, once it has been found.
    var ring: PocketRingState = .away
    var ringName: String?
    /// What macos has allowed so far.
    var canType = false
    /// How the speech model's download stands.
    var model = LocalSpeech.State.missing
    /// The first words said, once there are some.
    var said: String?
    /// The button's words when they differ from the step's own, and whether it can be pressed.
    var action: String?
    var isReady = true
    var next: () -> Void = {}
    /// A quiet way past a page that is waiting on something, when there is one.
    var skip: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            middle
                .frame(height: WelcomeMetrics.mark + MuseSpacing.md)
            VStack(spacing: MuseSpacing.sm) {
                Text(heard ?? step.title)
                    .font(MuseFont.lora(heard == nil ? WelcomeMetrics.title : WelcomeMetrics.said))
                    .lineSpacing(WelcomeMetrics.saidLeading)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: WelcomeMetrics.measure + MuseSpacing.sectionLabel * 2)
                    .tracking(WelcomeMetrics.titleTracking)
                    .foregroundStyle(MuseColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(heard == nil ? step.line : "that's all there is to it. museo lives in your menu bar.")
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink70)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: WelcomeMetrics.measure)
            }
            .padding(.top, MuseSpacing.section)
            if step == .typing {
                allowed(canType ? "museo can type into your apps" : "accessibility › museo, switched on", canType)
                    .padding(.top, MuseSpacing.xl)
            }
            if step == .model {
                download
                    .padding(.top, MuseSpacing.xl)
            }
            Button(action: next) {
                Text(action ?? step.action)
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ground)
                    .frame(width: WelcomeMetrics.button.width, height: WelcomeMetrics.button.height)
                    .background(MuseColor.primaryGradient, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(MusePressStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!isReady)
            .opacity(isReady ? 1 : WelcomeMetrics.waiting)
            .padding(.top, MuseSpacing.section + MuseSpacing.xs)
            Button {
                skip?()
            } label: {
                Text("not now")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .frame(height: MuseSpacing.section)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, MuseSpacing.xs)
            // Its room is always kept, so the page doesn't shift when it comes and goes.
            .opacity(skip == nil ? 0 : 1)
            .disabled(skip == nil)
            .accessibilityHidden(skip == nil)
            Spacer(minLength: 0)
            dots
                .padding(.bottom, MuseSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PocketGround(strength: WelcomeMetrics.dune, stipple: LibraryWindow.ground.stipple, fine: true) }
        .preferredColorScheme(.light)
    }

    /// The one thing each page shows above its title.
    @ViewBuilder
    private var middle: some View {
        switch step {
        case .hello:
            PocketHalftoneRing(size: WelcomeMetrics.mark, ink: MuseColor.moss, dots: WelcomeMetrics.markDots)
                .accessibilityHidden(true)
        case .ring:
            VStack(spacing: MuseSpacing.sm) {
                Spacer(minLength: 0)
                DuoRingPill(state: ring)
                    .frame(width: WelcomeMetrics.pill)
                    .allowsHitTesting(false)
                Text(found ? "found \(ringName ?? "it")." : "looking…")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
        case .typing, .model:
            mark(light: nil)
        case .firstHold:
            mark(light: .white)
        }
    }

    /// The ring's mark, smaller, sitting just above the title. Lit white while it listens.
    private func mark(light: PocketRingLight?) -> some View {
        VStack {
            Spacer(minLength: 0)
            PocketHalftoneRing(size: WelcomeMetrics.smallMark, ink: MuseColor.moss, light: light, dots: WelcomeMetrics.smallMarkDots)
                .accessibilityHidden(true)
        }
    }

    /// Their first words take the title's place once they are said.
    private var heard: String? { step == .firstHold ? said : nil }

    private var found: Bool {
        if case .away = ring { return false }
        return true
    }

    private func allowed(_ what: String, _ isAllowed: Bool) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            Image(systemName: isAllowed ? "checkmark.circle.fill" : "circle")
                .font(MuseFont.symbol(WelcomeMetrics.check + MuseSpacing.xxs))
                .foregroundStyle(isAllowed ? MuseColor.moss : MuseColor.ink55)
                .accessibilityLabel(isAllowed ? "allowed" : "not yet")
            Text(what)
                .font(MuseType.body)
                .foregroundStyle(isAllowed ? MuseColor.ink : MuseColor.ink70)
        }
    }

    /// The download as one thin line filling in moss, and a word beside it.
    private var download: some View {
        let share: Double = switch model {
        case .ready: 1
        case .downloading(let share): share
        case .missing, .failed: 0
        }
        let word = switch model {
        case .ready: "it's here"
        case .downloading(let share): "\(Int(share * 100))%"
        case .missing: "starting…"
        case .failed: "it didn't come down. it will try again from the menu."
        }
        return VStack(spacing: MuseSpacing.xs) {
            Capsule()
                .fill(MuseColor.ink.opacity(0.1))
                .frame(width: WelcomeMetrics.bar.width, height: WelcomeMetrics.bar.height)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(MuseColor.primaryGradient)
                        .frame(width: max(WelcomeMetrics.bar.height, WelcomeMetrics.bar.width * share))
                }
                .accessibilityHidden(true)
            Text(word)
                .font(MuseType.meta)
                .monospacedDigit()
                .foregroundStyle(model == .failed ? MuseColor.clay : MuseColor.ink55)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    /// Where you are in the pages.
    private var dots: some View {
        HStack(spacing: MuseSpacing.xs) {
            ForEach(WelcomeStep.allCases, id: \.self) { each in
                Circle()
                    .fill(each == step ? MuseColor.moss : MuseColor.ink.opacity(0.16))
                    .frame(width: WelcomeMetrics.dot, height: WelcomeMetrics.dot)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("page \(step.rawValue + 1) of \(WelcomeStep.allCases.count)")
    }
}
