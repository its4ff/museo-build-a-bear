import MuseoKit
import SwiftUI

/// The ring pill at the foot of the library's margin: the same moss pill the iphone wears,
/// saying how the ring is right now. A click opens a small sheet of paper with the ring's
/// own lines and, when recordings wait on it, the row that brings them in.
struct LibraryRingPill: View {
    @State private var isOpen = false

    #if DEBUG
    /// A made-up ring for pictures.
    static var previewRing: RingStatus?
    #endif

    private var ring: RingStatus {
        #if DEBUG
        if let ring = Self.previewRing { return ring }
        #endif
        return RingModel.shared.status
    }

    var body: some View {
        DuoRingPill(state: PocketRingState(ring)) { isOpen.toggle() }
            .help(ring.shortLine)
            .popover(isPresented: $isOpen, arrowEdge: .top) {
                LibraryRingPopover(ring: ring)
            }
    }
}

/// What the pill opens: the ring's headline, its battery and room, and the sync row.
private struct LibraryRingPopover: View {
    let ring: RingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            Text(ring.headline)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Two things with a number, each named: a bare "2 h 12 min left" reads as battery.
            if ring.isLinked {
                VStack(spacing: MuseSpacing.xxs) {
                    if let battery = ring.battery {
                        fact(ring.isCharging ? "battery, charging" : "battery", "\(battery)%")
                    }
                    if let room {
                        fact("storage left on the ring", room)
                    }
                }
            }
            RingSyncRow(ring: ring, actions: .live(openFirmware: {})) {}
        }
        .padding(MuseSpacing.md)
        .frame(width: LibraryMetrics.ringPopover, alignment: .leading)
        .background { MuseBackground().ignoresSafeArea() }
        .environment(\.colorScheme, .light)
    }

    /// How much more the ring's own memory holds: "2 h 12 min", "48 min".
    private var room: String? {
        guard let minutes = ring.minutesLeft else { return nil }
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// One named number: what it is on the left, how much on the right.
    private func fact(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: MuseSpacing.sm)
            Text(value)
                .foregroundStyle(MuseColor.ink)
                .monospacedDigit()
        }
        .font(MuseType.meta)
        .accessibilityElement(children: .combine)
    }

}
