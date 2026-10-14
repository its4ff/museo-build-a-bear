import AVFoundation
import Foundation
import OSLog
#if canImport(Clear)
import Clear
#endif

/// Studio sound: a cleaner copy of a recording for listening, made on this iphone with
/// Desert Ant's Clear (denoise and dereverb).
///
/// Playback only. The muse's own file, its words and its word timings always stay on
/// the original; denoising before transcription costs accuracy. The copy keeps the
/// original's sample rate (16 khz for the ring) and level (Clear's mastering is
/// bypassed), so `Loudness` still applies and an A/B is at matched volume.
///
/// The first copy fetches Clear's weights once (about 9 mb) and compiles them (about 3
/// seconds). Copies live in `Caches/studio/`, which iOS may clear when space is low.
///
/// ```swift
/// guard let original = muse.audioURL else { return }
/// let url = (try? await StudioSound.shared.cleanCopy(of: original)) ?? original
/// ```
@MainActor
final class StudioSound {
    static let shared = StudioSound()

    nonisolated enum Problem: LocalizedError {
        /// Clear isn't linked in this build.
        case unavailable
        /// Making the copy failed earlier this session; play the original.
        case failed

        var errorDescription: String? {
            switch self {
            case .unavailable: "studio sound isn't part of this build."
            case .failed: "studio sound couldn't clean this one. playing the original."
            }
        }
    }

    /// How hard Clear works, 0...1. Lighter keeps more of the voice's air.
    nonisolated static let strength = 0.7

    nonisolated static var isAvailable: Bool {
        #if canImport(Clear)
        true
        #else
        false
        #endif
    }

    nonisolated static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("studio", isDirectory: true)
    }

    nonisolated private static let log = Logger(subsystem: "museo.build", category: "studio")

    #if canImport(Clear)
    private var model: Clear?
    #endif
    /// One copy at a time: the model already spreads one across its pool.
    private var tail: Task<URL, Error>?
    private var inFlight: [String: Task<URL, Error>] = [:]
    /// Copies that failed this session; asking again would only fail again.
    private var failed: Set<String> = []

    private init() {
        SpeechEngine.keepUsageAnonymous()
    }

    /// The clean copy of `url`, made now if it isn't cached. Throws when Clear is
    /// missing or the copy fails; play the original then.
    func cleanCopy(of url: URL) async throws -> URL {
        #if canImport(Clear)
        guard let target = Self.copyURL(for: url) else { throw SpeechError.unreadableAudio }
        if FileManager.default.fileExists(atPath: target.path) { return target }
        guard !failed.contains(target.path) else { throw Problem.failed }
        if let running = inFlight[target.path] { return try await running.value }

        let previous = tail
        let task = Task<URL, Error> {
            _ = await previous?.result
            try await self.make(source: url, to: target)
            // Deleted while it was being cleaned (its muse went): no copy outlives it.
            guard FileManager.default.fileExists(atPath: url.path) else {
                try? FileManager.default.removeItem(at: target)
                throw Problem.failed
            }
            return target
        }
        tail = task
        inFlight[target.path] = task
        defer { inFlight[target.path] = nil }
        do {
            return try await task.value
        } catch {
            failed.insert(target.path)
            throw error
        }
        #else
        throw Problem.unavailable
        #endif
    }

    /// Fetches and compiles Clear ahead of the first copy (for when the switch turns on).
    func warm() {
        #if canImport(Clear)
        Task { _ = try? await loadedModel() }
        #endif
    }

    /// Deletes every clean copy (build › your muses › delete everything).
    nonisolated static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Deletes every clean copy made from `source`, a half-finished one too. Matches on
    /// the name alone, so it works after the original is gone. `MuseStore.remove` calls it.
    nonisolated static func removeCopies(of source: URL) {
        let stem = source.deletingPathExtension().lastPathComponent
        let files = FileManager.default
        guard let names = try? files.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where isCopy(name, of: stem) {
            try? files.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    /// "<stem>-<size>-<stamp>-studio.wav" (or ".partial.wav") and nothing longer, so
    /// "take-2-…" is never taken for a copy of "take".
    nonisolated static func isCopy(_ name: String, of stem: String) -> Bool {
        guard !stem.isEmpty, name.hasPrefix(stem + "-") else { return false }
        let rest = name.dropFirst(stem.count + 1)
        for ending in ["-studio.wav", "-studio.partial.wav"] where rest.hasSuffix(ending) {
            let numbers = rest.dropLast(ending.count).split(separator: "-", omittingEmptySubsequences: false)
            return numbers.count == 2 && numbers.allSatisfy { part in
                !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber }
            }
        }
        return false
    }

    // MARK: - Making

    /// Keyed on the original's name, size and date, so a replaced file gets a new copy.
    nonisolated private static func copyURL(for source: URL) -> URL? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let size = attributes[.size] as? Int
        else { return nil }
        let stamp = Int((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
        let stem = source.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(stem)-\(size)-\(stamp)-studio.wav")
    }

    #if canImport(Clear)
    private func make(source: URL, to target: URL) async throws {
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        let clear = try await loadedModel()
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try await Self.enhance(clear, source: source, to: target)
    }

    private func loadedModel() async throws -> Clear {
        if let model { return model }
        let started = Date()
        let clear = Clear(variant: .clearStudio)
        try await clear.load()
        if let model { return model }
        model = clear
        Self.log.info("clear ready in \(String(format: "%.1f", Date().timeIntervalSince(started)), privacy: .public)s")
        return clear
    }

    /// The heavy part, off the main actor. Writes to a partial file first, so a copy
    /// cut short never looks finished.
    @concurrent
    nonisolated private static func enhance(_ clear: Clear, source: URL, to target: URL) async throws {
        let partial = target.deletingPathExtension().appendingPathExtension("partial.wav")
        do {
            let rate = try AVAudioFile(forReading: source).fileFormat.sampleRate
            try? FileManager.default.removeItem(at: partial)
            let options = Clear.Options(
                strength: Clear.Strength(strength),
                mastering: .bypass,
                sampleRate: rate
            )
            // A file out streams with flat memory, however long the recording.
            let result = try await clear.enhance(path: source.path, to: partial.path, options: options)
            try FileManager.default.moveItem(at: partial, to: target)
            log.info("""
                studio copy \(source.lastPathComponent, privacy: .public): \
                \(String(format: "%.1f", result.durationSec), privacy: .public)s at \
                \(String(format: "%.0f", rate), privacy: .public) hz, \
                \(String(format: "%.0f", result.realtimeFactor), privacy: .public)x realtime
                """)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            log.error("studio copy failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    #endif
}
