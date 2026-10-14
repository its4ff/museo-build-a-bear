import SwiftUI
import MuseoKit

/// Connects an `Onboarding` to the real ring and library: `RingModel.status`, ring events
/// (`Museo.events()`) and muse events (`MuseHooks.events()`). Both streams end, and the
/// hook is cancelled, when the view goes away. Lab screens leave it off and stage the
/// model by hand.
struct OnboardingRingLink: ViewModifier {
    let model: Onboarding

    @Environment(RingModel.self) private var ring

    func body(content: Content) -> some View {
        content
            .onChange(of: ring.status, initial: true) { _, status in
                model.ringChanged(status)
            }
            .task {
                for await event in Museo.events() {
                    model.ringEvent(event)
                }
            }
            .task {
                for await event in MuseHooks.events() {
                    model.museEvent(event)
                }
            }
    }
}
