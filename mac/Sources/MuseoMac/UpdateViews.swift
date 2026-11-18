import SwiftUI

/// A newer museo, as museo would say it: which version, what changed, and how far along it
/// is. Drawn by `PanelUpdateRow` and `UpdateCard`.
nonisolated struct UpdateOffer: Equatable, Sendable {
    var version: String
    /// A few short lines on what changed, lowercase, in museo's voice.
    var notes: [String] = []
    var size: String?
    var stage = Stage.offered

    nonisolated enum Stage: Equatable, Sendable {
        case offered
        case comingDown(Double)
        /// Downloaded and checked: it goes in when museo restarts.
        case ready
    }
}

nonisolated enum UpdateMetrics {
    static let dot: CGFloat = 6
    static let card = CGSize(width: 400, height: 348)
    static let mark: CGFloat = 44
    static let markDots = 25
    static let title: CGFloat = 30
    static let titleTracking: CGFloat = -0.7
    static let button: CGFloat = 40
    static let dune = 0.5
}

/// The quiet way: one line under the ring in the menu bar panel. No window, nothing in the
/// way. It waits there until you take it.
struct PanelUpdateRow: View {
    let offer: UpdateOffer
    /// "update" or "restart" was pressed.
    var update: () -> Void = {}
    /// The line itself was pressed: say what changed.
    var more: () -> Void = {}

    var body: some View {
        HStack(spacing: MuseSpacing.xs) {
            Circle()
                .fill(MuseColor.moss600)
                .frame(width: UpdateMetrics.dot, height: UpdateMetrics.dot)
                .accessibilityHidden(true)
            Button(action: more) {
                Text(line)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
                    .lineLimit(1)
                    .frame(height: MuseSpacing.section)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("what's new")
            Spacer(minLength: MuseSpacing.xs)
            if let action {
                Button(action: update) {
                    Text(action)
                        .font(MuseType.metaMedium)
                        .foregroundStyle(MuseColor.moss600)
                        .frame(height: MuseSpacing.section)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MusePressStyle())
            }
        }
        .frame(height: MuseSpacing.section)
    }

    private var line: String {
        switch offer.stage {
        case .offered: "museo \(offer.version) is here"
        case .comingDown(let share): "bringing in \(offer.version) · \(Int(share * 100))%"
        case .ready: "museo \(offer.version) is ready"
        }
    }

    private var action: String? {
        switch offer.stage {
        case .offered: "update"
        case .comingDown: nil
        case .ready: "restart"
        }
    }
}

/// The fuller way: a small sheet of the dune that says what changed, for the first time a
/// version is offered or when you ask "what's new".
struct UpdateCard: View {
    let offer: UpdateOffer
    var update: () -> Void = {}
    var later: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PocketHalftoneRing(size: UpdateMetrics.mark, ink: MuseColor.moss, dots: UpdateMetrics.markDots)
                .accessibilityHidden(true)
            Text("a new museo.")
                .font(MuseFont.lora(UpdateMetrics.title))
                .tracking(UpdateMetrics.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .padding(.top, MuseSpacing.md)
                .accessibilityAddTraits(.isHeader)
            Text([offer.version, offer.size].compactMap { $0 }.joined(separator: " · "))
                .font(MuseFont.mono(.caption))
                .foregroundStyle(MuseColor.ink55)
                .padding(.top, MuseSpacing.xxs)
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                ForEach(offer.notes, id: \.self) { note in
                    Text(note)
                        .font(MuseType.body)
                        .foregroundStyle(MuseColor.ink70)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, MuseSpacing.lg)
            Spacer(minLength: MuseSpacing.lg)
            HStack(spacing: MuseSpacing.md) {
                Button(action: update) {
                    Text(offer.stage == .ready ? "restart" : "update")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ground)
                        .padding(.horizontal, MuseSpacing.section)
                        .frame(height: UpdateMetrics.button)
                        .background(MuseColor.primaryGradient, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(MusePressStyle())
                .keyboardShortcut(.defaultAction)
                Button(action: later) {
                    Text("later")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(height: UpdateMetrics.button)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 0)
                Text("museo restarts. your muses stay.")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .padding(MuseSpacing.xl)
        .frame(width: UpdateMetrics.card.width, height: UpdateMetrics.card.height, alignment: .topLeading)
        .background { PocketGround(strength: UpdateMetrics.dune, stipple: LibraryWindow.ground.stipple, fine: true) }
        .preferredColorScheme(.light)
    }
}
