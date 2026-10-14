import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers
import MuseoKit

/// Build › your muses: take everything with you as one json file, or delete it all.
struct MusesDataSection: View {
    @Binding var toast: String?

    @Environment(MuseStore.self) private var store
    @Environment(RingModel.self) private var ring
    @State private var asking = false

    var body: some View {
        let count = store.muses.count
        BuildBlock(.muses) {
            Text(count == 1 ? "1 muse" : "\(count) muses")
                .font(MuseType.captionMedium)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
        } content: {
            ShareLink(
                item: MuseExport(muses: store.muses),
                preview: SharePreview(MuseExport.fileTitle, icon: Image(systemName: "doc.text"))
            ) {
                MuseListRow(
                    title: "export everything",
                    meta: count == 0 ? "nothing to export yet" : "every muse and its timings, one json file",
                    systemImage: "square.and.arrow.up",
                    showsChevron: false
                )
            }
            .buildRowLink()
            .disabled(count == 0)
            .opacity(count == 0 ? 0.42 : 1)

            BuildDestructiveRow(
                title: "delete everything",
                meta: count == 0 ? "nothing here yet" : "every muse, its audio and its words",
                systemImage: "trash"
            ) {
                asking = true
            }
            .disabled(count == 0)
            .confirmationDialog("delete every muse?", isPresented: $asking, titleVisibility: .visible) {
                Button("delete everything", role: .destructive, action: deleteEverything)
                Button("keep them", role: .cancel) {}
            } message: {
                Text(count == 1
                     ? "1 muse, its audio and its words leave this iphone for good."
                     : "\(count) muses, their audio and their words leave this iphone for good.")
            }

            BuildFootnote("muses are saved in `MuseFiles.library`, their audio in `MuseFiles.audio`. the export leaves the audio out.")
        }
    }

    private func deleteEverything() {
        // muses.json can't be read right now: deleting would only clear the screen, and
        // every muse would come back. Say so instead.
        store.reloadIfNeeded()
        guard store.isWritable else {
            MuseHaptics.play(.warning)
            toast = "your muses can't be reached right now. try again in a moment."
            return
        }
        store.removeAll()
        // Word timings clean themselves up through `MuseHooks.onRemoved`. The rest is
        // speech's memory of what it heard, backups of muses.json, and any audio no muse
        // points at; lab screens and previews use a preview store and keep their hands off
        // the real files. While muses.json can't be read (`isWritable` false) the muses in it
        // still own their audio and backups, so those sweeps wait.
        let live = BuildEnvironment.hasRingManager
        let canSweep = store.isWritable
        // Read here, on the main actor, before the work moves off it. A muse can land
        // between the delete and the sweep, so whatever the store still points at stays.
        let kept = Set(store.muses.flatMap { muse in
            [muse.audioURL, muse.sourceURL].compactMap { $0?.lastPathComponent }
        })
        // The age cutoff is taken with `kept`: a file written after this moment is never
        // old enough, however late the sweep below gets to run.
        let settled = Date.now.addingTimeInterval(-LeftoverAudio.settleTime)
        // While the ring streams or syncs, the kit is writing into the audio folder: leave
        // it alone this time. Files still being decoded are caught by the age check.
        let ringIsWriting = ring.status.isLive || ring.status.isSyncing
        if live {
            Task { await SpeechEngine.shared.reset() }
        }
        // Whole folders of audio and json: off the main thread.
        Task.detached(priority: .utility) {
            // The export's json copies hold every word too, wherever it runs.
            MuseExport.removeExports()
            guard live else { return }
            StudioSound.removeAll()
            TimedTranscriptStore.deleteAll()
            guard canSweep else { return }
            LibraryBackups.remove()
            if !ringIsWriting {
                LeftoverAudio.remove(keeping: kept, settled: settled)
            }
        }
        MuseHaptics.play(.done)
        toast = "every muse is gone."
    }
}

// MARK: - Library backups

/// Full copies of muses.json the store set aside (`muses.unreadable-….json`,
/// `muses.partial-….json`). They hold every word, so delete everything takes them too.
nonisolated private enum LibraryBackups {
    static func remove() {
        let files = FileManager.default
        guard let urls = try? files.contentsOfDirectory(at: MuseFiles.library, includingPropertiesForKeys: nil) else { return }
        for url in urls {
            let name = url.lastPathComponent
            guard name.hasPrefix("muses."), name.hasSuffix(".json"), name != "muses.json" else { continue }
            try? files.removeItem(at: url)
        }
    }
}

// MARK: - Leftover audio

/// Recordings in `MuseFiles.audio` that no muse points at: a stream whose decode failed,
/// an offline `.ops` whose wav never got written. Delete everything sweeps them too.
nonisolated private enum LeftoverAudio {
    /// Anything touched this recently may be a capture the kit hasn't handed over yet, or
    /// one the pipeline is still moving: it stays.
    static let settleTime: TimeInterval = 120

    static func remove(keeping kept: Set<String>, settled: Date) {
        let files = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let urls = try? files.contentsOfDirectory(
            at: MuseFiles.audio,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]
        ) else { return }
        for url in urls where !kept.contains(url.lastPathComponent) {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < settled
            else { continue }
            try? files.removeItem(at: url)
        }
    }
}

// MARK: - Export

/// Every muse with its word timings, written as one json file when the share sheet asks
/// for it (not before), into a temporary folder. Only the newest export is kept there, and
/// delete everything removes that one too.
///
/// ```json
/// { "app": "museo build", "exportedAt": "…", "count": 12,
///   "muses": [ { "muse": { "id": "…", "transcript": "…", … }, "timings": { "words": […] } } ] }
/// ```
nonisolated struct MuseExport: Transferable, Sendable {
    let muses: [Muse]

    static let fileTitle = "muses.json"

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            SentTransferredFile(try export.write())
        }
    }

    /// Writes the file and returns where. Reads each muse's timings from disk, so call it
    /// off the main actor (the share sheet does).
    func write() throws -> URL {
        Self.removeExports()
        let file = ExportFile(
            app: "museo build",
            exportedAt: .now,
            count: muses.count,
            muses: muses.map { ExportEntry(muse: $0, timings: TimedTranscriptStore.load($0.id)) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.exportPrefix)\(UUID().uuidString.lowercased())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let day = Date.now.formatted(.iso8601.year().month().day())
        let url = folder.appendingPathComponent("muses-\(day).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Removes every export folder this app left in the temporary directory: json exports
    /// and the wav copies "share audio" makes (`MuseAudioExport`). Runs at launch too.
    static func removeExports() {
        let files = FileManager.default
        guard let children = try? files.contentsOfDirectory(
            at: files.temporaryDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for child in children where child.lastPathComponent.hasPrefix(exportPrefix) {
            try? files.removeItem(at: child)
        }
    }

    static let exportPrefix = "muse-export-"

    nonisolated private struct ExportFile: Encodable {
        let app: String
        let exportedAt: Date
        let count: Int
        let muses: [ExportEntry]
    }

    nonisolated private struct ExportEntry: Encodable {
        let muse: Muse
        let timings: TimedTranscript?
    }
}
