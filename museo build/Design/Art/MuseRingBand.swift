import SwiftUI

/// The ring's band up close, as the booklet draws it: the stone, the light window with the
/// light and the mic. White while it streams, amber while it records to itself, off when
/// neither. While `lit` the light breathes a soft glow, as the ring's does (still under
/// Reduce Motion). Onboarding's hold and double click steps use it. Decorative.
struct MuseRingBand: View {
    var light: RingLight.Kind = .white
    var lit = false
    var height: CGFloat = 240

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the light sits in the booklet's band, as a fraction of its width and height.
    private static let lightCenter = UnitPoint(x: 0.508, y: 0.631)
    /// The booklet's band, width over height.
    private static let aspect: CGFloat = 60.0 / 183.0

    var body: some View {
        let width = height * Self.aspect
        let glow = width * 0.32
        Image(asset)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                if lit {
                    halo(size: glow)
                        .offset(x: Self.lightCenter.x * width - glow / 2, y: Self.lightCenter.y * height - glow / 2)
                }
            }
            .accessibilityHidden(true)
    }

    private var asset: String {
        guard lit else { return "BookletBandOff" }
        return light == .white ? "BookletBandStream" : "BookletBandRecord"
    }

    /// A soft glow around the light, breathing.
    private func halo(size: CGFloat) -> some View {
        let color = light == .white ? MuseColor.composer : MuseColor.ringAmber
        let dot = Circle().fill(color).frame(width: size, height: size).blur(radius: size / 3)
        return Group {
            if reduceMotion {
                dot.opacity(0.5)
            } else {
                dot.phaseAnimator([false, true]) { view, on in
                    view.opacity(on ? 0.75 : 0.2)
                } animation: { _ in
                    .easeInOut(duration: 1.2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    HStack(spacing: MuseSpacing.section) {
        MuseRingBand(light: .white, lit: true)
        MuseRingBand(light: .amber, lit: true)
        MuseRingBand(light: .white, lit: false)
    }
    .padding(MuseSpacing.page)
    .background { MuseBackground() }
}
