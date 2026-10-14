import Foundation

/// Which of the ring's 30-minute files a memory muse holds.
///
/// The ring cuts one long memory recording into files that share a record number and count
/// up a part number ("07-0000.ops", "07-0100.ops", …). Each part lands as its own muse, then
/// `MuseJoiner` folds the parts back into one. A muse of one part has `first == last`; a
/// joined one covers `first...last`.
///
/// Only `.offline` muses from a dated ring file carry it.
nonisolated struct RingParts: Codable, Equatable, Hashable, Sendable {
    /// The ring's record number (NN, 00 to 99). The ring hands numbers out again after a
    /// delete, so it never names a recording on its own.
    var record: Int
    /// The first part this muse holds (MM).
    var first: Int
    /// The last part this muse holds.
    var last: Int
    /// When the last part started, by the ring's clock.
    var lastStartedAt: Date
    /// The last part's audio, in seconds. A full part holds about 29:27: the ring cuts at 30
    /// minutes of its clock, and its mic runs about 1.77% slow.
    var lastDuration: TimeInterval
}

nonisolated extension RingParts {
    /// The part a fresh memory capture holds, read from the kit's sync key
    /// (`CompletedCapture.offlineSyncKey`, "NN-MM00.ops|<size>|<epoch>"). Nil on anything
    /// unexpected: an undated file, a name that isn't NN-MM00.ops, a date that isn't the
    /// capture's own start, or one from a ring whose clock was never set.
    init?(syncKey: String, startedAt: Date, duration: TimeInterval) {
        let fields = syncKey.split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3, let epoch = Int(fields[2]),
              abs(TimeInterval(epoch) - startedAt.timeIntervalSince1970) < 2,
              startedAt >= Self.clockWasSet
        else { return nil }
        // Two BCD digits of record, two of part, then the ring's reserved byte, always 00.
        let name = Array(fields[0])
        guard name.count == 11, name[2] == "-", name[5] == "0", name[6] == "0",
              String(name[7...]) == ".ops",
              (name[0..<2] + name[3..<5]).allSatisfy({ $0.isASCII && $0.isNumber }),
              let record = Int(String(name[0..<2])), let part = Int(String(name[3..<5])),
              duration > 0
        else { return nil }
        self.init(record: record, first: part, last: part, lastStartedAt: startedAt, lastDuration: duration)
    }

    /// 2025-01-01. After a reset the ring's clock starts again at 2024-01-01, and the kit
    /// stamps files with it as is. Two recordings made after two resets can then sit 30
    /// minutes apart by that clock under a reused record number, so a part stamped before
    /// this never joins: it stays its own muse.
    static let clockWasSet = Date(timeIntervalSince1970: 1_735_689_600)
}
