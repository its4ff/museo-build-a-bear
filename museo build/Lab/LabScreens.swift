#if DEBUG
import SwiftUI
import MuseoKit

// Lab-only screens: the arrival choreography on home, the ring glyph sheet, and the build
// stack for pushed pages. Everything else in the lab is a real screen fed fixtures.

// MARK: - Home, a muse arriving

/// The home as a muse lands: a beat after launch the ring's muse settles in as the first
/// tile, "transcribing…", its words land and their start types into the title slot, then the
/// model's title cross-fades into its place.
struct LabArrivingHome: View {
    @Environment(MuseStore.self) private var store

    var body: some View {
        HomeView(sort: .newest)
            .task { await arrive() }
    }

    private func arrive() async {
        try? await Task.sleep(for: .milliseconds(700))
        store.insert(LabFixtures.arriving(state: .transcribing))
        try? await Task.sleep(for: .milliseconds(1_500))
        store.update(LabFixtures.arrivingID) { muse in
            let done = LabFixtures.arriving(state: .complete)
            muse.transcript = done.transcript
            muse.language = done.language
            muse.wordConfidence = done.wordConfidence
            muse.textModel = done.textModel
            muse.transcriptionState = .complete
        }
        // The title comes from the on-device model once the words are in.
        try? await Task.sleep(for: .milliseconds(4_800))
        store.update(LabFixtures.arrivingID) { muse in
            muse.title = LabFixtures.arrivingTitle
        }
    }
}

// MARK: - Ring glyphs

/// Every `MuseRingGlyph` style at a few fills, the three `RingButton` styles, and every
/// `RingStatus` fixture in all three, each labelled with its Swift name.
struct LabRingGlyphs: View {
    private let fills: [Double?] = [1, 0.6, 0.2, nil]

    var body: some View {
        ZStack {
            MuseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: MuseSpacing.sectionLabel) {
                    MuseHeader(
                        eyebrow: "lab",
                        title: "ring glyphs.",
                        subtitle: "the gauge in every style, the three ring buttons, and every ring status.",
                        titleSize: 28
                    )
                    styles
                    buttons
                    statuses
                }
                .padding(.horizontal, MuseSpacing.page)
                .padding(.top, MuseSpacing.xl)
                .padding(.bottom, MuseSpacing.sectionLabel)
            }
            .scrollIndicators(.hidden)
            .museBottomBlur()
        }
        // Paper under the status bar, fading into the page, so rows never run under the clock.
        .overlay(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: MuseColor.groundWash, location: 0),
                    .init(color: MuseColor.groundWash.opacity(0.92), location: 0.7),
                    .init(color: MuseColor.groundWash.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: MuseSpacing.xl)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: Styles

    private var styles: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("gauge styles") {
                LabCode("MuseRingGlyph.Style")
            }
            Text(verbatim: "fill 1 · 0.6 · 0.2 · nil, then a count, then attention")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
            ForEach(MuseRingGlyph.Style.allCases, id: \.self) { style in
                VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                    LabCode(".\(style.rawValue)")
                    HStack(spacing: MuseSpacing.xs) {
                        ForEach(fills.indices, id: \.self) { index in
                            plate(style) {
                                MuseRingGlyph(fill: fills[index], style: style, breathing: false)
                            }
                        }
                        plate(style) {
                            MuseRingGlyph(fill: 0.4, style: style, count: 3)
                        }
                        plate(style) {
                            MuseRingGlyph(fill: 0.8, style: style, attention: true)
                        }
                    }
                }
            }
        }
    }

    /// The glyph on its 38pt plate, the way `RingButtonFace` draws it.
    private func plate<Glyph: View>(_ style: MuseRingGlyph.Style, @ViewBuilder glyph: () -> Glyph) -> some View {
        glyph()
            .frame(width: MuseTopChrome.circle, height: MuseTopChrome.circle)
            .background {
                Circle()
                    .fill(style.plate)
                    .overlay {
                        if style.platesHairline {
                            Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                        }
                    }
            }
            .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("ring buttons") {
                LabCode("RingButtonStyle")
            }
            ForEach(RingButtonStyle.allCases) { style in
                HStack(spacing: MuseSpacing.md) {
                    LabCode(".\(style.rawValue)")
                        .frame(width: 104, alignment: .leading)
                    RingButton(status: .linked, style: style) {}
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Statuses

    private var statuses: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
            MuseSectionHeader("ring statuses") {
                LabCode("RingStatus.fixtures")
            }
            ForEach(RingStatus.fixtures, id: \.name) { fixture in
                VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                        LabCode(".\(fixture.name)")
                        Text(fixture.status.shortLine)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                            .lineLimit(1)
                    }
                    HStack(spacing: MuseSpacing.sm) {
                        ForEach(RingButtonStyle.allCases) { style in
                            RingButton(status: fixture.status, style: style) {}
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

/// A Swift name, set in mono the way the design kit labels things.
private struct LabCode: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(MuseType.code)
            .foregroundStyle(MuseColor.ink70)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
#endif
