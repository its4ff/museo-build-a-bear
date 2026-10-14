import SwiftUI
import UIKit
import MuseoKit

/// Build › ring › ring console: every public value `RingBLEManager` reports as it changes, plus the
/// AccessorySetupKit log and a few safe commands. For builders debugging the ring.
///
/// Live app only: it reads the real manager from the environment (`.liveRingManager()`
/// at the root hands in `Museo.manager`), which lab screens and Xcode previews never
/// carry. Build only offers it when `BuildEnvironment.hasRingManager` is true.
struct RingConsoleView: View {
    @EnvironmentObject private var ble: RingBLEManager
    @Environment(RingModel.self) private var ring

    @State private var toast: String?

    private var setup: RingSetup { .shared }

    var body: some View {
        let groups = consoleGroups
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.sectionLabel) {
                MuseHeader(
                    title: "ring console.",
                    subtitle: "the ring kit's values as they change. the buttons send real commands to the ring."
                )
                commands
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: MuseSpacing.md) {
                        MuseSectionHeader(group.title)
                        ConsoleTable(rows: group.rows)
                    }
                }
                ringFiles
                setupLog
                Button {
                    UIPasteboard.general.string = Self.snapshot(groups, files: ble.ringFiles, events: setup.events)
                    MuseHaptics.play(.success)
                    toast = "copied every value."
                } label: {
                    Label("copy everything", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MuseButtonStyle(.secondary))
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, MuseSpacing.xs)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .museBottomBlur()
        .background { MuseBackground() }
        .museToast($toast, systemImage: "checkmark")
    }

    // MARK: - Commands

    private var commands: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("ask the ring") {
                Text(ble.isConnected ? "linked" : "not linked")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(ble.isConnected ? MuseColor.moss600 : MuseColor.ink55)
            }
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: MuseSpacing.sm),
                    GridItem(.flexible(), spacing: MuseSpacing.sm),
                ],
                spacing: MuseSpacing.sm
            ) {
                command("read battery", "battery.75percent") { ble.readBatteryLevel() }
                command("list files", "list.bullet") { ble.requestRingFileList() }
                command("request state", "arrow.clockwise") { ble.requestSystemState() }
                command("sync now", "arrow.down.circle", enabled: ble.canStartOfflineSync) {
                    ble.syncOfflineRecordings()
                }
            }
            .disabled(!ble.isConnected)
        }
    }

    private func command(_ title: String, _ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            MuseHaptics.play(.light)
            action()
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MuseButtonStyle(.tinted))
        .disabled(!enabled)
    }

    // MARK: - Files and log

    private var ringFiles: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("ring files", count: ble.ringFiles.isEmpty ? nil : ble.ringFiles.count)
            if ble.ringFiles.isEmpty {
                Text(ble.isListingRingFiles ? "asking the ring\u{2026}" : "none listed. tap list files to ask.")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            } else {
                ConsoleTable(rows: ble.ringFiles.map { file in
                    ConsoleRow(
                        key: file.fileName,
                        value: [Self.bytes(Int(file.size)), file.timestamp.map(Self.time)]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                })
            }
        }
    }

    @ViewBuilder
    private var setupLog: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("accessory setup log", count: setup.events.isEmpty ? nil : setup.events.count)
            if setup.events.isEmpty {
                Text("nothing yet. setting up, linking and removing the ring show up here.")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                MuseCodeLine(setup.events.reversed().joined(separator: "\n"), caption: "newest first")
            }
        }
    }

    // MARK: - Values

    private var consoleGroups: [ConsoleGroup] {
        let status = ring.status
        let state = ble.ringSystemState
        return [
            ConsoleGroup(title: "link", rows: [
                .init(key: "state", value: ble.state.rawValue),
                .init(key: "isConnected", value: Self.flag(ble.isConnected)),
                .init(key: "hasActiveLink", value: Self.flag(ble.hasActiveLink)),
                .init(key: "deviceName", value: ble.deviceName),
                .init(key: "rssi", value: ble.rssi.map { "\($0) dbm" } ?? "nil"),
                .init(key: "connectedRingID", value: Self.id(ble.connectedRingID)),
                .init(key: "preferredPeripheralID", value: Self.id(ble.preferredPeripheralID)),
                .init(key: "discoveredRings", value: "\(ble.discoveredRings.count)"),
                .init(key: "isScanningNearby", value: Self.flag(ble.isScanningNearby)),
            ]),
            ConsoleGroup(title: "battery", rows: [
                .init(key: "batteryPercent", value: ble.batteryPercent.map { "\($0)%" } ?? "nil"),
                .init(key: "batteryIsCharging", value: Self.flag(ble.batteryIsCharging)),
                .init(key: "isBatteryEstimate", value: Self.flag(ble.isBatteryEstimate)),
                .init(key: "batteryReadAt", value: ble.batteryReadAt.map(Self.time) ?? "nil"),
                .init(key: "showsBattery", value: Self.flag(ble.showsBattery)),
            ]),
            ConsoleGroup(title: "capture", rows: [
                .init(key: "isCapturing", value: Self.flag(ble.isCapturing)),
                .init(key: "activeCaptureStartedAt", value: ble.activeCaptureStartedAt.map(Self.time) ?? "nil"),
                .init(key: "captureElapsed", value: ble.captureElapsed.museDuration),
                .init(key: "packetCount", value: "\(ble.packetCount)"),
                .init(key: "byteCount", value: Self.bytes(ble.byteCount)),
                .init(key: "completedCaptures", value: "\(ble.completedCaptures.count) waiting"),
            ]),
            ConsoleGroup(title: "on the ring", rows: [
                .init(key: "ringSystemState.fileCount", value: state.map { "\($0.fileCount)" } ?? "nil"),
                .init(key: "ringSystemState.isRecording", value: state.map { Self.flag($0.isRecording) } ?? "nil"),
                .init(key: "ringSystemState.freeStoragePercent", value: state.map { "\($0.freeStoragePercent)%" } ?? "nil"),
                .init(key: "ringIsRecordingOffline", value: Self.flag(ble.ringIsRecordingOffline)),
                .init(key: "offlineMuseCount", value: "\(ble.offlineMuseCount)"),
                .init(key: "unsyncedRingFiles", value: "\(ble.unsyncedRingFiles.count)"),
            ]),
            ConsoleGroup(title: "sync", rows: [
                .init(key: "isSyncingOffline", value: Self.flag(ble.isSyncingOffline)),
                .init(key: "isDecodingOffline", value: Self.flag(ble.isDecodingOffline)),
                .init(key: "offlineSyncProgress", value: "\(Int((ble.offlineSyncProgress * 100).rounded()))%"),
                .init(key: "offlineQueueRemaining", value: "\(ble.offlineQueueRemaining)"),
                .init(key: "activeOfflineFileName", value: ble.activeOfflineFileName ?? "nil"),
                .init(key: "offlineSyncError", value: ble.offlineSyncError.map(\.museQuiet) ?? "nil"),
                .init(key: "autoSyncOfflineRecordings", value: Self.flag(ble.autoSyncOfflineRecordings)),
                .init(key: "autoClearRingStorage", value: Self.flag(ble.autoClearRingStorage)),
                .init(key: "isOfflineSyncBusy", value: Self.flag(ble.isOfflineSyncBusy)),
                .init(key: "canStartOfflineSync", value: Self.flag(ble.canStartOfflineSync)),
                .init(key: "isFirmwareUpdateInProgress", value: Self.flag(ble.isFirmwareUpdateInProgress)),
            ]),
            ConsoleGroup(title: "accessory setup", rows: [
                .init(key: "RingSetup.isEnabled", value: Self.flag(RingSetup.isEnabled)),
                .init(key: "isReady", value: Self.flag(setup.isReady)),
                .init(key: "authorizedRingID", value: Self.id(setup.authorizedRingID)),
                .init(key: "authorizedName", value: setup.authorizedName ?? "nil"),
                .init(key: "isPickerVisible", value: Self.flag(setup.isPickerVisible)),
                .init(key: "setupError", value: setup.setupError.map(\.museQuiet) ?? "nil"),
            ]),
            ConsoleGroup(title: "what the app shows", rows: [
                .init(key: "RingModel.status.link", value: status.link.rawValue),
                .init(key: "headline", value: status.headline),
                .init(key: "shortLine", value: status.shortLine),
                .init(key: "battery", value: status.battery.map { "\($0)%" } ?? "nil"),
                .init(key: "waiting", value: "\(status.waiting)"),
            ]),
        ]
    }

    nonisolated private static func flag(_ value: Bool) -> String { value ? "true" : "false" }

    /// The first eight hex digits, lowercase: enough to tell rings apart.
    nonisolated private static func id(_ id: UUID?) -> String {
        guard let id else { return "nil" }
        return String(id.uuidString.lowercased().prefix(8)) + "\u{2026}"
    }

    nonisolated private static func time(_ date: Date) -> String {
        "\(date.museClock) · \(date.museRelative)"
    }

    nonisolated private static func bytes(_ count: Int) -> String {
        count < 1024 ? "\(count) b" : String(format: "%.1f kb", Double(count) / 1024)
    }

    /// Everything on the page as plain text, for a bug report.
    private static func snapshot(_ groups: [ConsoleGroup], files: [RingFile], events: [String]) -> String {
        var lines = ["museo build ring console · \(Date.now.formatted(.iso8601))"]
        for group in groups {
            lines.append("")
            lines.append("[\(group.title)]")
            lines += group.rows.map { "\($0.key) = \($0.value)" }
        }
        if !files.isEmpty {
            lines.append("")
            lines.append("[ring files]")
            lines += files.map { "\($0.fileName) = \(bytes(Int($0.size)))" }
        }
        if !events.isEmpty {
            lines.append("")
            lines.append("[accessory setup log]")
            lines += events
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Table

private struct ConsoleGroup: Identifiable {
    let title: String
    let rows: [ConsoleRow]
    var id: String { title }
}

private struct ConsoleRow: Identifiable {
    let key: String
    let value: String
    var id: String { key }
}

/// Mono rows on an inset well: the Swift name on the left, its value on the right.
private struct ConsoleTable: View {
    let rows: [ConsoleRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    Rectangle()
                        .fill(MuseColor.divider)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                    Text(verbatim: row.key)
                        .foregroundStyle(MuseColor.ink55)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(0)
                    Spacer(minLength: MuseSpacing.xs)
                    Text(verbatim: row.value)
                        .foregroundStyle(MuseColor.ink)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .layoutPriority(1)
                }
                .font(MuseType.code)
                .padding(.vertical, MuseSpacing.xs)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museInsetSurface()
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
