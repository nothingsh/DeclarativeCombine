import Combine
import UIKit

/// Registers itself as the control's target for as long as it is subscribed.
private final class ControlEventSubscription: NSObject, Subscription {

    private weak var control: UIControl?
    private let events: UIControl.Event
    private var receive: (() -> Void)?

    init(control: UIControl?, events: UIControl.Event, receive: @escaping () -> Void) {
        self.control = control
        self.events = events
        self.receive = receive
        super.init()
        control?.addTarget(self, action: #selector(eventFired), for: events)
    }

    // Control events are not buffered, so demand is not tracked.
    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        control?.removeTarget(self, action: #selector(eventFired), for: events)
        receive = nil
    }

    @objc private func eventFired() {
        receive?()
    }
}

private struct ControlEventPublisher: Publisher {
    typealias Output = Void
    typealias Failure = Never

    weak var control: UIControl?
    let events: UIControl.Event

    func receive<S: Subscriber>(subscriber: S) where S.Input == Void, S.Failure == Never {
        let subscription = ControlEventSubscription(control: control, events: events) {
            _ = subscriber.receive()
        }
        subscriber.receive(subscription: subscription)
    }
}

/// These publishers emit on user interaction only: nothing on subscription,
/// and nothing when the value is set in code. They hold the control weakly
/// and never complete.
@MainActor
public extension UIControl {

    /// Emits each time one of `events` fires.
    func publisher(for events: UIControl.Event) -> AnyPublisher<Void, Never> {
        ControlEventPublisher(control: self, events: events).eraseToAnyPublisher()
    }
}

@MainActor
public extension UIButton {

    var tapPublisher: AnyPublisher<Void, Never> {
        publisher(for: .touchUpInside)
    }
}

@MainActor
public extension UITextField {

    /// Emits the text after each edit, `""` when there is none.
    var textPublisher: AnyPublisher<String, Never> {
        publisher(for: .editingChanged)
            .map { [weak self] in self?.text ?? "" }
            .eraseToAnyPublisher()
    }
}

@MainActor
public extension UISwitch {

    var isOnPublisher: AnyPublisher<Bool, Never> {
        publisher(for: .valueChanged)
            .compactMap { [weak self] in self?.isOn }
            .eraseToAnyPublisher()
    }
}

@MainActor
public extension UISlider {

    var valuePublisher: AnyPublisher<Float, Never> {
        publisher(for: .valueChanged)
            .compactMap { [weak self] in self?.value }
            .eraseToAnyPublisher()
    }
}
