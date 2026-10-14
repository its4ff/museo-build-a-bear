import MuseoKit

// MARK: - Making room on a nearly full ring

extension RingStatus {
    /// What frees a nearly full ring.
    nonisolated enum Room: Equatable, Sendable {
        /// Recordings are waiting: bring them in first (clearing would lose them).
        case bringIn
        /// Nothing is waiting. The ring keeps a copy of everything that came in ("clear the
        /// ring once they're safe" starts off), so it fills anyway; clearing makes room.
        case clear
    }

    /// Nil unless the ring is linked, nearly full and idle enough to act on it. `waiting`
    /// counts high before a file list, so this leans toward bringing in.
    var room: Room? {
        guard isLinked, isStorageLow, !isLive, !isRecordingOnRing, !isFirmwareUpdating else { return nil }
        return waiting > 0 || isSyncing ? .bringIn : .clear
    }
}
