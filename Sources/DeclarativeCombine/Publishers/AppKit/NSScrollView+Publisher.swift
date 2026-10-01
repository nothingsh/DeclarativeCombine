#if os(macOS)
import AppKit
import Combine

/// These publishers emit each time the value changes, whether the user
/// scrolls or the change is made in code. They emit nothing on subscription,
/// hold the scroll view weakly and never complete.
@MainActor
public extension NSScrollView {

    /// Emits the part of the document view that is visible, when it is
    /// scrolled and when the visible area is resized. Its origin is the
    /// scroll position, in the document view's coordinates: `y` grows
    /// downwards only when the document view is flipped.
    var documentVisibleRectPublisher: AnyPublisher<CGRect, Never> {
        // A clip view posts a bounds change when it scrolls and a frame
        // change when it is resized.
        changes(of: { $0.documentVisibleRect }) { scrollView in
            scrollView.notifications(named: NSView.boundsDidChangeNotification, from: { $0.contentView })
                .merge(with: scrollView.notifications(named: NSView.frameDidChangeNotification, from: { $0.contentView }))
                .eraseToAnyPublisher()
        }
    }

    /// Emits the size of the document view's frame, when it is resized and
    /// when another document view of a different size is set.
    var documentSizePublisher: AnyPublisher<CGSize, Never> {
        changes(of: { $0.documentView?.frame.size ?? .zero }) { scrollView in
            scrollView.notifications(named: NSView.frameDidChangeNotification, from: { $0.documentView })
                .merge(with: scrollView.publisher(for: \.documentView, options: [.new]).map { _ in })
                .eraseToAnyPublisher()
        }
    }
}

@MainActor
private extension NSScrollView {

    // Emits when `poster` posts `name`. The posting view is matched when a
    // notification arrives, not when subscribing: NotificationCenter's
    // publisher retains the object it filters on, and the document view can
    // be replaced.
    func notifications(
        named name: Notification.Name,
        from poster: @escaping (NSScrollView) -> NSView?
    ) -> AnyPublisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: name)
            .filter { [weak self] notification in
                guard let self, let poster = poster(self) else { return false }
                return notification.object as AnyObject? === poster
            }
            .map { _ in }
            .eraseToAnyPublisher()
    }

    // Reads `value` each time `triggers` emits. KVO's publisher retains the
    // object it observes, so the triggers are created when a subscriber
    // arrives rather than stored in the returned publisher. The value at
    // subscription is compared against and then dropped, so that a trigger
    // emits only if the value really changed.
    func changes<Value: Equatable>(
        of value: @escaping (NSScrollView) -> Value,
        when triggers: @escaping (NSScrollView) -> AnyPublisher<Void, Never>
    ) -> AnyPublisher<Value, Never> {
        Deferred { [weak self] () -> AnyPublisher<Value, Never> in
            guard let self else {
                return Empty(completeImmediately: false).eraseToAnyPublisher()
            }
            return triggers(self)
                .compactMap { [weak self] in self.map(value) }
                .prepend(value(self))
                .removeDuplicates()
                .dropFirst()
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
#endif
