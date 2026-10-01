#if os(macOS)
import AppKit

/// Hosts views in a window that is never shown, so that a text field can
/// become first responder and get a field editor.
@MainActor
final class EditingHost {

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )

    init(_ views: NSView...) {
        window.isReleasedWhenClosed = false
        for (index, view) in views.enumerated() {
            view.frame = NSRect(x: 0, y: CGFloat(index) * 40, width: 150, height: 30)
            window.contentView?.addSubview(view)
        }
    }

    /// Types `text` into `view` the way the keyboard does.
    func type(_ text: String, into view: NSView) {
        focus(view)
        editor.insertText(text, replacementRange: editor.selectedRange())
    }

    func pressReturn(in view: NSView) {
        focus(view)
        editor.insertNewline(nil)
    }

    func focus(_ view: NSView) {
        window.makeFirstResponder(view)
    }

    // A text field edits through the window's field editor; a text view is
    // its own editor.
    private var editor: NSTextView {
        window.firstResponder as! NSTextView
    }
}
#endif
