import SwiftUI
import UIKit
import MuseoKit

/// Build › look › design kit: every token and component the app is made of, each labelled
/// with its Swift name so a builder (or their agent) can copy it. Self-contained: it only
/// uses `Design/`, so it works anywhere (a sheet, a pushed page, the lab).
struct DesignKitView: View {
    @State private var toast: String?

    var body: some View {
        ZStack {
            MuseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: MuseSpacing.sectionLabel) {
                    MuseHeader(
                        title: "design kit.",
                        subtitle: "everything the app is made of. use these, don't invent new chrome."
                    )
                    KitColorSection()
                    KitTypeSection()
                    KitSpaceSection()
                    KitMotionSection()
                    KitHapticsSection()
                    KitSurfaceSection()
                    KitButtonSection()
                    KitComponentSection(toast: $toast)
                    KitOrbSection()
                    KitRingSection()
                    KitInkSection()
                    MuseHintCard(
                        "every piece lives in the design folder. change a token there and every screen follows.",
                        systemImage: "paintbrush"
                    )
                }
                .padding(.horizontal, MuseSpacing.page)
                .padding(.top, MuseSpacing.lg)
                .padding(.bottom, MuseSpacing.sectionLabel)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .museBottomBlur()
        }
        .museToast($toast, systemImage: "checkmark")
    }
}

// MARK: - Kit pieces

/// A section: the header rule, then its items.
private struct KitSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader(title)
            content
        }
    }
}

/// A Swift name to copy, in Satoshi caption ink55. Long-press to copy it.
private struct KitName: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        Text(verbatim: name)
            .font(MuseType.caption)
            .foregroundStyle(MuseColor.ink55)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A smaller group label inside a section.
private struct KitGroupLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(MuseType.metaMedium)
            .foregroundStyle(MuseColor.ink70)
            .padding(.top, MuseSpacing.xxs)
    }
}

/// An example with its name underneath.
private struct KitItem<Content: View>: View {
    let name: String
    let content: Content

    init(_ name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            content
            KitName(name)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private let kitColumns = [
    GridItem(.flexible(), spacing: MuseSpacing.sm, alignment: .top),
    GridItem(.flexible(), spacing: MuseSpacing.sm, alignment: .top),
]

// MARK: - Color

private struct KitColor: Identifiable {
    let name: String
    let color: Color
    let role: String
    var id: String { name }
}

private struct KitColorSection: View {
    private let groups: [(title: String, colors: [KitColor])] = [
        ("ground", [
            KitColor(name: "ground", color: MuseColor.ground, role: "page ground, label on moss"),
            KitColor(name: "groundWash", color: MuseColor.groundWash, role: "top of the wash"),
            KitColor(name: "groundDeep", color: MuseColor.groundDeep, role: "bottom of the wash"),
            KitColor(name: "raised", color: MuseColor.raised, role: "cards, tiles, chrome"),
            KitColor(name: "composer", color: MuseColor.composer, role: "the composer, sheets"),
            KitColor(name: "inset", color: MuseColor.inset, role: "fields, code, inner rows"),
            KitColor(name: "mossTint", color: MuseColor.mossTint, role: "tags, tinted buttons, hints"),
            KitColor(name: "shelf", color: MuseColor.shelf, role: "fill-only chips"),
        ]),
        ("ink", [
            KitColor(name: "ink", color: MuseColor.ink, role: "titles and body"),
            KitColor(name: "ink70", color: MuseColor.ink70, role: "secondary text, symbols"),
            KitColor(name: "ink55", color: MuseColor.ink55, role: "meta, labels, chevrons"),
            KitColor(name: "hairline", color: MuseColor.hairline, role: "0.75pt borders"),
            KitColor(name: "divider", color: MuseColor.divider, role: "rows inside a card"),
        ]),
        ("moss", [
            KitColor(name: "moss900", color: MuseColor.moss900, role: "gradient ends, orb shade"),
            KitColor(name: "moss700", color: MuseColor.moss700, role: "primary fill"),
            KitColor(name: "moss", color: MuseColor.moss, role: "same as moss700"),
            KitColor(name: "moss600", color: MuseColor.moss600, role: "accent text, status dots"),
            KitColor(name: "moss300", color: MuseColor.moss300, role: "quiet marks, never a fill"),
        ]),
        ("clay and ochre", [
            KitColor(name: "clay", color: MuseColor.clay, role: "consequence, one per screen"),
            KitColor(name: "clayTint", color: MuseColor.clayTint, role: "ground for a clay badge"),
            KitColor(name: "ochre", color: MuseColor.ochre, role: "a fresh dot, never a fill"),
            KitColor(name: "ochreInk", color: MuseColor.ochreInk, role: "text on an unsure confidence tag"),
            KitColor(name: "ochreTint", color: MuseColor.ochreTint, role: "ground for an unsure confidence tag"),
        ]),
        ("orb", [
            KitColor(name: "orbHighlight", color: MuseColor.orbHighlight, role: "moss orb, light"),
            KitColor(name: "orbMid", color: MuseColor.orbMid, role: "moss orb, middle"),
            KitColor(name: "orbDeep", color: MuseColor.orbDeep, role: "moss orb, deep"),
            KitColor(name: "orbLinenHighlight", color: MuseColor.orbLinenHighlight, role: "linen orb, light"),
            KitColor(name: "orbLinenMid", color: MuseColor.orbLinenMid, role: "linen orb, middle"),
            KitColor(name: "orbLinenDeep", color: MuseColor.orbLinenDeep, role: "linen orb, deep"),
            KitColor(name: "orbLinenShade", color: MuseColor.orbLinenShade, role: "linen orb, edge"),
            KitColor(name: "orbLinenInset", color: MuseColor.orbLinenInset, role: "linen orb, shade"),
        ]),
        ("the ring's lights", [
            KitColor(name: "ringAmber", color: MuseColor.ringAmber, role: "the amber light, as the booklet prints it"),
        ]),
    ]

    var body: some View {
        KitSection("color") {
            ForEach(groups, id: \.title) { group in
                KitGroupLabel(group.title)
                LazyVGrid(columns: kitColumns, alignment: .leading, spacing: MuseSpacing.md) {
                    ForEach(group.colors) { swatch in
                        KitSwatch(swatch: swatch)
                    }
                }
            }
            KitGroupLabel("gradients")
            LazyVGrid(columns: kitColumns, alignment: .leading, spacing: MuseSpacing.md) {
                KitItem("MuseColor.primaryGradient") {
                    RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                        .fill(MuseColor.primaryGradient)
                        .frame(height: 52)
                }
                KitItem("MuseColor.softForestGradient") {
                    RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                        .fill(MuseColor.softForestGradient)
                        .frame(height: 52)
                }
            }
        }
    }
}

private struct KitSwatch: View {
    let swatch: KitColor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                .fill(swatch.color)
                .frame(height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                        .strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                }
            KitName("MuseColor.\(swatch.name)")
            Text(verbatim: Self.hex(swatch.color))
                .font(MuseType.code)
                .foregroundStyle(MuseColor.ink)
                .textSelection(.enabled)
            Text(swatch.role)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// "#f4f1e8", or "#1b2118 · 9%" for a translucent token.
    private static func hex(_ color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        let rgb = String(format: "#%02x%02x%02x", byte(red), byte(green), byte(blue))
        guard alpha < 0.999 else { return rgb }
        let percent = (alpha * 1000).rounded() / 10
        let shown = percent == percent.rounded() ? "\(Int(percent))" : "\(percent)"
        return "\(rgb) · \(shown)%"
    }
}

// MARK: - Type

private struct KitTypeSection: View {
    private struct Style: Identifiable {
        let name: String
        let font: Font
        let spec: String
        let sample: String
        var tracking: CGFloat = 0
        var id: String { name }
    }

    private let styles: [Style] = [
        Style(name: "display", font: MuseType.display, spec: "lora 40", sample: "muse.", tracking: MuseType.displayTracking),
        Style(name: "title", font: MuseType.title, spec: "lora 28", sample: "your ring.", tracking: MuseType.titleTracking),
        Style(name: "titleSmall", font: MuseType.titleSmall, spec: "lora 22", sample: "museo ring"),
        Style(name: "headline", font: MuseType.headline, spec: "lora 19", sample: "a walk by the water"),
        Style(name: "serif", font: MuseType.serif, spec: "lora 17, their words", sample: "\u{201C}remind me to call mum after the game.\u{201D}"),
        Style(name: "serifItalic", font: MuseType.serifItalic, spec: "lora italic 17, waiting", sample: "transcribing this muse\u{2026}"),
        Style(name: "label", font: MuseType.label, spec: "satoshi 15 medium, buttons", sample: "set up your ring"),
        Style(name: "body", font: MuseType.body, spec: "satoshi 15", sample: "muses arrive here and become words on this iphone."),
        Style(name: "meta", font: MuseType.meta, spec: "satoshi 13", sample: "9:41a \u{00B7} 0:12 \u{00B7} from the ring"),
        Style(name: "metaMedium", font: MuseType.metaMedium, spec: "satoshi 13 medium", sample: "82%"),
        Style(name: "caption", font: MuseType.caption, spec: "satoshi 11", sample: "last read 2m ago"),
        Style(name: "captionMedium", font: MuseType.captionMedium, spec: "satoshi 11 medium", sample: "3 on"),
        Style(name: "eyebrow", font: MuseType.eyebrow, spec: "satoshi 11, tracked", sample: "today", tracking: MuseType.eyebrowTracking),
        Style(name: "code", font: MuseType.code, spec: "sf mono 13", sample: "MuseHooks.onTranscribed { muse in }"),
    ]

    var body: some View {
        KitSection("type") {
            Text("lora speaks: their words, titles. satoshi labels: buttons, times, counts. never both in one sentence.")
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                ForEach(styles) { style in
                    KitItem("MuseType.\(style.name) \u{00B7} \(style.spec)") {
                        Text(verbatim: style.sample)
                            .font(style.font)
                            .tracking(style.tracking)
                            .foregroundStyle(MuseColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            KitName("MuseFont.lora(_:weight:) \u{00B7} MuseFont.loraItalic(_:) \u{00B7} MuseFont.satoshi(_:weight:) \u{00B7} MuseFont.symbol(_:weight:) \u{00B7} .museSymbol(_:weight:) \u{00B7} MuseFont.mono(_:)")
            if !MuseFont.isLoaded {
                MuseHintCard("lora or satoshi didn't load, so this page is drawing in the system font. check the shared fonts folder is in the app target.", systemImage: "textformat")
            }
        }
    }
}

// MARK: - Space and radius

private struct KitSpaceSection: View {
    private let spacing: [(String, CGFloat)] = [
        ("xxs", MuseSpacing.xxs), ("xs", MuseSpacing.xs), ("sm", MuseSpacing.sm), ("row", MuseSpacing.row),
        ("md", MuseSpacing.md), ("card", MuseSpacing.card), ("lg", MuseSpacing.lg), ("page", MuseSpacing.page),
        ("xl", MuseSpacing.xl), ("section", MuseSpacing.section), ("sectionLabel", MuseSpacing.sectionLabel),
    ]

    private let radii: [(String, CGFloat)] = [
        ("tag", MuseRadius.tag), ("control", MuseRadius.control), ("card", MuseRadius.card),
        ("tile", MuseRadius.tile), ("sheet", MuseRadius.sheet),
    ]

    var body: some View {
        KitSection("space and radius") {
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                ForEach(spacing, id: \.0) { name, value in
                    HStack(spacing: MuseSpacing.sm) {
                        Capsule()
                            .fill(MuseColor.moss300)
                            .frame(width: value * 3, height: 6)
                            .frame(width: 124, alignment: .leading)
                        KitName("MuseSpacing.\(name) \u{00B7} \(Int(value))")
                    }
                }
            }
            MuseFlowLayout(spacing: MuseSpacing.md, lineSpacing: MuseSpacing.md) {
                ForEach(radii, id: \.0) { name, value in
                    VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                        RoundedRectangle(cornerRadius: value, style: .continuous)
                            .fill(MuseColor.raised)
                            .overlay {
                                RoundedRectangle(cornerRadius: value, style: .continuous)
                                    .strokeBorder(MuseColor.ink.opacity(0.2), lineWidth: 0.75)
                            }
                            .frame(width: 64, height: 64)
                        KitName("MuseRadius.\(name) \u{00B7} \(Int(value))")
                    }
                }
            }
            LazyVGrid(columns: kitColumns, alignment: .leading, spacing: MuseSpacing.md) {
                ForEach([MuseElevation.e0, .e1, .e2], id: \.self) { level in
                    KitItem(".museElevation(.\(level))") {
                        RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous)
                            .fill(MuseColor.raised)
                            .frame(height: 52)
                            .museElevation(level)
                    }
                }
                KitItem("MuseTopChrome.height \u{00B7} 34, .circle \u{00B7} 38, .hitTarget \u{00B7} 44") {
                    Text("44pt targets, always")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink70)
                        .frame(height: 52)
                }
            }
        }
    }
}

// MARK: - Motion

private struct KitMotionSection: View {
    private let motions: [(String, Animation)] = [
        ("snappy", MuseMotion.snappy), ("smooth", MuseMotion.smooth), ("gentle", MuseMotion.gentle),
        ("bouncy", MuseMotion.bouncy), ("drift", MuseMotion.drift), ("dissolve", MuseMotion.dissolve),
        ("crossing", MuseMotion.crossing), ("select", MuseMotion.select), ("press", MuseMotion.press),
    ]

    var body: some View {
        KitSection("motion") {
            Text("tap one to feel how it moves. drift is a muse arriving.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
            LazyVGrid(columns: kitColumns, alignment: .leading, spacing: MuseSpacing.md) {
                ForEach(motions, id: \.0) { name, animation in
                    KitMotionSample(name: name, animation: animation)
                }
            }
            KitName("MuseMotion.adaptive(_:reduceMotion:) \u{00B7} .museAnimation(_:value:)")
        }
    }
}

private struct KitMotionSample: View {
    let name: String
    let animation: Animation
    @State private var moved = false

    var body: some View {
        Button {
            withAnimation(animation) { moved.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                Circle()
                    .fill(MuseColor.moss)
                    .frame(width: 18, height: 18)
                    .padding(3)
                    .frame(maxWidth: .infinity, alignment: moved ? .trailing : .leading)
                    .background { Capsule().fill(MuseColor.ink.opacity(0.06)) }
                KitName("MuseMotion.\(name)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("play \(name)")
    }
}

// MARK: - Haptics

private struct KitHapticsSection: View {
    var body: some View {
        KitSection("haptics") {
            Text("tap to feel each one on a phone.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
            KitName("MuseHaptics.play(_:)")
            MuseFlowLayout {
                ForEach(MuseHaptics.Kind.allCases, id: \.self) { kind in
                    KitChip(".\(kind)") { MuseHaptics.play(kind) }
                }
            }
            KitName("MuseHaptics.key(_:strength:) \u{00B7} the typewriter")
            MuseFlowLayout {
                ForEach(MuseKeyHaptics.Key.allCases, id: \.self) { key in
                    KitChip(".\(key)") { MuseHaptics.key(key) }
                }
            }
        }
    }
}

/// A fill-only chip that runs something.
private struct KitChip: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            // One line at its own width: the flow layout wraps the chip, never the word.
            Text(verbatim: title)
                .font(MuseType.metaMedium)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(MuseColor.ink)
                .padding(.horizontal, MuseSpacing.sm)
                .frame(height: MuseTopChrome.height)
                .musePill(.chip)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle())
    }
}

// MARK: - Surfaces

private struct KitSurfaceSection: View {
    var body: some View {
        KitSection("surfaces") {
            Text("one table decides fill, hairline and lift for all of them: MuseStock.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
            LazyVGrid(columns: kitColumns, alignment: .leading, spacing: MuseSpacing.lg) {
                KitItem(".museCardSurface()") {
                    KitBlock("card").museCardSurface()
                }
                KitItem(".museTileSurface()") {
                    KitBlock("tile").museTileSurface()
                }
                KitItem(".museInsetSurface()") {
                    KitBlock("inset").museInsetSurface()
                }
                KitItem(".museComposerSurface()") {
                    KitBlock("composer").museComposerSurface()
                }
                KitItem(".musePill()") {
                    KitPillLabel("tile pill").musePill()
                }
                KitItem(".musePill(.chip)") {
                    KitPillLabel("chip").musePill(.chip)
                }
                KitItem(".musePill(selected: true)") {
                    KitPillLabel("selected", color: MuseColor.ground).musePill(selected: true)
                }
                KitItem(".museTopChrome()") {
                    HStack(spacing: 6) {
                        MuseLiveDot(size: 7, pulses: false)
                        Text("ring \u{00B7} linked")
                            .font(MuseType.body)
                            .foregroundStyle(MuseColor.ink)
                    }
                    .padding(.horizontal, MuseSpacing.sm)
                    .museTopChrome()
                }
                KitItem("MuseGlassSurface()") {
                    KitBlock("glass").background { MuseGlassSurface() }
                }
                KitItem("MuseBackground()") {
                    KitBlock("the page")
                        .background { MuseBackground().clipShape(RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)) }
                        .overlay {
                            RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                                .strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                        }
                }
            }
            KitName(".museBottomBlur() on every ScrollView \u{00B7} MuseGrainOverlay(opacity:) on the wash only")
        }
    }
}

private struct KitBlock: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(MuseType.meta)
            .foregroundStyle(MuseColor.ink70)
            .frame(maxWidth: .infinity, minHeight: 64)
    }
}

private struct KitPillLabel: View {
    let text: String
    var color: Color = MuseColor.ink

    init(_ text: String, color: Color = MuseColor.ink) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(MuseType.metaMedium)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(color)
            .padding(.horizontal, MuseSpacing.md)
            .frame(height: MuseTopChrome.height)
    }
}

// MARK: - Buttons

private struct KitButtonSection: View {
    var body: some View {
        KitSection("buttons") {
            Text("one primary per screen. tinted for things you can undo. clay text for things you can't.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            KitItem("MuseButtonStyle(.primary) \u{00B7} full width: label .frame(maxWidth: .infinity)") {
                Button {
                    MuseHaptics.play(.medium)
                } label: {
                    Text("set up your ring").frame(maxWidth: .infinity)
                }
                .buttonStyle(MuseButtonStyle(.primary))
            }
            KitItem("MuseButtonStyle(.secondary)") {
                Button("look for it") { MuseHaptics.play(.soft) }
                    .buttonStyle(MuseButtonStyle(.secondary))
            }
            KitItem("MuseButtonStyle(.tinted)") {
                Button("bring them in") { MuseHaptics.play(.soft) }
                    .buttonStyle(MuseButtonStyle(.tinted))
            }
            KitItem("MuseButtonStyle(.tinted, height: 28)") {
                Button("retry") { MuseHaptics.play(.soft) }
                    .buttonStyle(MuseButtonStyle(.tinted, height: 28))
            }
            KitItem("MuseButtonStyle(.destructive)") {
                Button("remove ring") { MuseHaptics.play(.warning) }
                    .buttonStyle(MuseButtonStyle(.destructive))
            }
            KitItem("MusePressStyle(pressedScale: 0.94) \u{00B7} chrome with no fill of its own") {
                Button {
                    MuseHaptics.play(.soft)
                } label: {
                    MuseIconTile("sparkles", size: 36)
                }
                .buttonStyle(MusePressStyle())
                .accessibilityLabel("press me")
            }
        }
    }
}

// MARK: - Components

private struct KitComponentSection: View {
    @Binding var toast: String?

    @State private var homeStyle = "workbench"
    @State private var autoSync = true
    @State private var studioSound = false
    @State private var toggleOn = true

    var body: some View {
        KitSection("components") {
            KitItem("MuseHeader(eyebrow:title:subtitle:titleSize:)") {
                MuseHeader(eyebrow: "eyebrow", title: "your ring.", subtitle: "linked \u{00B7} listening", titleSize: 28)
            }
            KitItem("MuseSectionHeader(_:count:) \u{00B7} MuseSectionHeader(_:trailing:)") {
                VStack(spacing: MuseSpacing.md) {
                    MuseSectionHeader("today", count: 3)
                    MuseSectionHeader("ask the ring") {
                        Text("linked")
                            .font(MuseType.captionMedium)
                            .foregroundStyle(MuseColor.moss600)
                    }
                }
            }
            KitItem("MuseEyebrow(_:color:)") {
                MuseEyebrow("listening", color: MuseColor.moss600)
            }
            KitItem("MuseSegmented(selection:options:)") {
                MuseSegmented(selection: $homeStyle, options: [("workbench", "workbench"), ("quiet", "quiet")])
            }
            KitItem("MuseSegmented(selection:options:fillsWidth: true)") {
                MuseSegmented(
                    selection: $homeStyle,
                    options: [("workbench", "workbench"), ("quiet", "quiet")],
                    fillsWidth: true
                )
            }
            KitItem("MuseConfidenceTag(_:style:)") {
                VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                    HStack(spacing: MuseSpacing.xs) {
                        MuseConfidenceTag(0.42, style: .compact)
                        MuseConfidenceTag(0.68, style: .compact)
                        MuseConfidenceTag(0.81, style: .compact)
                        MuseConfidenceTag(0.97, style: .compact)
                    }
                    MuseConfidenceTag(0.91)
                }
            }
            KitItem("MuseLiveDot(color:size:pulses:)") {
                HStack(spacing: MuseSpacing.md) {
                    MuseLiveDot()
                    MuseLiveDot(color: MuseColor.clay)
                }
                .frame(height: 20)
            }
            HStack(alignment: .top, spacing: MuseSpacing.lg) {
                KitItem("MuseChromeIcon(_:label:action:)") {
                    HStack(spacing: 0) {
                        MuseChromeIcon("hammer", label: "build") {}
                        MuseChromeIcon("xmark", label: "close") {}
                    }
                }
                KitItem("MuseIconTile(_:size:tone:)") {
                    HStack(spacing: MuseSpacing.sm) {
                        MuseIconTile("checklist")
                        MuseIconTile("waveform", tone: .quiet)
                    }
                    .frame(height: 44)
                }
            }
            KitItem("MuseListRow(title:meta:value:systemImage:action:)") {
                MuseListRow(
                    title: "update firmware",
                    meta: "bundled \(BundledFirmware.version)",
                    systemImage: "arrow.down.circle"
                ) {}
            }
            KitItem("MuseListCard { rows } \u{00B7} one card, dividers between") {
                MuseListCard {
                    MuseListRow("ring console", systemImage: "terminal") {}
                    MuseListRow("language", value: "auto") {}
                    MuseToggleRow("studio sound", subtitle: "a cleaner copy for listening.", isOn: $studioSound)
                }
            }
            KitItem("MuseToggleRow(_:subtitle:isOn:)") {
                MuseToggleRow("bring recordings in on their own", isOn: $autoSync)
            }
            KitItem("Toggle(_:isOn:).toggleStyle(.muse)") {
                Toggle("any toggle", isOn: $toggleOn)
                    .toggleStyle(.muse)
            }
            KitItem("MuseCodeLine(_:caption:)") {
                MuseCodeLine("MuseHooks.onTranscribed { muse in\n    print(muse.words)\n}", caption: "listen to every muse")
            }
            KitItem("MuseHintCard(_:systemImage:)") {
                MuseHintCard("hold the ring to talk. let go and the words land here.", systemImage: "hand.tap")
            }
            KitItem("MuseToast(_:systemImage:) \u{00B7} .museToast($message)") {
                VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                    MuseToast("copied", systemImage: "checkmark")
                    Button("show a toast") { toast = "copied" }
                        .buttonStyle(MuseButtonStyle(.tinted, height: 32))
                }
            }
            KitItem("MuseFlowLayout(spacing:lineSpacing:)") {
                MuseFlowLayout {
                    ForEach(["ask", "to-do", "recall", "today", "webhook", "notes"], id: \.self) { name in
                        KitPillLabel(name).musePill(.chip)
                    }
                }
            }
            KitItem("MuseHairline()") {
                MuseHairline()
                    .padding(.vertical, MuseSpacing.xs)
            }
        }
    }
}

// MARK: - Orb

private struct KitOrbSection: View {
    var body: some View {
        KitSection("orb") {
            Text("the only gradient sphere. moss at rest, linen while listening, a drifting light while thinking.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: MuseSpacing.md) {
                ForEach(MuseOrb.Mode.allCases, id: \.self) { mode in
                    KitItem(".\(mode)") {
                        MuseOrb(mode: mode)
                    }
                }
            }
            KitName("MuseOrb(mode:size:breathes:)")
            HStack(alignment: .bottom, spacing: MuseSpacing.lg) {
                ForEach(
                    [("mark", MuseOrb.Size.mark), ("search", MuseOrb.Size.search), ("chat", MuseOrb.Size.chat), ("voice", MuseOrb.Size.voice)],
                    id: \.0
                ) { name, size in
                    VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                        MuseOrb(size: size, breathes: false)
                        KitName(".\(name) \u{00B7} \(Int(size))")
                    }
                }
            }
            KitName("MuseOrb.Size.mark / .search / .chat / .voice")
        }
    }
}

// MARK: - Ring

private struct KitRingSection: View {
    private struct Example: Identifiable {
        let call: String
        let note: String
        let glyph: MuseRingGlyph
        var id: String { call }
    }

    private let examples: [Example] = [
        Example(call: "MuseRingGlyph(fill: 0.82, style: .linked)", note: "linked, battery 82%", glyph: MuseRingGlyph(fill: 0.82, style: .linked)),
        Example(call: "MuseRingGlyph(fill: nil, style: .linked)", note: "linked, no battery read yet", glyph: MuseRingGlyph(fill: nil, style: .linked)),
        Example(call: "MuseRingGlyph(fill: 0.6, style: .away)", note: "away, its last reading at half strength", glyph: MuseRingGlyph(fill: 0.6, style: .away)),
        Example(call: "MuseRingGlyph(fill: nil, style: .setup)", note: "not set up on this iphone yet", glyph: MuseRingGlyph(fill: nil, style: .setup)),
        Example(call: "MuseRingGlyph(fill: nil, style: .setup, attention: true)", note: "bluetooth is off", glyph: MuseRingGlyph(fill: nil, style: .setup, attention: true)),
        Example(call: "MuseRingGlyph(fill: 0.7, style: .streaming, breathing: true)", note: "a muse streaming in right now", glyph: MuseRingGlyph(fill: 0.7, style: .streaming, breathing: true)),
        Example(call: "MuseRingGlyph(fill: 0.15, style: .low)", note: "linked, battery low", glyph: MuseRingGlyph(fill: 0.15, style: .low)),
        Example(call: "MuseRingGlyph(fill: 0.4, style: .linked, count: 3)", note: "bringing in 3, this one 40% across", glyph: MuseRingGlyph(fill: 0.4, style: .linked, count: 3)),
        Example(call: "MuseRingGlyph(fill: 0.9, style: .linked, attention: true)", note: "linked, the ring is nearly full", glyph: MuseRingGlyph(fill: 0.9, style: .linked, attention: true)),
    ]

    var body: some View {
        KitSection("ring") {
            Text("one glyph says link, battery and sync. it's the ring seen from above: the stone at the top, and the battery running clockwise from it around the band.")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: MuseSpacing.md) {
                ForEach(examples) { example in
                    HStack(alignment: .center, spacing: MuseSpacing.row) {
                        KitRingPlate(glyph: example.glyph)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(example.note)
                                .font(MuseType.meta)
                                .foregroundStyle(MuseColor.ink)
                            KitName(example.call)
                        }
                    }
                }
            }
            KitItem("MuseRingGlyph(fill:style:size: 34) \u{00B7} style.plate behind it") {
                HStack(spacing: MuseSpacing.lg) {
                    ForEach(MuseRingGlyph.Style.allCases, id: \.self) { style in
                        KitRingPlate(glyph: MuseRingGlyph(fill: style == .low ? 0.18 : 0.72, style: style, size: 34), diameter: 56)
                    }
                }
            }
            KitItem("MuseRingMark(size:color:) \u{00B7} \"from the ring\"") {
                HStack(spacing: MuseSpacing.lg) {
                    MuseRingMark(size: 12, color: MuseColor.ink55)
                    MuseRingMark()
                    MuseRingMark(size: 24, color: MuseColor.moss600)
                }
            }
            KitItem("MuseRingArt(width:) \u{00B7} the ring, from the booklet") {
                MuseRingArt(width: 220)
            }
            KitItem("MuseRingBand(light:lit:height:) \u{00B7} streaming, recording, resting") {
                HStack(spacing: MuseSpacing.section) {
                    MuseRingBand(light: .white, lit: true, height: 140)
                    MuseRingBand(light: .amber, lit: true, height: 140)
                    MuseRingBand(light: .white, lit: false, height: 140)
                }
            }
            KitItem("MuseHandArt(width:) \u{00B7} how to wear it") {
                MuseHandArt(width: 200)
            }
            KitItem("MuseCaseArt(pose:width:) \u{00B7} open, and closed with the ring charging") {
                HStack(alignment: .bottom, spacing: MuseSpacing.section) {
                    MuseCaseArt(pose: .open, width: 80)
                    MuseCaseArt(pose: .closed, width: 80)
                }
            }
        }
    }
}

/// The circle a ring button draws behind the glyph.
private struct KitRingPlate: View {
    let glyph: MuseRingGlyph
    var diameter: CGFloat = MuseTopChrome.circle

    var body: some View {
        glyph
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(glyph.style.plate)
                    .overlay {
                        if glyph.style.platesHairline {
                            Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                        }
                    }
            }
    }
}

// MARK: - Ink

private struct KitInkSection: View {
    @State private var run = 0
    /// The kit isn't lazy, so this section appears when the page opens, screens below.
    /// It types (and taps the keys) the first time it's actually on screen, once.
    @State private var seen = false

    var body: some View {
        KitSection("ink") {
            KitItem("MuseInkText(_:font:color:startsTyping:haptics:onFinish:)") {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    MuseInkText(
                        "\u{201C}you said this into the ring. it lands here, one letter at a time, like ink settling.\u{201D}",
                        font: MuseType.serif,
                        color: MuseColor.ink,
                        startsTyping: seen
                    )
                    .lineSpacing(MuseType.serifLineSpacing)
                    .id(run)
                    Button("type it again") { run += 1 }
                        .buttonStyle(MuseButtonStyle(.tinted, height: 32))
                }
                .padding(.horizontal, MuseSpacing.md)
                .padding(.vertical, MuseSpacing.row)
                .museCardSurface()
                .onScrollVisibilityChange(threshold: 0.6) { visible in
                    if visible { seen = true }
                }
            }
        }
    }
}
