import Foundation
import SwiftUI
import MuseoKit

/// The first run: hello, set up, hold, double click, the card. Each step is one breath.
///
/// It draws whatever state `model` is in and sends taps back to it; nothing here touches
/// the ring. The live app wraps it in `OnboardingCover` (which feeds the model from the
/// ring); lab screens hand it a model staged in any state.
struct OnboardingView: View {
    let model: Onboarding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            MuseBackground()
            VStack(spacing: 0) {
                topBar
                ZStack {
                    page
                        .id(model.step)
                        .transition(stepTransition)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .museAnimation(MuseMotion.gentle, value: model.step)
    }

    @ViewBuilder
    private var page: some View {
        switch model.step {
        case .hello: OnboardingHello(model: model)
        case .setUp: OnboardingSetUpStep(model: model)
        case .stream: OnboardingStreamStep(model: model)
        case .memory: OnboardingMemoryStep(model: model)
        case .card: OnboardingCardStep(model: model)
        }
    }

    /// The next step slides in from the right as the last one leaves to the left. Under
    /// Reduce Motion, a plain fade.
    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: MuseSpacing.xl)),
            removal: .opacity.combined(with: .offset(x: -MuseSpacing.xl))
        )
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: MuseSpacing.sm) {
            if model.step != .hello {
                OnboardingProgress(step: model.step)
                    .transition(.opacity)
            }
            Spacer(minLength: MuseSpacing.sm)
            if model.step != .card {
                Button {
                    MuseHaptics.play(.soft)
                    model.later()
                } label: {
                    Text("later")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(minWidth: MuseTopChrome.hitTarget, minHeight: MuseTopChrome.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.97))
                .accessibilityHint("closes this and opens your muses")
                .transition(.opacity)
            }
        }
        .frame(minHeight: MuseTopChrome.hitTarget)
        .padding(.horizontal, MuseSpacing.page)
        .padding(.top, MuseSpacing.xxs)
    }
}

// MARK: - Progress

/// Four small marks for set up, hold, double click and the card: the current one long,
/// the ones done in ink, the ones ahead faint.
struct OnboardingProgress: View {
    let step: Onboarding.Step

    private static let steps: [Onboarding.Step] = [.setUp, .stream, .memory, .card]

    var body: some View {
        let index = Self.steps.firstIndex(of: step) ?? 0
        HStack(spacing: MuseSpacing.xxs + 2) {
            ForEach(Self.steps.indices, id: \.self) { position in
                Capsule()
                    .fill(position <= index ? MuseColor.ink : MuseColor.ink.opacity(0.16))
                    .frame(width: position == index ? 18 : 6, height: 6)
            }
        }
        .museAnimation(MuseMotion.smooth, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("step \(index + 1) of \(Self.steps.count)")
    }
}

#Preview("onboarding · hello") {
    OnboardingView(model: Onboarding(ring: .notSetUp, actions: .preview, drivesItself: false))
}

#Preview("onboarding · streaming") {
    OnboardingView(model: Onboarding(
        ring: .linked, actions: .preview, step: .stream,
        stream: .listening(since: Date(timeIntervalSinceNow: -4)), drivesItself: false
    ))
}
