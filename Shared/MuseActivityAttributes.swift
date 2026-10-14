import ActivityKit
import Foundation

/// Shared between the app and the widget extension. Keep this file tiny.

/// The ring is mid-capture. The lock screen counts up from `startedAt`.
nonisolated struct MuseCaptureActivityAttributes: ActivityAttributes {
    var startedAt: Date

    nonisolated struct ContentState: Codable, Hashable, Sendable {}
}

/// The ring handing its offline recordings to the phone.
nonisolated struct MuseSyncActivityAttributes: ActivityAttributes {
    var startedAt: Date

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var done: Int
        var total: Int
    }
}
