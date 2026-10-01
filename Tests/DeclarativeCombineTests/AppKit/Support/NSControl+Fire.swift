#if os(macOS)
import AppKit

extension NSControl {

    /// Sends the control's action to its target, as AppKit does on user
    /// interaction. A control sends through `NSApp`, which is nil in the test
    /// process until `NSApplication.shared` is first read.
    func fire() {
        guard let action else { return }
        NSApplication.shared.sendAction(action, to: target, from: self)
    }
}
#endif
