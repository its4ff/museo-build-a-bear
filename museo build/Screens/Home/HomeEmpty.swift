import SwiftUI
import MuseoKit

/// The home before the first muse: the orb, "nothing here yet" (or, before the ring is set
/// up, what to do first), one line on how a muse is made, and a quiet promise at the foot of
/// the page. Before setup it carries the one primary button. The simulator has no bluetooth,
/// so there the primary loads the sample muses instead (delete everything clears them). Fills
/// the space under the title so the column sits in the middle and the promise rests at the
/// bottom.
struct HomeEmpty: View {
    let status: RingStatus
    /// The height to fill (the visible page under the title). Grows past it for large text.
    var minHeight: CGFloat = 0
    let onSetUp: () -> Void
    /// Fills the library with the sample muses (`MusePipeline.loadSamples()`).
    let onSamples: () -> Void

    var body: some View {
        HomeEmptyStage(minHeight: minHeight) {
            column
            Text("your voice becomes text on this iphone.")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, MuseSpacing.md)
        }
    }

    private var column: some View {
        VStack(spacing: MuseSpacing.md) {
            MuseOrb(size: MuseOrb.Size.voice)
                .padding(.bottom, MuseSpacing.xs)
            Text(headline)
                .font(MuseType.title)
                .tracking(MuseType.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .padding(.horizontal, MuseSpacing.xs)
                .accessibilityAddTraits(.isHeader)
            Text(line)
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MuseSpacing.xs)
            // The button fills the page gutter, in line with the chips above and the ring
            // sheet's setup button; only the words sit in a little.
            if Self.inSimulator {
                primary("load the samples", action: onSamples)
            } else if status.link == .notSetUp {
                primary("set up your ring", action: onSetUp)
                    .disabled(status.isSettingUp)
            }
        }
        .frame(maxWidth: .infinity)
        .museAnimation(MuseMotion.smooth, value: status.link)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            MuseHaptics.play(.medium)
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MuseButtonStyle(.primary))
        .padding(.top, MuseSpacing.md)
        .transition(.opacity)
    }

    /// No bluetooth here, so no ring: the samples stand in for it.
    static var inSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// Before setup, what to do first. After it the status line above says how the ring
    /// is, so this just says the library is empty.
    var headline: String {
        if Self.inSimulator { return "nothing here yet" }
        return status.link == .notSetUp ? "set up your ring to begin" : "nothing here yet"
    }

    /// How a muse is made, picking up from the headline.
    var line: String {
        if Self.inSimulator { return "the simulator has no bluetooth. load the samples to see a full library." }
        return status.link == .notSetUp
            ? "then hold it and speak. every muse you make lives here."
            : "hold your ring and speak. every muse you make lives here."
    }
}

/// Places the column in the optical middle of the space above the footer and pins the
/// footer to the bottom. Grows taller than `minHeight` when the text needs it, so nothing
/// is ever cut off.
nonisolated private struct HomeEmptyStage: Layout {
    var minHeight: CGFloat
    /// Breath above the column and between the column and the footer.
    var gap: CGFloat = MuseSpacing.sectionLabel
    /// Slightly above center reads as centered.
    var opticalCenter: CGFloat = 0.44

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let natural = heights.reduce(0, +) + gap * CGFloat(subviews.count)
        return CGSize(width: width, height: max(minHeight, natural))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let column = subviews.first else { return }
        let offer = ProposedViewSize(width: bounds.width, height: nil)
        let columnHeight = column.sizeThatFits(offer).height
        var footerHeight: CGFloat = 0
        if subviews.count > 1, let footer = subviews.last {
            footerHeight = footer.sizeThatFits(offer).height
            footer.place(at: CGPoint(x: bounds.minX, y: bounds.maxY - footerHeight), proposal: offer)
        }
        let room = bounds.height - footerHeight - gap
        let top = max(gap, (room - columnHeight) * opticalCenter)
        column.place(at: CGPoint(x: bounds.minX, y: bounds.minY + top), proposal: offer)
    }
}

#Preview("empty home") {
    ScrollView {
        HomeEmpty(status: .notSetUp, minHeight: 640, onSetUp: {}, onSamples: {})
            .padding(.horizontal, MuseSpacing.page)
    }
    .scrollIndicators(.hidden)
    .background { MuseBackground() }
}
