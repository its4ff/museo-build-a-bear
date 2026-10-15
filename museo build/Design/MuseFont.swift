import CoreText
import SwiftUI
import UIKit

// Lora speaks: anything that came out of someone's mouth (their words, titles, hints).
// Satoshi labels: anything the app says about itself (buttons, times, counts, nav).
// Never mix the two inside one sentence.
//
// Every face scales with Dynamic Type (`.custom(_:size:relativeTo:)`). Dense rows can cap
// it with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`. Symbols beside words scale
// too (`.museSymbol(13)`); `MuseFont.symbol(13)` stays fixed, for chrome that doesn't grow.

// MARK: - Fonts

/// Lora, Satoshi, SF Symbols and SF Mono at any size. Most screens want `MuseType` instead.
nonisolated enum MuseFont {

    /// The faces museo build ships. Lora and Satoshi are variable fonts (`Design/Fonts/`); CoreText
    /// names their named instances "<postscript name>_<instance>". Lora italic is a static
    /// file in `Design/Fonts/`.
    nonisolated enum Face: String, CaseIterable, Sendable {
        case loraRegular = "Lora-Regular"
        case loraMedium = "Lora-Regular_Medium"
        case loraSemiBold = "Lora-Regular_SemiBold"
        case loraBold = "Lora-Regular_Bold"
        case loraItalic = "Lora-Italic"
        case satoshiLight = "SatoshiVariable-Bold_Light"
        case satoshiRegular = "SatoshiVariable-Bold_Regular"
        case satoshiMedium = "SatoshiVariable-Bold_Medium"
        case satoshiBold = "SatoshiVariable-Bold_Bold"

        /// Other names the same face goes by (static font files), tried in order.
        fileprivate var fallbacks: [String] {
            switch self {
            case .loraRegular: []
            case .loraMedium: ["Lora-Medium"]
            case .loraSemiBold: ["Lora-SemiBold"]
            case .loraBold: ["Lora-Bold"]
            case .loraItalic: []
            case .satoshiLight: ["Satoshi-Light"]
            case .satoshiRegular: ["Satoshi-Regular"]
            case .satoshiMedium: ["Satoshi-Medium"]
            case .satoshiBold: ["Satoshi-Bold"]
            }
        }
    }

    /// Lora at any size. Regular (400) unless a dense list needs medium.
    static func lora(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face: Face = switch weight {
        case .bold, .heavy, .black: .loraBold
        case .semibold: .loraSemiBold
        case .medium: .loraMedium
        default: .loraRegular
        }
        return .custom(name(face), size: size, relativeTo: textStyle(for: size))
    }

    /// Lora italic: waiting and empty states ("transcribing this muse…", "blank muse").
    /// Falls back to a synthesized slant if the italic file is missing.
    static func loraItalic(_ size: CGFloat) -> Font {
        guard resolved[.loraItalic] != nil else { return lora(size).italic() }
        return .custom(name(.loraItalic), size: size, relativeTo: textStyle(for: size))
    }

    /// Satoshi at any size. Semibold maps to medium (the font has no semibold).
    static func satoshi(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face: Face = switch weight {
        case .bold, .heavy, .black: .satoshiBold
        case .medium, .semibold: .satoshiMedium
        case .light, .ultraLight, .thin: .satoshiLight
        default: .satoshiRegular
        }
        return .custom(name(face), size: size, relativeTo: textStyle(for: size))
    }

    /// SF Symbols at a fixed point size, for chrome whose frame doesn't grow (the 38pt
    /// chrome circles, the ring glyph, an icon tile):
    /// `Image(systemName: "hammer").font(MuseFont.symbol(15))`. An icon that sits beside
    /// text (a row's chevron, a tag's icon) uses `.museSymbol(13)` instead, so it scales with
    /// Dynamic Type like the words next to it. The one sanctioned use of the system face,
    /// and only for symbols, never words. Screens never size a symbol with the system font
    /// directly.
    static func symbol(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font(UIFont.systemFont(ofSize: size, weight: uiWeight(weight)))
    }

    /// SF Mono for code and raw values (snippets, the ring console). Scales with Dynamic Type.
    static func mono(_ style: Font.TextStyle = .footnote, weight: Font.Weight = .regular) -> Font {
        Font.system(style, design: .monospaced, weight: weight)
    }

    /// The PostScript name a face resolved to.
    static func name(_ face: Face) -> String {
        resolved[face] ?? face.rawValue
    }

    /// False when Lora or Satoshi failed to load, so text is drawing in the system font.
    static var isLoaded: Bool {
        resolved[.loraRegular] != nil && resolved[.satoshiRegular] != nil
    }

    // MARK: - Resolution

    /// Face to PostScript name, resolved once. A `static let` initializer runs exactly once
    /// (thread safe), so this table can be read from any thread without a lock. Faces that
    /// did not load are absent and fall back to their canonical name.
    private static let resolved: [Face: String] = {
        registerIfNeeded()
        var table: [Face: String] = [:]
        for face in Face.allCases {
            let candidates = [face.rawValue] + face.fallbacks
            if let hit = candidates.first(where: { UIFont(name: $0, size: 12) != nil }) {
                table[face] = hit
            }
        }
        return table
    }()

    /// `MuseoBuildApp.init` registers Lora and Satoshi. Previews skip `App.init`, so check
    /// here too, then add the static Lora italic.
    private static func registerIfNeeded() {
        if UIFont(name: Face.loraRegular.rawValue, size: 12) == nil
            || UIFont(name: Face.satoshiRegular.rawValue, size: 12) == nil {
            FontRegistrar.registerBundledFonts()
        }
        if UIFont(name: Face.loraItalic.rawValue, size: 12) == nil,
           let url = Bundle.main.url(forResource: "Lora-Italic", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// SwiftUI weight to UIKit weight, for `symbol(_:weight:)`.
    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }

    /// The Dynamic Type curve a size follows (the iOS default size of each style).
    fileprivate static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...: .largeTitle
        case 28..<34: .title
        case 22..<28: .title2
        case 20..<22: .title3
        case 17..<20: .body
        case 16..<17: .callout
        case 15..<16: .subheadline
        case 13..<15: .footnote
        case 12..<13: .caption
        default: .caption2
        }
    }
}

// MARK: - Scaling symbols

extension View {
    /// An SF Symbol that scales with Dynamic Type, on the same curve as text of that size:
    /// `Image(systemName: "chevron.right").museSymbol(13, weight: .semibold)`. For icons
    /// beside words. Fixed chrome uses `.font(MuseFont.symbol(_:weight:))`.
    func museSymbol(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        modifier(MuseSymbolFont(size, weight: weight, relativeTo: MuseFont.textStyle(for: size)))
    }
}

/// `MuseFont.symbol` at a size that follows Dynamic Type. Use it through `.museSymbol`.
struct MuseSymbolFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(_ base: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: base, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(MuseFont.symbol(size, weight: weight))
    }
}

// MARK: - Type ramp

/// The named styles. New screens reach for these so everything stays on one rhythm.
/// Lora is regular (400) throughout.
nonisolated enum MuseType {

    // MARK: Lora speaks

    /// Page titles: "muse.", "build.", "design kit." (Lora 40). Pair with `displayTracking`.
    static let display = MuseFont.lora(40)
    /// Sheet titles and big numbers: "your ring.", a running timer (Lora 28).
    static let title = MuseFont.lora(28)
    /// Small titles: the ring's name, a section's big line (Lora 22).
    static let titleSmall = MuseFont.lora(22)
    /// Card and row titles (Lora 19).
    static let headline = MuseFont.lora(19)
    /// Their words, hints, read body (Lora 17). Pair with `serifLineSpacing`.
    static let serif = MuseFont.lora(17)
    /// Waiting and empty lines: "transcribing this muse…" (Lora italic 17).
    static let serifItalic = MuseFont.loraItalic(17)

    // MARK: Satoshi labels

    /// Buttons and control labels (Satoshi 15 medium).
    static let label = MuseFont.satoshi(15, weight: .medium)
    /// Subtitles and UI sentences (Satoshi 15).
    static let body = MuseFont.satoshi(15)
    /// Times, durations, segments, tags: "9:41a · 0:12" (Satoshi 13).
    static let meta = MuseFont.satoshi(13)
    /// Chips and the battery percent (Satoshi 13 medium).
    static let metaMedium = MuseFont.satoshi(13, weight: .medium)
    /// Stamps and small print (Satoshi 11).
    static let caption = MuseFont.satoshi(11)
    /// Counts in pills (Satoshi 11 medium).
    static let captionMedium = MuseFont.satoshi(11, weight: .medium)
    /// Section labels, always lowercase, with `eyebrowTracking` (Satoshi 11).
    static let eyebrow = MuseFont.satoshi(11)

    // MARK: Mono

    /// Code snippets and raw values (SF Mono 13).
    static let code = MuseFont.mono(.footnote)

    // MARK: Rhythm

    /// +16% on the eyebrow.
    static let eyebrowTracking: CGFloat = 1.76
    /// -2.5% on display titles.
    static let displayTracking: CGFloat = -1.0
    /// -2% on titles.
    static let titleTracking: CGFloat = -0.56
    /// Lora 17 reads at 17/27.
    static let serifLineSpacing: CGFloat = 5
    /// Satoshi 15 reads at 15/22.
    static let bodyLineSpacing: CGFloat = 2
}
