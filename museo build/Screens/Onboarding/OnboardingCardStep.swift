import SwiftUI

/// The last beat: hold and double click once more, and "start". The home's question mark
/// opens the whole card.
struct OnboardingCardStep: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: "that's museo.",
            line: "find it again on the home, behind the question mark."
        ) {
            RingCheatCard(essentials: true)
        } buttons: {
            OnboardingPrimary("start", haptic: .done) { model.start() }
        }
    }
}
