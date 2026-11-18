#if DEBUG
import SwiftUI

/// Pictures of the first run, from made-up state: `MuseoMac -renderDuo <folder> -duoOnly welcome`.
enum WelcomeShots {
    static var all: [DuoShot] {
        let size = WelcomeMetrics.window
        return [
            DuoShot("welcome-1", size: size) { WelcomePage(step: .hello) },
            DuoShot("welcome-2", size: size) { WelcomePage(step: .ring, ring: .linked(battery: 82), ringName: "Museo_bd27") },
            DuoShot("welcome-3", size: size) { WelcomePage(step: .typing, canType: false, action: "open settings", skip: {}) },
            DuoShot("welcome-model", size: size) { WelcomePage(step: .model, model: .downloading(0.31), timeLeft: "about 2 minutes left", isReady: false, skip: {}) },
            DuoShot("welcome-pick", size: size) {
                WelcomePage(step: .ring, nearby: [
                    NearbyRing(id: "a", name: "Museo_bd27", nearness: NearbyRing.nearness(rssi: -44)),
                    NearbyRing(id: "b", name: "Museo_47cf", nearness: NearbyRing.nearness(rssi: -63)),
                    NearbyRing(id: "c", name: "Museo_9e10", nearness: NearbyRing.nearness(rssi: -81)),
                ], isReady: false, skip: {})
            },
            DuoShot("welcome-4", size: CGSize(width: 980, height: 700)) { firstHold },
        ]
    }

    /// The last page under the notch, the island holding the same words as they form.
    private static var firstHold: some View {
        let said = "this is the first thing i ever said to my mac"
        return ZStack(alignment: .top) {
            MuseColor.groundDeep.mix(with: MuseColor.ink, by: 0.14)
            WelcomePage(step: .firstHold, said: said)
                .frame(width: WelcomeMetrics.window.width, height: WelcomeMetrics.window.height)
                .clipShape(RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous))
                .museElevation(.e2)
                .padding(.top, 112)
            // A stand in for the real island (`NotchIsland`), which lives above every window.
            HStack(spacing: MuseSpacing.sm) {
                PocketHalftoneRing(size: 18, ink: MuseColor.ground, light: .white, dots: 17)
                Text(said)
                    .font(MuseFont.lora(15))
                    .foregroundStyle(MuseColor.ground)
            }
            .padding(.horizontal, MuseSpacing.xl)
            .frame(height: 64, alignment: .bottom)
            .padding(.bottom, MuseSpacing.sm)
            .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22, style: .continuous))
        }
    }
}
#endif
