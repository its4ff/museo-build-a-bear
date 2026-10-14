import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Copy and share for one muse, as menu items. The home's long press and the muse page's
/// menu use these same ones, so a muse leaves the app the same way from anywhere.
///
/// ```swift
/// .contextMenu { MuseExportActions(muse: muse) { toast = $0 } }
/// Menu { MuseExportActions(muse: muse, parts: .share) } label: { … }   // just the shares
/// ```
///
/// What each one puts out is in `Model/MuseShare.swift`: plain text with a one-line header
/// for shares, no header for copies, and the audio as a wav named after the muse.
struct MuseExportActions: View {
    /// Which items to list: everything, only the copies, or only the shares.
    nonisolated enum Parts: Sendable {
        case all
        case copy
        case share
    }

    let muse: Muse
    var parts: Parts = .all
    /// Called after a copy with a line for a toast: "notes copied.", "words copied.".
    var onCopied: (String) -> Void = { _ in }

    var body: some View {
        if parts != .share {
            copies
        }
        if parts == .all, hasCopies, hasShares {
            Divider()
        }
        if parts != .copy {
            shares
        }
    }

    // MARK: Items

    private var hasCopies: Bool { muse.copyNotes != nil || muse.copyWords != nil }
    private var hasShares: Bool { muse.shareNotes != nil || muse.shareWords != nil || muse.audioURL != nil }

    @ViewBuilder
    private var copies: some View {
        if let notes = muse.copyNotes {
            Button {
                copy(notes, note: "notes copied.")
            } label: {
                Label("copy notes", systemImage: "list.bullet")
            }
        }
        if let words = muse.copyWords {
            Button {
                copy(words, note: "words copied.")
            } label: {
                Label("copy words", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private var shares: some View {
        if let text = muse.shareNotes {
            ShareLink(item: text, subject: Text(muse.shareSubject)) {
                Label("share notes", systemImage: "list.bullet")
            }
        }
        if let text = muse.shareWords {
            ShareLink(item: text, subject: Text(muse.shareSubject)) {
                Label("share words", systemImage: "text.alignleft")
            }
        }
        if let audio = MuseAudioExport(muse) {
            ShareLink(item: audio, preview: SharePreview(muse.shareSubject)) {
                Label("share audio", systemImage: "waveform")
            }
        }
    }

    private func copy(_ text: String, note: String) {
        UIPasteboard.general.string = text
        MuseHaptics.play(.success)
        onCopied(note)
    }
}

/// A muse's audio as a file to share: a wav named after the muse ("call mum about
/// sunday.wav"), copied to a temporary folder only when the share sheet asks for it.
nonisolated struct MuseAudioExport: Transferable {
    let url: URL
    let name: String

    /// Nil when the muse has no audio on this iphone (typed, sample, or its file is gone).
    @MainActor
    init?(_ muse: Muse) {
        guard let url = muse.audioURL else { return nil }
        self.url = url
        let cleaned = muse.shareSubject
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = String((cleaned.isEmpty ? "muse" : cleaned).prefix(60))
    }

    /// Starts with `MuseExport`'s prefix, so its sweep removes these too.
    static let folderPrefix = "muse-export-share-"

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .wav) { export in
            // One shared copy at a time, named so delete everything and the launch sweep
            // (`MuseExport.removeExports`) find it: earlier copies go first.
            let files = FileManager.default
            if let old = try? files.contentsOfDirectory(at: files.temporaryDirectory, includingPropertiesForKeys: nil) {
                for url in old where url.lastPathComponent.hasPrefix(Self.folderPrefix) {
                    try? files.removeItem(at: url)
                }
            }
            let folder = files.temporaryDirectory
                .appendingPathComponent("\(Self.folderPrefix)\(UUID().uuidString.lowercased())", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent("\(export.name).wav")
            try FileManager.default.copyItem(at: export.url, to: copy)
            return SentTransferredFile(copy)
        }
    }
}
