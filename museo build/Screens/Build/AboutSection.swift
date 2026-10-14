import SwiftUI
import UIKit

/// Build › about: what this is, who made it, what it stands on, a way to reach its maker
/// (`AppConfig.contact`, when set), and the first run again.
struct AboutSection: View {
    @Environment(\.museShowOnboarding) private var showOnboarding

    var body: some View {
        BuildBlock(.about) {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                card
                MuseListCard {
                    if let contact = AppConfig.contact {
                        MuseListRow(
                            title: contact.title,
                            meta: contact.detail,
                            systemImage: "bubble.left",
                            action: { open(contact.url) }
                        )
                        .accessibilityHint("opens \(contact.url.host() ?? "a link")")
                    }
                    MuseListRow(
                        title: "see the welcome again",
                        meta: "set up, hold, double click, the card",
                        systemImage: "sparkles",
                        action: showOnboarding
                    )
                }
            }
        }
    }

    /// The app for the link when it's installed (a universal link), the browser when not.
    private func open(_ url: URL) {
        Task {
            if await !UIApplication.shared.open(url, options: [.universalLinksOnly: true]) {
                await UIApplication.shared.open(url)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                Text(Self.productName)
                    .font(MuseType.headline)
                    .foregroundStyle(MuseColor.ink)
                Spacer(minLength: MuseSpacing.xs)
                Text(verbatim: Self.version)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                    .textSelection(.enabled)
            }
            Text(AppConfig.madeBy)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink70)
            Text("your muses stay on this phone, until you write code that sends them somewhere else.")
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            Text("speech by apple and desert ant labs · type: lora (ofl), satoshi (itf)")
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MuseSpacing.xxs)
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
        .accessibilityElement(children: .combine)
    }

    /// The app's full name, lowercase: `MUSEO_FULL_NAME` from `Config/`, which is the name
    /// under the icon unless the builder set a longer one.
    private static var productName: String {
        let info = Bundle.main.infoDictionary
        let name = info?["MuseoFullName"] as? String
            ?? info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? "museo"
        return name.lowercased()
    }

    /// "version 2.0 · 14".
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "version \(short) · \(build)"
    }
}
