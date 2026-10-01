#if os(macOS)
import AppKit
import Combine

@MainActor
public extension NSTextView {

    /// Emits the text after each edit by the user. It emits nothing on
    /// subscription and nothing when the text is set in code. It holds the
    /// text view weakly and never completes.
    var stringPublisher: AnyPublisher<String, Never> {
        // NotificationCenter's publisher retains the object it filters on, so
        // the text view is matched here instead.
        NotificationCenter.default
            .publisher(for: NSText.didChangeNotification)
            .compactMap { [weak self] notification in
                guard let self, notification.object as AnyObject? === self else { return nil }
                return self.string
            }
            .eraseToAnyPublisher()
    }
}
#endif
