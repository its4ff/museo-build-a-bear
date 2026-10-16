import SwiftUI
import MuseoKit

/// Set up: iOS's accessory sheet comes up over this, and the booklet's ring (the one hello
/// showed) breathes while it joins and settles with a soft moss glow as it links.
/// "linked." holds a beat, then hold.
struct OnboardingSetUpStep: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: title,
            line: line,
            note: note
        ) {
            VStack(spacing: MuseSpacing.sm) {
                OnboardingSetUpRing(linked: model.setUp == .linked, working: isWorking)
                Text(caption)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                    .contentTransition(.opacity)
            }
            .museAnimation(MuseMotion.smooth, value: model.setUp)
        } buttons: {
            if let primary {
                OnboardingPrimary(primary, haptic: .medium) { model.setUpRing() }
            }
            // Not while the sheet is coming up or the ring is joining: a second tap on the
            // last button would land here and skip to the end.
            if canSkip {
                MuseQuietButton("skip for now") { model.next() }
            }
        }
    }

    private var isWorking: Bool {
        model.setUp == .choosing || model.setUp == .joining
    }

    private var canSkip: Bool {
        switch model.setUp {
        case .ready, .nothing, .away, .bluetoothOff: true
        case .choosing, .joining, .linked: false
        }
    }

    // MARK: Words

    private var title: String {
        switch model.setUp {
        case .ready: "set up your ring."
        case .choosing: "choosing your ring…"
        case .joining: "joining…"
        case .linked: "linked."
        case .away: "bring your ring close."
        case .bluetoothOff: "bluetooth is off."
        case .nothing: "no ring yet."
        }
    }

    private var line: String {
        switch model.setUp {
        case .ready: "keep museo close to your iphone."
        case .choosing: "choose museo in the sheet."
        case .joining: "keep it close. this takes a few seconds."
        case .linked: "it links on its own whenever it's near."
        case .away: "it's set up. it links on its own whenever it's near."
        case .bluetoothOff: "turn on bluetooth in control center."
        case .nothing(let note): note
        }
    }

    /// Under the well: the ring as this iphone sees it.
    private var caption: String {
        switch model.setUp {
        case .linked: model.ring.deviceLine
        case .joining: model.ring.advertisedName ?? model.ring.name
        default: model.ring.name
        }
    }

    /// The tip for a ring setup can't find, unless the kit's note already gave one.
    private var note: String? {
        guard case .nothing(let reason) = model.setUp, !reason.contains("6 to 7"), !reason.contains("6 times") else {
            return nil
        }
        return "can't find it? click it 6 times so it forgets its old phone."
    }

    private var primary: String? {
        switch model.setUp {
        case .ready: "set up your ring"
        case .nothing: "try again"
        case .away: "look for it"
        case .choosing, .joining, .linked, .bluetoothOff: nil
        }
    }
}

// MARK: - The ring

/// The booklet's ring: faint until it links, breathing while it joins, then full with a
/// soft moss glow under it.
private struct OnboardingSetUpRing: View {
    let linked: Bool
    let working: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let width: CGFloat = 220

    var body: some View {
        let art = MuseRingArt(width: Self.width)
            .opacity(linked ? 1 : 0.6)
            .background {
                Ellipse()
                    .fill(MuseColor.moss300)
                    .frame(width: Self.width * 0.8, height: Self.width * 0.3)
                    .blur(radius: MuseSpacing.xl)
                    .offset(y: Self.width * 0.18)
                    .opacity(linked ? 0.45 : 0)
            }
        Group {
            if working && !reduceMotion {
                art.phaseAnimator([false, true]) { view, out in
                    view.scaleEffect(out ? 1.03 : 1).opacity(out ? 1 : 0.8)
                } animation: { _ in
                    .easeInOut(duration: 2.2)
                }
            } else {
                art
            }
        }
        .museAnimation(MuseMotion.smooth, value: linked)
        .accessibilityHidden(true)
    }
}
