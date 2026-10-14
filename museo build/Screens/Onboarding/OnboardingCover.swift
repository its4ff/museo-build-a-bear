import SwiftUI
import MuseoKit

/// The onboarding as the live app shows it, over the home (`RootView`): one model for the
/// cover's life, fed by the ring.
struct OnboardingCover: View {
    @State private var model: Onboarding

    init(actions: RingActions, onFinish: @escaping () -> Void) {
        _model = State(initialValue: Onboarding(
            ring: RingModel.shared.status,
            actions: actions,
            onFinish: onFinish
        ))
    }

    var body: some View {
        OnboardingView(model: model)
            .modifier(OnboardingRingLink(model: model))
    }
}

// MARK: - Seeing it again

extension EnvironmentValues {
    /// Opens the onboarding again (build › about). `RootView` sets it; elsewhere it does
    /// nothing.
    @Entry var museShowOnboarding: () -> Void = {}
}
