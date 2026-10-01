#if os(macOS)
import AppKit
import Combine

/// These publishers observe notifications and leave the field's `target` and
/// `action` alone. They emit on user edits only: nothing on subscription, and
/// nothing when the text is set in code. They hold the field weakly and never
/// complete.
@MainActor
public extension NSTextField {

    /// Emits the text after each edit.
    var stringValuePublisher: AnyPublisher<String, Never> {
        // NotificationCenter's publisher retains the object it filters on, so
        // the field is matched here instead.
        NotificationCenter.default
            .publisher(for: NSControl.textDidChangeNotification)
            .compactMap { [weak self] notification in
                guard let self, notification.object as AnyObject? === self else { return nil }
                return self.stringValue
            }
            .eraseToAnyPublisher()
    }

    /// Emits when editing ends because the return key was pressed, and not
    /// when it ends because the focus moved.
    var returnPublisher: AnyPublisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: NSControl.textDidEndEditingNotification)
            .filter { [weak self] notification in
                guard let self, notification.object as AnyObject? === self else { return false }
                return notification.userInfo?["NSTextMovement"] as? Int == NSTextMovement.return.rawValue
            }
            .map { _ in }
            .eraseToAnyPublisher()
    }
}
#endif
