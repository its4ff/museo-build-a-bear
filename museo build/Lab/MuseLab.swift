#if DEBUG
import SwiftUI

/// muse lab: launch straight into a mock screen with `-museLab <id>`.
/// No ring, no stores, no prompts. `scripts/lab.sh` drives it:
///
/// ```sh
/// scripts/lab.sh                      # build, then screenshot every screen to lab-shots/
/// scripts/lab.sh shots home.feed      # one screen, no build
/// scripts/lab.sh index                # browse every screen in the simulator by hand
/// ```
///
/// Add a screen in `LabRegistry` (a real view, fed `LabFixtures` through `LabStage`).
enum MuseLab {
    static var requested: String? {
        guard let value = UserDefaults.standard.string(forKey: "museLab"), !value.isEmpty else { return nil }
        return value
    }
}

/// The lab's whole app: `manifest` writes the screen list, `index` is a browsable list,
/// anything else is that screen. Once it has settled it writes `Documents/lab-ready`, which
/// `scripts/lab.sh` waits for before it takes the screenshot.
struct LabRoot: View {
    let id: String

    var body: some View {
        content
            .task {
                if id == "manifest" { LabFiles.writeManifest() }
                try? await Task.sleep(for: LabRegistry.screen(id)?.settle ?? .milliseconds(900))
                LabFiles.writeReady(id)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch id {
        case "manifest":
            LabManifestView()
        case "index":
            LabIndexView()
        default:
            if let screen = LabRegistry.screen(id) {
                screen.make()
            } else {
                LabMissingView(id: id)
            }
        }
    }
}

/// The files `scripts/lab.sh` reads, in the app's Documents folder.
enum LabFiles {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// `lab-ready` holds the id of the screen that has settled.
    static func writeReady(_ id: String) {
        let url = documents.appendingPathComponent("lab-ready")
        try? Data(id.utf8).write(to: url, options: .atomic)
    }

    /// `lab-manifest.json`: every screen as `{id, title, note}`, in registry order.
    static func writeManifest() {
        let rows: [[String: String]] = LabRegistry.all.map {
            ["id": $0.id, "title": $0.title, "note": $0.note]
        }
        let url = documents.appendingPathComponent("lab-manifest.json")
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Manifest and missing

private struct LabManifestView: View {
    var body: some View {
        ZStack {
            MuseBackground()
            VStack(spacing: MuseSpacing.sm) {
                Text("muse lab.")
                    .font(MuseType.title)
                    .foregroundStyle(MuseColor.ink)
                Text("\(LabRegistry.all.count) screens written to the manifest")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
        }
    }
}

private struct LabMissingView: View {
    let id: String

    var body: some View {
        ZStack {
            MuseBackground()
            VStack(spacing: MuseSpacing.sm) {
                Text("no lab screen called \(id).")
                    .font(MuseType.serif)
                    .foregroundStyle(MuseColor.ink70)
                Text("scripts/lab.sh index lists them all")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
            .padding(.horizontal, MuseSpacing.page)
        }
    }
}

// MARK: - Index

/// Every screen, grouped, for browsing in the simulator by hand. A screen opens over the
/// list; the round close button at the bottom brings the list back.
private struct LabIndexView: View {
    @State private var open: LabOpen?

    private var groups: [String] {
        var seen: [String] = []
        for screen in LabRegistry.all where !seen.contains(screen.group) {
            seen.append(screen.group)
        }
        return seen
    }

    var body: some View {
        ZStack {
            MuseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: MuseSpacing.section) {
                    MuseHeader(
                        eyebrow: "debug",
                        title: "muse lab.",
                        subtitle: "every screen on real museo build parts, fed sample muses. no ring needed."
                    )
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                            MuseSectionHeader(group, count: LabRegistry.all.filter { $0.group == group }.count)
                            MuseListCard {
                                ForEach(LabRegistry.all.filter { $0.group == group }) { screen in
                                    MuseListRow(screen.title, meta: "\(screen.id) · \(screen.note)") {
                                        open = LabOpen(id: screen.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, MuseSpacing.page)
                .padding(.top, MuseSpacing.xl)
                .padding(.bottom, MuseSpacing.sectionLabel)
            }
            .scrollIndicators(.hidden)
            .museBottomBlur()
        }
        .fullScreenCover(item: $open) { item in
            ZStack(alignment: .bottomLeading) {
                if let screen = LabRegistry.screen(item.id) {
                    screen.make()
                }
                MuseChromeIcon("xmark", label: "back to the lab") { open = nil }
                    .padding(.leading, MuseSpacing.page - (MuseTopChrome.hitTarget - MuseTopChrome.circle) / 2)
                    .padding(.bottom, MuseSpacing.xs)
            }
        }
    }
}

private struct LabOpen: Identifiable {
    let id: String
}
#endif
