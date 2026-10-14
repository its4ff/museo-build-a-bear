import SwiftUI
import MuseoKit

/// Set up: iOS's accessory sheet comes up over this, and the ring in the well turns from
/// a dashed outline into a moss band as it links. "linked." holds a beat, then hold.
struct OnboardingSetUpStep: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: title,
            line: line,
            note: note
        ) {
            VStack(spacing: MuseSpacing.sm) {
                OnboardingRingWell(glow: model.setUp == .linked ? MuseColor.moss300 : nil, breathes: isWorking) {
                    MuseRingGlyph(
                        fill: model.setUp == .linked ? battery : nil,
                        style: model.setUp == .linked ? .linked : .setup,
                        breathing: isWorking,
                        size: 52
                    )
                }
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
            if model.setUp != .linked {
                MuseQuietButton("skip for now") { model.next() }
            }
        }
    }

    private var isWorking: Bool {
        model.setUp == .choosing || model.setUp == .joining
    }

    /// The band fills with the battery once there's a reading.
    private var battery: Double {
        model.ring.battery.map { Double($0) / 100 } ?? 1
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
