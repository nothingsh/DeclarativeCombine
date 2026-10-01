#if canImport(UIKit)
import Combine
import UIKit

/// Adds the recognizer to the view, and is the recognizer's target, for as
/// long as it is subscribed.
private final class GestureSubscription: NSObject, Subscription {

    private weak var view: UIView?
    private let recognizer: UIGestureRecognizer
    private var receive: (() -> Subscribers.Demand)?
    private var demand = Subscribers.Demand.none

    init(view: UIView?, recognizer: UIGestureRecognizer, receive: @escaping () -> Subscribers.Demand) {
        self.view = view
        self.recognizer = recognizer
        self.receive = receive
        super.init()
        recognizer.addTarget(self, action: #selector(gestureFired))
        view?.addGestureRecognizer(recognizer)
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand += demand
    }

    func cancel() {
        recognizer.removeTarget(self, action: #selector(gestureFired))
        view?.removeGestureRecognizer(recognizer)
        receive = nil
    }

    // Gestures are not buffered: one that fires without demand is dropped.
    @objc private func gestureFired() {
        guard demand > .none, let receive else { return }
        demand -= 1
        demand += receive()
    }
}

private struct GesturePublisher<Recognizer: UIGestureRecognizer>: Publisher {
    typealias Output = Recognizer
    typealias Failure = Never

    weak var view: UIView?
    let recognizer: Recognizer

    func receive<S: Subscriber>(subscriber: S) where S.Input == Recognizer, S.Failure == Never {
        let subscription = GestureSubscription(view: view, recognizer: recognizer) { [recognizer] in
            subscriber.receive(recognizer)
        }
        subscriber.receive(subscription: subscription)
    }
}

/// Subscribing adds the recognizer to the view; cancelling removes it. The
/// view must have `isUserInteractionEnabled` set for the gesture to fire,
/// which `UILabel` and `UIImageView` do not by default. These publishers hold
/// the view weakly and never complete.
@MainActor
public extension UIView {

    /// Emits `recognizer` each time it sends its action: once for a discrete
    /// gesture, on every state change for a continuous one.
    func gesturePublisher<Recognizer: UIGestureRecognizer>(
        _ recognizer: Recognizer
    ) -> AnyPublisher<Recognizer, Never> {
        GesturePublisher(view: self, recognizer: recognizer).eraseToAnyPublisher()
    }

    var tapGesturePublisher: AnyPublisher<UITapGestureRecognizer, Never> {
        gesturePublisher(UITapGestureRecognizer())
    }

    /// Emits when the press begins, moves and ends; read `state` to tell them
    /// apart.
    var longPressGesturePublisher: AnyPublisher<UILongPressGestureRecognizer, Never> {
        gesturePublisher(UILongPressGestureRecognizer())
    }
}
#endif
