#if canImport(UIKit)
import Combine
import UIKit

@MainActor
public extension UITextView {

    /// Emits the text after each edit by the user. It emits nothing on
    /// subscription and nothing when the text is set in code. It holds the
    /// text view weakly and never completes.
    var textPublisher: AnyPublisher<String, Never> {
        // NotificationCenter's publisher retains the object it filters on, so
        // the text view is matched here instead.
        NotificationCenter.default
            .publisher(for: UITextView.textDidChangeNotification)
            .compactMap { [weak self] notification in
                guard let self, notification.object as AnyObject? === self else { return nil }
                return self.text
            }
            .eraseToAnyPublisher()
    }
}
#endif
