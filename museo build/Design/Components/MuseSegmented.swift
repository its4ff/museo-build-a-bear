import SwiftUI

/// A quiet page filter or setting with two to four choices. Paper when selected.
/// Not a primary button.
struct MuseSegmented<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [(Option, String)]
    var fillsWidth: Bool

    @Namespace private var lift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(selection: Binding<Option>, options: [(Option, String)], fillsWidth: Bool = false) {
        _selection = selection
        self.options = options
        self.fillsWidth = fillsWidth
    }

    var body: some View {
        // One row while the labels fit; stacked when large text would cut them off.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) { segments(stacked: false) }
                .padding(3)
                .background { Capsule().fill(MuseColor.ink.opacity(0.05)) }
            VStack(spacing: 2) { segments(stacked: true) }
                .padding(3)
                .background {
                    RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                        .fill(MuseColor.ink.opacity(0.05))
                }
        }
    }

    private func segments(stacked: Bool) -> some View {
        ForEach(options.indices, id: \.self) { index in
            segment(options[index].0, title: options[index].1, stacked: stacked)
        }
    }

    private func segment(_ option: Option, title: String, stacked: Bool) -> some View {
        let on = option == selection
        // Concentric with the well's 3pt inset when stacked.
        let shape = stacked
            ? AnyShape(RoundedRectangle(cornerRadius: MuseRadius.control - 3, style: .continuous))
            : AnyShape(Capsule())
        return Button {
            guard !on else { return }
            MuseHaptics.play(.soft)
            withAnimation(MuseMotion.adaptive(MuseMotion.select, reduceMotion: reduceMotion)) {
                selection = option
            }
        } label: {
            // One line, so the row measures each label's full width before it picks.
            Text(title)
                .font(MuseType.meta)
                .lineLimit(1)
                .minimumScaleFactor(stacked ? 0.8 : 1)
                .foregroundStyle(on ? MuseColor.ink : MuseColor.ink70)
                .padding(.horizontal, MuseSpacing.sm)
                .frame(maxWidth: fillsWidth || stacked ? .infinity : nil, minHeight: MuseTopChrome.circle)
                .background {
                    if on {
                        shape
                            .fill(MuseColor.raised)
                            .shadow(color: MuseColor.ink.opacity(0.09), radius: 1, x: 0, y: 1)
                            // Each layout lifts its own paper, so the hidden one never
                            // claims the same match.
                            .matchedGeometryEffect(id: stacked ? "lift.stacked" : "lift", in: lift)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.96))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
