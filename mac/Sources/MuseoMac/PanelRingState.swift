import MuseoKit

extension PocketRingState {
    /// What the ring pill shows for the real ring. Anything but linked reads as away;
    /// linked, the first that holds of: a hold (streaming, with `words` so far), bringing
    /// in, recording to its memory, on the charger, then plain linked with its battery.
    ///
    /// A battery not read yet comes through as 0: check `status.battery` before showing a
    /// percent.
    init(_ status: RingStatus, words: String = "") {
        guard status.isLinked else {
            self = .away
            return
        }
        if status.isLive {
            self = .streaming(words: words)
        } else if status.isSyncing {
            let total = max(status.syncTotal, 1)
            let left = min(max(status.waiting, 1), total)
            self = .bringingIn(done: total - left, total: total)
        } else if status.isRecordingOnRing {
            self = .memory
        } else if status.showsCharging {
            self = .charging(level: status.battery ?? 0)
        } else {
            self = .linked(battery: status.battery ?? 0)
        }
    }
}
