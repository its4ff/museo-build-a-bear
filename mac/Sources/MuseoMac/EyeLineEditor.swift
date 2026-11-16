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
        textView.insertionPointColor = NSColor(MuseColor.moss)
        textView.delegate = context.coordinator
        textView.layoutManager?.delegate = context.coordinator
        textView.string = text
        context.coordinator.style(textView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))

        scrollView.documentView = textView
        context.coordinator.watchSize(of: scrollView)
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
            textView.ink = attributes
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

    // MARK: - Words from a hold

    /// The note's own look, for typing after the forming words have come and gone.
    var ink: [NSAttributedString.Key: Any] = [:]
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
            var soft = ink
            soft[.foregroundColor] = NSColor(MuseColor.ink55).withAlphaComponent(0.7)
            soft[Self.formingKey] = true
            storage.insert(NSAttributedString(string: lead + words, attributes: soft), at: caret)
        }
        storage.endEditing()
        formingShown = words
        setSelectedRange(NSRange(location: caret, length: 0))
        typingAttributes = ink
        // Edits straight to the storage don't resize the view: do it, so the line can center.
        if let layoutManager, let textContainer { layoutManager.ensureLayout(for: textContainer) }
        sizeToFit()
        centerCaretLine()
    }

    /// A hold's words at the caret, with a space before them when they'd run into a word.
    /// Through `insertText`, so ⌘Z takes them back and the page saves them.
    func insertSpoken(_ words: String) {
        showForming(nil)
        let caret = selectedRange()
        let before = caret.location > 0 ? (string as NSString).substring(with: NSRange(location: caret.location - 1, length: 1)) : ""
        let needsSpace = !before.isEmpty && !(before.last?.isWhitespace ?? true) && !(words.first.map { ".,;:?!".contains($0) } ?? false)
        insertText((needsSpace ? " " : "") + words, replacementRange: caret)
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
