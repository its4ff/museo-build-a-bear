import SwiftUI

/// The last beat: the cheat card, and "start". The home's question mark opens the same card.
struct OnboardingCardStep: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: "that's museo.",
            line: "find it again on the home, behind the question mark."
        ) {
            RingCheatCard()
        } buttons: {
            OnboardingPrimary("start", haptic: .done) { model.start() }
        }
    }
}
