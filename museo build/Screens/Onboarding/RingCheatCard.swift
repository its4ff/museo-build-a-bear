import SwiftUI

/// The ring in one card: streaming and memory, the lights, music, resetting it, charging,
/// and care.
///
/// The onboarding ends on it, the home's question mark opens it ("how museo works"), and the lab
/// shoots it alone (`cheatcard`) as a portrait image for the docs. Facts only the
/// firmware confirms are left out (the "too far" flash, what a steady white means).
struct RingCheatCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mode(
                "streaming",
                gesture: .hold,
                name: "hold",
                light: .white,
                detail: "talk while you hold, let go to send. sent straight to your iphone or mac."
            )
            divider
            mode(
                "memory",
                gesture: .clicks(2),
                name: "double click",
                light: .amber,
                detail: "once to start, again to stop. kept on museo, about 3 hours fit. it comes in when your phone is near."
            )
            divider
            // Which one: when each mode is the right one.
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                Text("memory mode always works, whether your phone is there or not.")
                Text("streaming mode is for when you need a response back. keep your phone or mac within 10 ft (3 m).")
            }
            .font(MuseType.serifItalic)
            .lineSpacing(MuseType.serifLineSpacing - 1)
            .foregroundStyle(MuseColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, MuseSpacing.sm)
            divider
            section("wear") {
                HStack(alignment: .center, spacing: MuseSpacing.sm) {
                    Text("index finger, the button toward your thumb. talk or whisper from 3 to 60 cm away. in public, cup your hand.")
                        .font(MuseType.body)
                        .lineSpacing(MuseType.bodyLineSpacing)
                        .foregroundStyle(MuseColor.ink70)
                        .fixedSize(horizontal: false, vertical: true)
                    MuseHandArt(width: 112)
                }
            }
            divider
            section("music") {
                row(.clicks(1), "click", "play or pause")
                row(.clicks(3), "three clicks", "next track or video")
            }
            divider
            section("reset") {
                row(.clicks(6), "click 6 times", "forget its phone, so setup can find it", stacked: true)
                row(.count(10), "click 10 to 11 times", "restart the ring", stacked: true)
            }
            divider
            section("charging") {
                charging(
                    MuseCaseArt(pose: .open, width: 56),
                    title: "the case",
                    lines: [([MuseColor.moss600], "3 to 4 charges"), ([MuseColor.ringAmber], "1 to 2 charges"), ([MuseColor.ringAmber, MuseColor.ringAmber], "under 20%")]
                )
                charging(
                    MuseCaseArt(pose: .closed, width: 56),
                    title: "the ring",
                    lines: [([MuseColor.moss600], "ready"), ([MuseColor.ringAmber], "charging")]
                )
            }
            divider
            section("care") {
                Text("hands, showers and rain are fine. not swimming, salt water or long soaks. clean it with a soft, slightly damp cloth.")
                    .font(MuseType.body)
                    .lineSpacing(MuseType.bodyLineSpacing)
                    .foregroundStyle(MuseColor.ink70)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
    }

    // MARK: Streaming and memory

    private func mode(
        _ title: String,
        gesture: RingGestureMark.Gesture,
        name: String,
        light: RingLight.Kind,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                MuseEyebrow(title)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: MuseSpacing.sm)
                RingLight(light)
                Text(light == .white ? "white light" : "amber light")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                RingGestureMark(gesture, color: MuseColor.ink)
                Text(name)
                    .font(MuseType.headline)
                    .foregroundStyle(MuseColor.ink)
            }
            Text(detail)
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, RingGestureMark.width + MuseSpacing.xs)
        }
        .padding(.vertical, MuseSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: Charging

    /// The case drawn small, and what its light says beside it.
    private func charging(_ art: MuseCaseArt, title: String, lines: [([Color], String)]) -> some View {
        HStack(alignment: .center, spacing: MuseSpacing.md) {
            art
                .frame(width: 56)
            VStack(alignment: .leading, spacing: MuseSpacing.xxs + 2) {
                Text(title)
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                ForEach(lines.indices, id: \.self) { index in
                    HStack(spacing: MuseSpacing.xs) {
                        HStack(spacing: 3) {
                            ForEach(lines[index].0.indices, id: \.self) { dot in
                                Circle()
                                    .fill(lines[index].0[dot])
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 16, alignment: .leading)
                        Text(lines[index].1)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): " + lines.map { line in
            let color = line.0.first == MuseColor.moss600 ? "green" : "amber"
            return "\(line.0.count == 2 ? "two \(color)" : color), \(line.1)"
        }.joined(separator: ". "))
    }

    // MARK: Music, reset, care

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            MuseEyebrow(title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.vertical, MuseSpacing.sm)
    }

    /// A gesture and what it does: the result on the right, or under the name when
    /// it's a sentence (`stacked`).
    private func row(
        _ gesture: RingGestureMark.Gesture,
        _ name: String,
        _ result: String,
        stacked: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
            RingGestureMark(gesture, color: MuseColor.ink)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            if stacked {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink)
                    Text(result)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                Text(name)
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MuseSpacing.sm)
                Text(result)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(result)")
    }

    private var divider: some View {
        Rectangle()
            .fill(MuseColor.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#Preview("cheat card") {
    ScrollView {
        RingCheatCard()
            .padding(MuseSpacing.page)
    }
    .background { MuseBackground() }
}
