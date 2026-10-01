#if os(macOS)
import AppKit
import Combine

/// Adds the recognizer to the view, and is the recognizer's target, for as
/// long as it is subscribed.
private final class GestureSubscription: NSObject, Subscription {

    private weak var view: NSView?
    private let recognizer: NSGestureRecognizer
    private var receive: (() -> Subscribers.Demand)?
    private var demand = Subscribers.Demand.none

    init(view: NSView?, recognizer: NSGestureRecognizer, receive: @escaping () -> Subscribers.Demand) {
        self.view = view
        self.recognizer = recognizer
        self.receive = receive
        super.init()
        recognizer.target = self
        recognizer.action = #selector(gestureFired)
        view?.addGestureRecognizer(recognizer)
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand += demand
    }

    // A recognizer has a single target. If a later subscription took this
    // recognizer over, it is left in place for that subscription.
    func cancel() {
        receive = nil
        guard recognizer.target === self else { return }
        recognizer.target = nil
        recognizer.action = nil
        view?.removeGestureRecognizer(recognizer)
    }

    // Gestures are not buffered: one that fires without demand is dropped.
    @objc private func gestureFired() {
        guard demand > .none, let receive else { return }
        demand -= 1
        demand += receive()
    }
}

private struct GesturePublisher<Recognizer: NSGestureRecognizer>: Publisher {
    typealias Output = Recognizer
    typealias Failure = Never

    weak var view: NSView?
    let recognizer: Recognizer

    func receive<S: Subscriber>(subscriber: S) where S.Input == Recognizer, S.Failure == Never {
        let subscription = GestureSubscription(view: view, recognizer: recognizer) { [recognizer] in
            subscriber.receive(recognizer)
        }
        subscriber.receive(subscription: subscription)
    }
}

/// Subscribing adds the recognizer to the view and takes over its `target`
/// and `action`; cancelling removes it. These publishers hold the view weakly
/// and never complete.
@MainActor
public extension NSView {

    /// Emits `recognizer` each time it sends its action: once for a discrete
    /// gesture, on every state change for a continuous one. A recognizer has
    /// a single target, so pass each recognizer to one subscription only.
    func gesturePublisher<Recognizer: NSGestureRecognizer>(
        _ recognizer: Recognizer
    ) -> AnyPublisher<Recognizer, Never> {
        GesturePublisher(view: self, recognizer: recognizer).eraseToAnyPublisher()
    }

    var clickGesturePublisher: AnyPublisher<NSClickGestureRecognizer, Never> {
        gesturePublisher(NSClickGestureRecognizer())
    }

    /// Emits when the press begins, moves and ends; read `state` to tell them
    /// apart.
    var pressGesturePublisher: AnyPublisher<NSPressGestureRecognizer, Never> {
        gesturePublisher(NSPressGestureRecognizer())
    }
}
#endif
