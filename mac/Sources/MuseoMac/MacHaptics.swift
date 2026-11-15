import Foundation

/// The house haptics, silent on a mac: a trackpad has no tap to feel for a button, so the
/// shared design components (`MusePressStyle`) call these and nothing happens.
enum MuseHaptics {
    nonisolated enum Kind: CaseIterable, Sendable {
        case soft, light, medium, rigid, selection, success, warning, error, sent, received, tick, done
    }

    static func play(_ kind: Kind) {}

    static func prepare() {}
}
