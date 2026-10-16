import SwiftUI
import MuseoKit

/// Double click to remember: the ring records to itself (amber), then the muse comes in
/// from the ring when it stops. It never clears the ring; older recordings waiting there
/// come in too, but only the new one shows here.
struct OnboardingMemoryStep: View {
    let model: Onboarding

    var body: some View {
        OnboardingPage(
            title: landed ? "kept on museo." : "double click to record on-device.",
            line: landed
                ? "it came in when your phone was near. about 3 hours fit on museo."
                : "double click to start, again to stop. no phone needed.",
            note: note,
            recipe: RingRecipeLine(gesture: .clicks(2), name: "double click", light: .amber, result: "kept on museo")
        ) {
            stage
                .frame(minHeight: OnboardingMetrics.well)
                .museAnimation(MuseMotion.drift, value: stageKey)
        } buttons: {
            if landed || model.isSlow {
                OnboardingPrimary("next") { model.next() }
            } else {
                MuseQuietButton("skip for now") { model.next() }
            }
        }
    }

    // MARK: Stage

    @ViewBuilder
    private var stage: some View {
        switch model.memory {
        case .waiting, .tooShort, .wasStreamed:
            MuseRingBand(light: .amber, lit: false)
                .transition(.opacity)
        case .recording:
            VStack(spacing: MuseSpacing.md) {
                MuseRingBand(light: .amber, lit: true)
                caption("recording on museo", "double click again to stop.")
            }
            .transition(.opacity)
        case .bringingIn:
            VStack(spacing: MuseSpacing.md) {
                OnboardingRingWell(breathes: true) {
                    MuseRingGlyph(fill: model.ring.syncProgress ?? 0, style: .linked, breathing: true, size: 52)
                }
                caption("bringing it in…", nil)
            }
            .transition(.opacity)
        case .landed(let muse):
            OnboardingMuseCard(muse: muse)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private func caption(_ title: String, _ detail: String?) -> some View {
        VStack(spacing: MuseSpacing.xxs) {
            Text(title)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
            if let detail {
                Text(detail)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    /// Changes only when the stage swaps what it shows.
    private var stageKey: Int {
        switch model.memory {
        case .waiting, .tooShort, .wasStreamed: 0
        case .recording: 1
        case .bringingIn: 2
        case .landed: 3
        }
    }

    private var landed: Bool {
        if case .landed = model.memory { return true }
        return false
    }

    // MARK: Words

    private var note: String? {
        switch model.memory {
        case .wasStreamed: return "that one streamed. to record, double click."
        case .tooShort: return "a little longer. double click, talk, then double click again."
        case .bringingIn: return model.isSlow ? "it's kept on museo. it comes in on its own." : nil
        case .waiting: return model.ring.isLinked ? nil : "bring your ring close. it links on its own."
        case .recording, .landed: return nil
        }
    }
}
