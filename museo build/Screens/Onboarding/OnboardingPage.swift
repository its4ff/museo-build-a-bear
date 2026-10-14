import SwiftUI

/// One onboarding step: a big Lora line, a sentence under it, an optional recipe line
/// ("hold · white light · …"), the stage in the middle of what's left, a note under it,
/// and the step's buttons pinned at the bottom.
///
/// The column fills the screen when it fits and scrolls when it doesn't (large text).
struct OnboardingPage<Stage: View, Buttons: View>: View {
    let title: String
    var line: String?
    var aside: String?
    /// A quiet line under the stage: a nudge when something didn't land.
    var note: String?
    /// "hold · white light · straight to this iphone".
    var recipe: RingRecipeLine?
    let stage: Stage
    let buttons: Buttons

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        line: String? = nil,
        aside: String? = nil,
        note: String? = nil,
        recipe: RingRecipeLine? = nil,
        @ViewBuilder stage: () -> Stage,
        @ViewBuilder buttons: () -> Buttons
    ) {
        self.title = title
        self.line = line
        self.aside = aside
        self.note = note
        self.recipe = recipe
        self.stage = stage()
        self.buttons = buttons()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                column(fills: true)
                buttonBar
            }
            // Too tall for the screen (the card, large text): it scrolls, softly, under
            // the buttons.
            ScrollView {
                column(fills: false)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .safeAreaBar(edge: .bottom, spacing: 0) { buttonBar }
        }
        // The big line is the news ("linked.", "streamed in."): say it when it changes.
        .onChange(of: title) { _, now in
            AccessibilityNotification.Announcement(now).post()
        }
    }

    private var buttonBar: some View {
        VStack(spacing: MuseSpacing.xxs) {
            buttons
        }
        // The same room whatever the step shows, so nothing above jumps.
        .frame(maxWidth: .infinity, minHeight: MuseTopChrome.hitTarget * 2 + MuseSpacing.xxs, alignment: .bottom)
        .padding(.horizontal, MuseSpacing.page)
        .padding(.bottom, MuseSpacing.xs)
    }

    private func column(fills: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            words
                .padding(.top, MuseSpacing.lg)
            if fills {
                Spacer(minLength: MuseSpacing.section)
            } else {
                Color.clear.frame(height: MuseSpacing.section)
            }
            VStack(spacing: MuseSpacing.md) {
                stage
                if let note {
                    Text(note)
                        .font(MuseType.body)
                        .lineSpacing(MuseType.bodyLineSpacing)
                        .foregroundStyle(MuseColor.ink70)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                        .id(note)
                }
            }
            .frame(maxWidth: .infinity)
            .museAnimation(MuseMotion.dissolve, value: note)
            if fills {
                Spacer(minLength: MuseSpacing.section)
            } else {
                Color.clear.frame(height: MuseSpacing.section)
            }
        }
        .padding(.horizontal, MuseSpacing.page)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            Text(title)
                .font(MuseType.display)
                .tracking(MuseType.displayTracking)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            if let line {
                Text(line)
                    .font(MuseType.body)
                    .lineSpacing(MuseType.bodyLineSpacing)
                    .foregroundStyle(MuseColor.ink70)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            if let aside {
                Text(aside)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let recipe {
                recipe
                    .padding(.top, MuseSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .museAnimation(MuseMotion.dissolve, value: title)
        .museAnimation(MuseMotion.dissolve, value: line)
    }
}

// MARK: - Buttons

/// The one primary button of a step, full width.
struct OnboardingPrimary: View {
    let title: String
    var haptic: MuseHaptics.Kind = .soft
    let action: () -> Void

    init(_ title: String, haptic: MuseHaptics.Kind = .soft, action: @escaping () -> Void) {
        self.title = title
        self.haptic = haptic
        self.action = action
    }

    var body: some View {
        Button {
            MuseHaptics.play(haptic)
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MuseButtonStyle(.primary))
        .transition(.opacity)
    }
}

// MARK: - The ring in a well

/// Sizes the onboarding's pieces share.
nonisolated enum OnboardingMetrics {
    /// The ring's well, and the least room a step's stage takes.
    static let well: CGFloat = 120
}

/// The ring on its own, in an inset well: the setup glyph, or the ring with its light.
struct OnboardingRingWell<Content: View>: View {
    /// A soft halo while the ring is doing something (listening, recording).
    var glow: Color?
    /// A slow breath, inviting a press.
    var breathes: Bool
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    init(glow: Color? = nil, breathes: Bool = false, @ViewBuilder content: () -> Content) {
        self.glow = glow
        self.breathes = breathes
        self.content = content()
    }

    var body: some View {
        let well = Circle()
            .fill(MuseColor.inset)
            .overlay { Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75) }
            .shadow(color: (glow ?? .clear).opacity(0.45), radius: glow == nil ? 0 : MuseSpacing.lg)
            .overlay { content }
            .frame(width: OnboardingMetrics.well, height: OnboardingMetrics.well)
        Group {
            if breathes && !reduceMotion {
                well.phaseAnimator([false, true]) { view, out in
                    view.scaleEffect(out ? 1.03 : 1)
                } animation: { _ in
                    .easeInOut(duration: 2.2)
                }
            } else {
                well
            }
        }
        .animation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion), value: glow)
        .accessibilityHidden(true)
    }
}
