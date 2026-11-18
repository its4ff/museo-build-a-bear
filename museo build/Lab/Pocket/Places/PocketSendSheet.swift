#if DEBUG
import SwiftUI

/// "send to…": the places that can take a thought out, as plain rows. One is chosen, and
/// the one button says what will happen. museo.fm is the only public one, so choosing it
/// never sends: it leads to the give sheet, which asks.
struct PocketSendSheet: View {
    let thought: PocketThought

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: PocketPlace
    @State private var isGiving = false

    init(thought: PocketThought) {
        self.thought = thought
        _chosen = State(initialValue: Self.places.first { $0.destination == .files } ?? PocketFixtures.journal)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("send to…")
                .font(MuseType.titleSmall)
                .foregroundStyle(MuseColor.ink)
                .padding(.top, MuseSpacing.section)
                .padding(.bottom, MuseSpacing.md)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Self.places) { place in
                    Button {
                        MuseHaptics.play(.soft)
                        chosen = place
                    } label: {
                        row(place)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(place == chosen ? .isSelected : [])
                    if place.id != Self.places.last?.id {
                        Rectangle()
                            .fill(MuseColor.hairline)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }

            Button {
                MuseHaptics.play(.soft)
                if chosen.destination == .fm {
                    isGiving = true
                } else {
                    dismiss()
                }
            } label: {
                PocketPlacesPrimaryLabel(chosen.destination == .fm ? "give to museo.fm…" : "send to \(chosen.name)")
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))
            .padding(.top, MuseSpacing.md)
        }
        .padding(.horizontal, MuseSpacing.xl)
        .padding(.bottom, MuseSpacing.md)
        .museAnimation(MuseMotion.select, value: chosen)
        .sheet(isPresented: $isGiving) {
            PocketGiveSheet(thought: thought)
                .pocketFittedSheet()
        }
    }

    /// The places that send somewhere, and museo.fm last.
    private static let places: [PocketPlace] =
        PocketFixtures.places.filter { $0.sends || $0.destination == .fm }

    private func row(_ place: PocketPlace) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(place.name)
                .font(MuseType.headline)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: MuseSpacing.xs)
            Text(place.destination == .fm ? "public" : place.destination.label)
                .font(MuseType.body)
                .foregroundStyle(place.destination == .fm ? MuseColor.clay : MuseColor.ink55)
            Image(systemName: "checkmark")
                .museSymbol(PocketSendSheetMetrics.check, weight: .semibold)
                .foregroundStyle(MuseColor.moss)
                .opacity(place == chosen ? 1 : 0)
                .accessibilityHidden(true)
        }
        .lineLimit(1)
        .frame(minHeight: PocketSendSheetMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

/// Sizes only this sheet needs: no token fits them.
private nonisolated enum PocketSendSheetMetrics {
    static let rowHeight: CGFloat = 60
    static let check: CGFloat = 13
}

#Preview {
    PocketSendSheet(thought: PocketFixtures.window)
        .background(MuseColor.raised)
}
#endif
