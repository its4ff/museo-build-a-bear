import SwiftUI
import MuseoKit

/// Hello: the name, what it does in a sentence, and the way in. No account, nothing to
/// allow. Without a ring, "later" (top right) leads home.
struct OnboardingHello: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: "\(AppConfig.appName).",
            line: "a new interface for your thoughts.",
            aside: "what you say becomes words on this iphone. it stays here unless your code sends it."
        ) {
            MuseRingArt(width: 240)
        } buttons: {
            OnboardingPrimary(primaryTitle, haptic: .medium) { model.begin() }
        }
    }

    /// A ring that's already set up skips setup.
    private var primaryTitle: String {
        model.ring.link == .notSetUp ? "set up your ring" : "continue"
    }
}
