import SwiftUI
import MuseoKit

/// Build › ring: firmware and the ring console. Clearing the ring lives in the ring sheet.
///
/// The section reads the ring through `RingModel` (lab hands in a fixture). Only the parts
/// that talk to the ring itself (the console, the updater over build) reach for the real
/// ring kit, and only in the live app.
struct RingToolsSection: View {
    @Binding var toast: String?
    /// Raised to show the firmware updater over build (live app). Lab screens and previews
    /// have no updater, so they open it through the router instead.
    @Binding var showFirmware: Bool

    @Environment(AppRouter.self) private var router
    @Environment(RingModel.self) private var ring

    var body: some View {
        let status = ring.status
        BuildBlock(.ring) {
            MuseListCard {
                MuseListRow(
                    title: "update firmware",
                    meta: status.isFirmwareUpdating
                        ? "updating now · keep it close"
                        : "bundled \(BundledFirmware.version) · \(BundledFirmware.stamp)",
                    systemImage: "arrow.down.circle"
                ) {
                    if BuildEnvironment.hasRingManager {
                        showFirmware = true
                    } else {
                        router.open(.firmware)
                    }
                }
                consoleRow
            }
        }
    }

    /// The console needs the real ring kit, so the lab gets the row without the page.
    @ViewBuilder
    private var consoleRow: some View {
        if BuildEnvironment.hasRingManager {
            NavigationLink(value: BuildRoute.console) { consoleLabel(action: nil) }
                .buildRowLink()
        } else {
            consoleLabel { toast = "the console opens with a real ring." }
        }
    }

    private func consoleLabel(action: (() -> Void)?) -> MuseListRow {
        MuseListRow(
            title: "ring console",
            meta: "every value the ring kit reports, as it changes",
            systemImage: "terminal",
            action: action
        )
    }
}
