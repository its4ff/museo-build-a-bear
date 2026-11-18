import SwiftUI

/// The small sheet that says what changed in a newer museo. Opened from the panel's line, or
/// by "check for updates" when it finds one.
struct UpdateWindow: View {
    static let id = "update"

    @Environment(\.dismissWindow) private var dismissWindow
    private let model = UpdateModel.shared

    var body: some View {
        Group {
            if let offer = model.offer {
                UpdateCard(offer: offer) {
                    if offer.stage == .ready { Updates.restart() } else { Updates.install() }
                    dismissWindow(id: Self.id)
                } later: {
                    dismissWindow(id: Self.id)
                }
            } else {
                // The offer went away while the sheet was open.
                Color.clear
                    .frame(width: UpdateMetrics.card.width, height: UpdateMetrics.card.height)
                    .onAppear { dismissWindow(id: Self.id) }
            }
        }
        .onAppear { DockPresence.opened() }
        .onDisappear { DockPresence.closed() }
    }
}
