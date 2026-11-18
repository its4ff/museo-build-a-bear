#if DEBUG
import SwiftUI

/// The one new mac native idea: ⌘K. A Liquid Glass palette over the dimmed page with one
/// text line and a few results in two quiet groups. It is how places and museo.fm exist
/// on the mac without a tab bar: you send a thought to one, or you go there.
struct PagePalette: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            field
            PageHairline()
            VStack(alignment: .leading, spacing: 0) {
                group("places", PageFixtures.sendTo, highlighted: PageFixtures.sendTo.first?.id)
                group("go", PageFixtures.goTo, highlighted: nil)
                    .padding(.top, MuseSpacing.xs)
            }
            .padding(MuseSpacing.xs)
            PageHairline()
            HStack {
                Spacer(minLength: 0)
                Text("↑↓ move · ↩ send · esc close")
                    .font(MuseFont.mono(.caption2))
                    .foregroundStyle(MuseColor.ink55)
            }
            .padding(.horizontal, MuseSpacing.card)
            .frame(height: PageMetrics.paletteRow)
        }
        .frame(width: PageMetrics.palette)
        .duoTileGlass(cornerRadius: MuseRadius.sheet)
        .museElevation(.e2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("send to, search, or go")
    }

    private var field: some View {
        HStack(spacing: MuseSpacing.xs) {
            Capsule()
                .fill(MuseColor.moss600)
                .frame(width: PageMetrics.rule, height: PageMetrics.caret)
                .accessibilityHidden(true)
            Text("send to, search, or go…")
                .font(MuseFont.satoshi(PageMetrics.listLine))
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: 0)
            Text("⌘K")
                .font(MuseFont.mono(.caption))
                .foregroundStyle(MuseColor.ink55)
        }
        .padding(.horizontal, MuseSpacing.card)
        .frame(height: PageMetrics.paletteField)
    }

    private func group(_ title: String, _ results: [PageFixtures.Result], highlighted: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageEyebrow(title)
                .padding(.horizontal, MuseSpacing.sm - 2)
                .padding(.top, MuseSpacing.xs)
                .padding(.bottom, MuseSpacing.xxs + 2)
            ForEach(results) { result in
                row(result, isOn: result.id == highlighted)
            }
        }
    }

    private func row(_ result: PageFixtures.Result, isOn: Bool) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            Text(result.name)
                .font(MuseType.label)
                .foregroundStyle(isOn ? DuoColor.onMoss : MuseColor.ink)
            if let note = result.note {
                Text("·")
                    .font(MuseType.meta)
                    .foregroundStyle(isOn ? DuoColor.onMossQuiet : MuseColor.ink55)
                    .accessibilityHidden(true)
                Text(note)
                    .font(MuseType.meta)
                    .foregroundStyle(noteInk(result, isOn: isOn))
            }
            Spacer(minLength: 0)
            if isOn {
                Text("↩")
                    .font(MuseFont.mono(.caption))
                    .foregroundStyle(DuoColor.onMossQuiet)
                    .accessibilityHidden(true)
            } else if let keys = result.keys {
                Text(keys)
                    .font(MuseFont.mono(.caption))
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .padding(.horizontal, MuseSpacing.sm - 2)
        .frame(height: PageMetrics.paletteRow)
        .background {
            if isOn {
                RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                    .fill(MuseColor.primaryGradient)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func noteInk(_ result: PageFixtures.Result, isOn: Bool) -> Color {
        if isOn { return DuoColor.onMossQuiet }
        return result.isPublic ? MuseColor.clay : MuseColor.ink55
    }
}

extension View {
    /// Dims and softens the window and lays the ⌘K palette over it, a little above the middle.
    func pagePalette() -> some View {
        self
            .blur(radius: PageMetrics.veilBlur)
            .overlay { MuseColor.ink.opacity(PageMetrics.veil) }
            .overlay {
                PagePalette()
                    .offset(y: -PageMetrics.paletteLift)
            }
            .clipped()
    }
}
#endif
