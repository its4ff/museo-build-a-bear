import SwiftUI
import UIKit
import MuseoKit

/// Build: the builder's tools and settings. Speech, ring tools, your data, about.
///
/// Opened from the hammer on home (`router.open(.build())`), or straight at a section
/// (`router.open(.build(.ring))`). Every section reads its data
/// from the environment, so lab screens show it with fixtures. The live-only parts (the
/// ring console, the firmware updater over build) are only offered when the real ring
/// kit is there: in the live app, `RootView` hands in the manager and the updater
/// (`.liveRingManager()`, which passes `Museo.manager`, and
/// `.environmentObject(Museo.firmware)`).
struct BuildView: View {
    var initialSection: BuildSection?

    @Environment(AppRouter.self) private var router
    @State private var path: [BuildRoute] = []
    @State private var toast: String?
    /// The root reappears every time a pushed page pops, so the jump to `initialSection`
    /// happens once, not on every way back.
    @State private var didJump = false
    /// The firmware updater, over build rather than instead of it, so build (and wherever
    /// you were in it) is still there when the update is done. Live app only.
    @State private var showFirmware = false

    init(initialSection: BuildSection? = nil) {
        self.initialSection = initialSection
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: MuseSpacing.sectionLabel) {
                        MuseHeader(
                            title: "build with museo.",
                            subtitle: "local tools & settings for building on museo."
                        )
                        sections
                        BuildSignOff()
                    }
                    .padding(.horizontal, MuseSpacing.page)
                    .padding(.bottom, MuseSpacing.sectionLabel)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
                // Room between the close button and the page, inside the bar: a section
                // jumped to lands clear of the button and the fade, not under them.
                .safeAreaPadding(.top, MuseSpacing.lg)
                .safeAreaBar(edge: .top, spacing: 0) {
                    // Close sits where the hammer was, so the way out is where the way in was.
                    BuildTopChrome("xmark", label: "close build") { router.close() }
                }
                .museBottomBlur()
                .background { MuseBackground() }
                .onAppear {
                    guard !didJump else { return }
                    didJump = true
                    jump(to: initialSection, with: proxy)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BuildRoute.self) { route in
                BuildDestination(route: route)
            }
        }
        .tint(MuseColor.ink)
        // No icon: one quiet note for every section's news.
        .museToast($toast)
        .sheet(isPresented: $showFirmware) {
            LiveFirmwareSheet(isPresented: $showFirmware)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var sections: some View {
        SpeechSection()
            .id(BuildSection.speech)
        RingToolsSection(toast: $toast, showFirmware: $showFirmware)
            .id(BuildSection.ring)
        MusesDataSection(toast: $toast)
            .id(BuildSection.muses)
        AboutSection()
            .id(BuildSection.about)
    }

    /// Lands on the asked-for section without a scroll animation: the sheet is still
    /// rising, and a second motion on top of it reads as a stumble.
    private func jump(to section: BuildSection?, with proxy: ScrollViewProxy) {
        guard let section else { return }
        proxy.scrollTo(section, anchor: .top)
    }
}

// MARK: - Routes

/// The pages build pushes. `NavigationLink(value: BuildRoute.console) { … }` from any
/// section; `BuildView` maps each to its view.
enum BuildRoute: Hashable {
    /// Live values from the ring kit. Live app only.
    case console
}

private struct BuildDestination: View {
    let route: BuildRoute

    var body: some View {
        Group {
            switch route {
            case .console: RingConsoleView()
            }
        }
        .buildPushedPage()
    }
}

/// The firmware updater as a sheet over build. Live app only: it reads the one updater
/// `RootView` owns, which lab screens and previews never carry.
private struct LiveFirmwareSheet: View {
    @Binding var isPresented: Bool

    @EnvironmentObject private var firmware: RingFirmwareUpdater
    @Environment(RingModel.self) private var ring
    @Environment(AppRouter.self) private var router

    var body: some View {
        FirmwareSheet(
            firmware: firmware,
            canUpdate: ring.status.isLinked,
            onNeedRing: { router.open(.ring) },
            onClose: { isPresented = false }
        )
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(firmware.phase.isBusy)
        // Same promise as the updater on its own: while the ring is half written, ask the
        // router to hold anything else that wants to open.
        .onChange(of: firmware.phase.isBusy, initial: true) { _, busy in router.hold(busy) }
        .onDisappear { router.hold(false) }
    }
}

// MARK: - Top chrome

/// Build's top row: one chrome circle on the page gutter, nothing else. The build root
/// puts its close here, every pushed page its back.
struct BuildTopChrome: View {
    let systemName: String
    let label: String
    let action: () -> Void

    init(_ systemName: String, label: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    var body: some View {
        HStack {
            MuseChromeIcon(systemName, label: label, action: action)
            Spacer()
        }
        // The circle's edge sits on the gutter; its 44pt target overhangs it.
        .padding(.horizontal, MuseSpacing.page - (MuseTopChrome.hitTarget - MuseTopChrome.circle) / 2)
        .padding(.top, MuseSpacing.sm)
        .padding(.bottom, MuseSpacing.xxs)
    }
}

extension View {
    /// A page pushed inside build: no system bar (its glass back button sits off the
    /// gutter and over the words), build's own back circle instead, and the edge swipe
    /// back kept working. Pair it with `.scrollEdgeEffectStyle(.soft, for: .top)` on the
    /// page's `ScrollView` so words fade under the circle.
    func buildPushedPage() -> some View {
        modifier(BuildPushedPage())
    }

    /// Keeps the edge swipe that goes back on a page whose navigation bar is hidden.
    /// `buildPushedPage()` includes it; use it alone on a page that draws its own close.
    func buildSwipeBack() -> some View {
        background { BuildSwipeBack().accessibilityHidden(true) }
    }
}

private struct BuildPushedPage: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .top, spacing: 0) {
                BuildTopChrome("chevron.left", label: "back") { dismiss() }
            }
            .buildSwipeBack()
    }
}

/// Hiding the navigation bar can switch off the edge swipe back. This finds the stack's
/// navigation controller and lets the swipe start whenever there is a page to go back to
/// (never on the root, where a pop has nowhere to land).
private struct BuildSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            install()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            install()
        }

        private func install() {
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            if pop.delegate !== BuildSwipeBackDelegate.shared {
                pop.delegate = BuildSwipeBackDelegate.shared
            }
            pop.isEnabled = true
        }
    }
}

/// One delegate for the app's lifetime, so the gesture never points at a page that's gone.
private final class BuildSwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = BuildSwipeBackDelegate()

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gesture.view
        while let next = responder, !(next is UINavigationController) {
            responder = next.next
        }
        guard let navigation = responder as? UINavigationController else { return false }
        return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }
}

// MARK: - Shared pieces

/// Live app, or a lab screen or Xcode preview. Lab screens and previews never carry the
/// real `RingBLEManager` (or the firmware updater), so the parts that need it (the ring
/// console, clearing the ring, the updater over build, wiping speech's files) are only
/// offered when this is true.
enum BuildEnvironment {
    static var hasRingManager: Bool {
        #if DEBUG
        MuseLab.requested == nil
            && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
        #else
        true
        #endif
    }
}

/// One build section: its header rule, then its content.
struct BuildBlock<Content: View, Trailing: View>: View {
    let section: BuildSection
    let trailing: Trailing
    let content: Content

    init(
        _ section: BuildSection,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader(section.title) { trailing }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension BuildBlock where Trailing == EmptyView {
    init(_ section: BuildSection, @ViewBuilder content: () -> Content) {
        self.init(section, trailing: { EmptyView() }, content: content)
    }
}

/// A quiet line under a section: small print that explains, never instructs.
/// `backticks` set a Swift name in mono.
struct BuildFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(String.buildMarkdown(text))
            .font(MuseType.meta)
            .lineSpacing(MuseType.bodyLineSpacing)
            .foregroundStyle(MuseColor.ink55)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MuseSpacing.xxs)
    }
}

/// A text row for the page's irreversible action (delete every muse). Quieter than a
/// `MuseListRow` on purpose: no card, no chevron, Satoshi not Lora.
///
/// Clay by default: build's one clay mark. Pass `tint: MuseColor.ink` for another
/// irreversible row, so the clay stays single (its dialog still says it's for good).
struct BuildDestructiveRow: View {
    let title: String
    let meta: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    init(
        title: String,
        meta: String,
        systemImage: String,
        tint: Color = MuseColor.clay,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.meta = meta
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            HStack(alignment: .center, spacing: MuseSpacing.row) {
                Image(systemName: systemImage)
                    .museSymbol(14, weight: .medium)
                    .foregroundStyle(tint)
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MuseType.label)
                        .foregroundStyle(tint)
                    Text(meta)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: MuseSpacing.xs)
            }
            .padding(.horizontal, MuseSpacing.card)
            .padding(.vertical, MuseSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.42)
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// For a `NavigationLink` or `ShareLink` wrapped around a `MuseListRow` (which is a bare
    /// label without an action): the row's press and its soft tap, like a row with one.
    func buildRowLink() -> some View {
        buttonStyle(BuildRowLinkStyle())
            .simultaneousGesture(TapGesture().onEnded { MuseHaptics.play(.soft) })
    }
}

/// A row inside a `MuseListCard` gets the faint ink wash rows use; a lone row (its own
/// card) settles a touch instead, so the card never shows a wash behind it.
struct BuildRowLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BuildRowLinkBody(isPressed: configuration.isPressed, label: configuration.label)
    }
}

private struct BuildRowLinkBody<Label: View>: View {
    let isPressed: Bool
    let label: Label

    @Environment(\.museInListCard) private var inCard

    var body: some View {
        label
            .background {
                if inCard && isPressed { MuseColor.ink.opacity(0.04) }
            }
            .scaleEffect(!inCard && isPressed ? 0.98 : 1)
            .animation(MuseMotion.press, value: isPressed)
            .onChange(of: isPressed) { _, down in
                if down { MuseHaptics.prepare() }
            }
    }
}

extension String {
    /// Copy with `backticks` around Swift names, as an attributed string: the names draw in
    /// mono, the rest in the view's font. Falls back to the plain text.
    static func buildMarkdown(_ text: String, code: Font = MuseFont.mono(.caption)) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var attributed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        let codeRanges = attributed.runs
            .filter { $0.inlinePresentationIntent?.contains(.code) == true }
            .map(\.range)
        for range in codeRanges {
            attributed[range].font = code
        }
        return attributed
    }
}

/// The page's last line.
private struct BuildSignOff: View {
    var body: some View {
        VStack(spacing: MuseSpacing.xs) {
            MuseRingMark(size: 16, color: MuseColor.ink55)
            Text("that's everything.")
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MuseSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
