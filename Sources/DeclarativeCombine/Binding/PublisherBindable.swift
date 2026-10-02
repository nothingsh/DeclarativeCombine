import Combine
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private var cancellableStoreKey: UInt8 = 0

/// Keeps a view's subscriptions alive for as long as the view.
private final class CancellableStore {
    var cancellables = Set<AnyCancellable>()
}

#if canImport(UIKit)
/// Carries the binding modifiers so that `Self` is the concrete view type in
/// key paths. Every `UIView` conforms; do not conform other types.
public protocol PublisherBindable: UIView {}

extension UIView: PublisherBindable {}
#elseif os(macOS)
/// Carries the binding modifiers so that `Self` is the concrete view type in
/// key paths. Every `NSView` conforms; do not conform other types.
public protocol PublisherBindable: NSView {}

extension NSView: PublisherBindable {}
#endif

private extension PublisherBindable {

    var cancellableStore: CancellableStore {
        if let store = objc_getAssociatedObject(self, &cancellableStoreKey) as? CancellableStore {
            return store
        }
        let store = CancellableStore()
        objc_setAssociatedObject(self, &cancellableStoreKey, store, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return store
    }
}

/// Each modifier subscribes once and keeps the subscription until the view is
/// released or unbound. Values are applied synchronously where the publisher
/// emits, so it must emit on the main thread.
@MainActor
public extension PublisherBindable {

    /// Assigns each value the publisher emits to the property at `keyPath`.
    @discardableResult
    func bind<P: Publisher>(
        _ keyPath: ReferenceWritableKeyPath<Self, P.Output>,
        to publisher: P
    ) -> Self where P.Failure == Never {
        publisher
            .sink { [weak self] in self?[keyPath: keyPath] = $0 }
            .store(in: &cancellableStore.cancellables)
        return self
    }

    /// Assigns each value to an optional property, such as `\.text` from a
    /// publisher of `String`.
    @discardableResult
    func bind<P: Publisher>(
        _ keyPath: ReferenceWritableKeyPath<Self, P.Output?>,
        to publisher: P
    ) -> Self where P.Failure == Never {
        bind(keyPath, to: publisher.map(Optional.some))
    }

    /// Runs `action` with this view and each value the publisher emits.
    @discardableResult
    func onReceive<P: Publisher>(
        _ publisher: P,
        perform action: @escaping (Self, P.Output) -> Void
    ) -> Self where P.Failure == Never {
        publisher
            .sink { [weak self] value in
                guard let self else { return }
                action(self, value)
            }
            .store(in: &cancellableStore.cancellables)
        return self
    }

    /// Runs `receiveValue` with each value from one of this view's own
    /// publishers, such as `\.tapPublisher`.
    @discardableResult
    func sink<P: Publisher>(
        _ publisher: (Self) -> P,
        receiveValue: @escaping (P.Output) -> Void
    ) -> Self where P.Failure == Never {
        publisher(self)
            .sink(receiveValue: receiveValue)
            .store(in: &cancellableStore.cancellables)
        return self
    }

    /// Sends each value from one of this view's own publishers to `subject`.
    /// Completion is not forwarded.
    @discardableResult
    func send<P: Publisher, S: Subject>(
        _ publisher: (Self) -> P,
        to subject: S
    ) -> Self where P.Failure == Never, S.Output == P.Output, S.Failure == Never {
        sink(publisher) { subject.send($0) }
    }

    /// Cancels every subscription the binding modifiers added to this view.
    /// Its subviews keep theirs.
    func unbind() {
        objc_setAssociatedObject(self, &cancellableStoreKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Cancels every subscription the binding modifiers added to this view
    /// and to every view below it.
    func unbindRecursively() {
        unbind()
        subviews.forEach { $0.unbindRecursively() }
    }
}
