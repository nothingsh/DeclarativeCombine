#if os(macOS)
import AppKit

extension NSGestureRecognizer {

    /// The test process cannot deliver mouse events, so this sends the
    /// recognizer's action to its target directly.
    func fire() {
        guard let action else { return }
        _ = (target as? NSObject)?.perform(action, with: self)
    }
}
#endif
