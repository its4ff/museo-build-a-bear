import AppKit
import SwiftUI

/// The note's words: plain text in Lora, in a column in the middle of the window, with the
/// line you're on held at eye height (blanc's typewriter page). Older lines roll up above it;
/// the page fades them (`NotePage`). Scroll and they come back to read; type and the page
/// returns to the line.
struct EyeLineEditor: NSViewRepresentable {
    @Binding var text: String
    /// Scrolled away from the line, to read back.
    @Binding var isLookingBack: Bool
    /// A hold's words as they form: shown at the caret in soft ink, wrapping like the rest,
    /// but not part of the note until they land.
    var forming: String?
    #if DEBUG
    /// For `ScreenSheet`: the last words caught partway through soaking in.
    var previewLanding = false
    #endif

    static let fontSize: CGFloat = 26
    static let lineHeight: CGFloat = 44
    static let columnWidth: CGFloat = 680

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NoteScrollView {
        let scrollView = NoteScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.onScroll = { [weak coordinator = context.coordinator] in coordinator?.lookBack() }

        // TextKit 1: the eye line reads line rects from the layout manager.
        let textView = EyeLineTextView(usingTextLayoutManager: false)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isAutomaticTextCompletionEnabled = false
        textView.inlinePredictionType = .no
        // No cursor: the page's moss tick marks the line, and a still mark shows only when
        // you move back into the words (`EyeLineTextView.placeNib`).
        textView.insertionPointColor = .clear
        textView.delegate = context.coordinator
        textView.layoutManager?.delegate = context.coordinator
        textView.string = text
        context.coordinator.style(textView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))

        scrollView.documentView = textView
        context.coordinator.watchSize(of: scrollView)
        #if DEBUG
        if previewLanding {
            let length = (text as NSString).length
            let from = max(0, length - 64)
            textView.ink.still(NSRange(location: from, length: length - from), at: 0.42)
        }
        #endif
        return scrollView
    }

    func updateNSView(_ scrollView: NoteScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? EyeLineTextView else { return }
        if textView.committedString != text, !textView.hasMarkedText() {
            textView.string = text
            context.coordinator.style(textView)
            textView.centerCaretLine()
        }
        textView.showForming(forming)
        if !isLookingBack, !textView.isAtEyeLine {
            textView.centerCaretLine()
        }
    }

    static func dismantleNSView(_ scrollView: NoteScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: EyeLineEditor
        private weak var clipView: NSClipView?

        init(_ parent: EyeLineEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? EyeLineTextView else { return }
            // The words still forming aren't the note's yet.
            parent.text = textView.committedString
            if parent.isLookingBack { parent.isLookingBack = false }
            textView.centerCaretLine()
        }

        /// Laid out again (a resize, words forming that wrap): back to the line, unless you're
        /// reading back. Next turn, so the scroll isn't part of the layout pass.
        nonisolated func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd: Bool) {
            guard atEnd else { return }
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.parent.isLookingBack,
                          let textView = self.clipView?.documentView as? EyeLineTextView, !textView.isAtEyeLine else { return }
                    textView.centerCaretLine()
                }
            }
        }

        func lookBack() {
            if !parent.isLookingBack { parent.isLookingBack = true }
        }

        func style(_ textView: EyeLineTextView) {
            let font = NSFont(name: MuseFont.name(.loraRegular), size: EyeLineEditor.fontSize)
                ?? NSFont.systemFont(ofSize: EyeLineEditor.fontSize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = EyeLineEditor.lineHeight
            paragraph.maximumLineHeight = EyeLineEditor.lineHeight
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(MuseColor.ink),
                .paragraphStyle: paragraph,
            ]
            textView.font = font
            textView.defaultParagraphStyle = paragraph
            textView.typingAttributes = attributes
            textView.inkLook = attributes
            if let storage = textView.textStorage, storage.length > 0 {
                storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
            }
        }

        // MARK: - Size

        /// The column in the middle, and half a window above the first line and below the
        /// last, so either can sit at the eye line.
        func watchSize(of scrollView: NSScrollView) {
            let clipView = scrollView.contentView
            self.clipView = clipView
            clipView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(resized), name: NSView.frameDidChangeNotification, object: clipView)
            layout(clipView)
        }

        @objc private func resized() {
            if let clipView { layout(clipView) }
        }

        private func layout(_ clipView: NSClipView) {
            guard let textView = clipView.documentView as? EyeLineTextView else { return }
            let visible = clipView.bounds.size
            let inset = NSSize(
                width: max(MuseSpacing.sectionLabel, (visible.width - EyeLineEditor.columnWidth) / 2),
                height: max(0, (visible.height - EyeLineEditor.lineHeight) / 2)
            )
            if textView.textContainerInset != inset {
                textView.textContainerInset = inset
                textView.sizeToFit()
            }
            textView.minSize = NSSize(width: 0, height: visible.height)
            if textView.frame.width != visible.width || textView.frame.height < visible.height {
                textView.setFrameSize(NSSize(width: visible.width, height: max(textView.frame.height, visible.height)))
            }
            textView.centerCaretLine()
        }
    }
}

/// Tells the page when you scroll yourself (not when the page moves to the line).
final class NoteScrollView: NSScrollView {
    var onScroll: (() -> Void)?

    // MARK: - Full screen

    /// How fast the words leave as the window starts to grow or shrink, and how gently
    /// they come back once it has settled.
    private static let leave: TimeInterval = 0.12
    private static let arrive: TimeInterval = 0.5
    private static let giveUp: TimeInterval = 2.5
    private var watching: [NSObjectProtocol] = []

    /// Going to full screen and back, macOS stretches a picture of the window, and the page
    /// would jump to its new middle at the end. So the words step out for the move and
    /// settle back in at the eye line of the new size.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        watching.forEach(NotificationCenter.default.removeObserver)
        watching = []
        guard let window else { return }
        let center = NotificationCenter.default
        for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification] {
            watching.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fade(to: 0, over: Self.leave) }
                // Should the move never finish, the words still come back.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.giveUp) {
                    if self?.alphaValue == 0 { self?.fade(to: 1, over: Self.arrive) }
                }
            })
        }
        for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
            watching.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    (self?.documentView as? EyeLineTextView)?.centerCaretLine()
                    self?.fade(to: 1, over: Self.arrive)
                }
            })
        }
    }

    private func fade(to alpha: CGFloat, over seconds: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = seconds
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = alpha
        }
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?()
        super.scrollWheel(with: event)
    }
}

/// The text view under the eye line. The open note's view is where a hold's words go
/// (`NoteFocus`), straight in at the caret.
final class EyeLineTextView: NSTextView {
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { NoteFocus.textView = self }
        return became
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            if NoteFocus.textView === self { NoteFocus.textView = nil }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }

    // MARK: - The eye line

    override func scrollRangeToVisible(_ range: NSRange) {
        centerCaretLine()
    }

    /// The caret's line is in the middle of what's shown.
    var isAtEyeLine: Bool {
        guard let clipView = enclosingScrollView?.contentView, let line = caretLineRect() else { return true }
        return abs(clipView.bounds.origin.y - target(line, in: clipView)) <= 0.5
    }

    /// Scrolls so the middle of the caret's line sits in the middle of the window.
    func centerCaretLine() {
        guard let clipView = enclosingScrollView?.contentView, let line = caretLineRect() else { return }
        let y = target(line, in: clipView)
        if abs(clipView.bounds.origin.y - y) > 0.5 {
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: y))
            enclosingScrollView?.reflectScrolledClipView(clipView)
        }
    }

    private func target(_ line: NSRect, in clipView: NSClipView) -> CGFloat {
        let visible = clipView.bounds.height
        return min(max(0, line.midY - visible / 2), max(0, frame.height - visible))
    }

    /// The line the caret is on, in this view's coordinates.
    func caretLineRect() -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let length = (string as NSString).length
        let caret = selectedRange().location
        var rect: NSRect
        if length == 0 || (caret >= length && layoutManager.extraLineFragmentTextContainer != nil) {
            rect = layoutManager.extraLineFragmentRect
            if rect.isEmpty {
                rect = NSRect(x: 0, y: 0, width: textContainer.size.width, height: EyeLineEditor.lineHeight)
            }
        } else {
            let glyph = layoutManager.glyphIndexForCharacter(at: min(caret, length - 1))
            rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    // MARK: - No cursor

    /// The system's caret never shows: this page is for speaking.
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {}

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if let caret = subview as? NSTextInsertionIndicator { caret.displayMode = .hidden }
    }

    private lazy var nib: NSView = {
        let nib = NSView()
        nib.wantsLayer = true
        nib.layer?.backgroundColor = NSColor(MuseColor.moss).cgColor
        nib.layer?.cornerRadius = 0.75
        nib.alphaValue = 0
        addSubview(nib)
        return nib
    }()
    private var nibFades: Task<Void, Never>?

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        placeNib()
    }

    /// A still moss mark where you are, only while you're back inside the words (at the end,
    /// the page's tick is enough). It never blinks, and fades a moment after you stop.
    private func placeNib() {
        nibFades?.cancel()
        let caret = selectedRange()
        guard caret.length == 0, caret.location < (string as NSString).length, formingShown == nil,
              let layoutManager, window != nil else {
            nib.alphaValue = 0
            return
        }
        let glyph = layoutManager.glyphIndexForCharacter(at: caret.location)
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let spot = layoutManager.location(forGlyphAt: glyph)
        nib.frame = NSRect(
            x: textContainerOrigin.x + line.minX + spot.x - 0.75,
            y: textContainerOrigin.y + line.minY + spot.y - 20,
            width: 1.5,
            height: 25
        )
        nib.alphaValue = 1
        nibFades = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self else { return }
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.5
            self.nib.animator().alphaValue = 0
            NSAnimationContext.endGrouping()
        }
    }

    // MARK: - Ink

    /// The ink's motion on this page: soaking in, blooming, draining.
    private(set) lazy var ink = NoteInk(self)
    /// The last hold's words, while they're still where they landed: what "delete that" takes.
    private var lastSpoken: NSRange?
    /// Nothing has changed since that hold landed: "undo" takes exactly those words.
    private var spokenIsLastEdit = false
    private var isLandingSpoken = false

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let should = super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        guard should else { return false }
        self.ink.settle(from: affectedCharRange.location)
        if !isLandingSpoken {
            spokenIsLastEdit = false
            if let lastSpoken, affectedCharRange.location < NSMaxRange(lastSpoken) { self.lastSpoken = nil }
        }
        return true
    }

    /// Typed letters bloom in from soft ink.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        guard !isLandingSpoken, !hasMarkedText() else { return }
        let typed = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        let count = (typed as NSString).length
        let caret = selectedRange().location
        guard count > 0, caret >= count, !typed.allSatisfy(\.isWhitespace) else { return }
        self.ink.bloom(NSRange(location: caret - count, length: count))
    }

    /// "undo": a hold that just landed drains first, then goes. Anything else just undoes.
    func undoLast() {
        guard spokenIsLastEdit, let range = lastSpoken, NSMaxRange(range) <= (string as NSString).length else {
            undoManager?.undo()
            return
        }
        lastSpoken = nil
        self.ink.drain(range) { [weak self] in self?.undoManager?.undo() }
    }

    /// "delete that": the last hold's words drain and go. ⌘Z, or "undo", brings them back.
    /// False when there's no hold still standing where it landed.
    func deleteSpoken() -> Bool {
        guard let range = lastSpoken, NSMaxRange(range) <= (string as NSString).length else { return false }
        lastSpoken = nil
        self.ink.drain(range) { [weak self] in
            guard let self, NSMaxRange(range) <= (self.string as NSString).length else { return }
            self.breakUndoCoalescing()
            if self.shouldChangeText(in: range, replacementString: "") {
                self.textStorage?.replaceCharacters(in: range, with: "")
                self.didChangeText()
            }
            self.breakUndoCoalescing()
        }
        return true
    }

    // MARK: - Words from a hold

    /// The note's own look, for typing after the forming words have come and gone.
    var inkLook: [NSAttributedString.Key: Any] = [:]
    private static let formingKey = NSAttributedString.Key("museoForming")
    private var formingShown: String?

    /// The words, without any still forming.
    var committedString: String {
        guard let storage = textStorage, formingShown != nil else { return string }
        let copy = NSMutableAttributedString(attributedString: storage)
        for range in formingRanges(in: copy).reversed() { copy.deleteCharacters(in: range) }
        return copy.string
    }

    private func formingRanges(in text: NSAttributedString) -> [NSRange] {
        var ranges: [NSRange] = []
        text.enumerateAttribute(Self.formingKey, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil { ranges.append(range) }
        }
        return ranges
    }

    /// A hold's words as they form, right after the caret in soft ink, or nil to take them
    /// away. Straight into the text storage: not typing, so no undo and nothing saved.
    func showForming(_ words: String?) {
        let words = words?.isEmpty == true ? nil : words
        guard words != formingShown, let storage = textStorage, !hasMarkedText() else { return }
        var caret = selectedRange().location
        storage.beginEditing()
        for range in formingRanges(in: storage).reversed() {
            storage.deleteCharacters(in: range)
            if range.location < caret { caret -= min(range.length, caret - range.location) }
        }
        if let words {
            let before = caret > 0 ? (string as NSString).substring(with: NSRange(location: caret - 1, length: 1)) : ""
            let lead = !before.isEmpty && !(before.last?.isWhitespace ?? true) ? " " : ""
            var soft = inkLook
            soft[.foregroundColor] = NoteInk.soft
            soft[Self.formingKey] = true
            storage.insert(NSAttributedString(string: lead + words, attributes: soft), at: caret)
        }
        storage.endEditing()
        formingShown = words
        setSelectedRange(NSRange(location: caret, length: 0))
        typingAttributes = inkLook
        // Edits straight to the storage don't resize the view: do it, so the line can center.
        if let layoutManager, let textContainer { layoutManager.ensureLayout(for: textContainer) }
        sizeToFit()
        centerCaretLine()
    }

    /// A hold's words at the caret, with a space before them when they'd run into a word.
    /// Through `insertText`, so ⌘Z takes them back and the page saves them. Then they soak in.
    func insertSpoken(_ words: String) {
        showForming(nil)
        let caret = selectedRange()
        let before = caret.location > 0 ? (string as NSString).substring(with: NSRange(location: caret.location - 1, length: 1)) : ""
        let needsSpace = !before.isEmpty && !(before.last?.isWhitespace ?? true) && !(words.first.map { ".,;:?!".contains($0) } ?? false)
        let landing = (needsSpace ? " " : "") + words
        // Its own step for ⌘Z, and the ink soaks in from where the forming words stood.
        breakUndoCoalescing()
        isLandingSpoken = true
        insertText(landing, replacementRange: caret)
        isLandingSpoken = false
        breakUndoCoalescing()
        let landed = NSRange(location: caret.location, length: (landing as NSString).length)
        guard NSMaxRange(landed) <= (string as NSString).length else { return }
        lastSpoken = landed
        spokenIsLastEdit = true
        self.ink.land(landed)
    }
}

/// The open note's text view, while it's the one you're typing in: a hold's words go there.
@MainActor
enum NoteFocus {
    static weak var textView: EyeLineTextView?

    /// The note in front, its window key and its words focused.
    static var active: EyeLineTextView? {
        guard let textView, NSApp.isActive, let window = textView.window, window.isKeyWindow,
              window.firstResponder === textView else { return nil }
        return textView
    }
}
