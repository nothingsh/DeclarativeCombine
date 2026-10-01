import Combine
import UIKit

/// Registers itself as the control's target for as long as it is subscribed.
private final class ControlEventSubscription: NSObject, Subscription {

    private weak var control: UIControl?
    private let events: UIControl.Event
    private var receive: (() -> Subscribers.Demand)?
    private var demand = Subscribers.Demand.none

    init(control: UIControl?, events: UIControl.Event, receive: @escaping () -> Subscribers.Demand) {
        self.control = control
        self.events = events
        self.receive = receive
        super.init()
        control?.addTarget(self, action: #selector(eventFired), for: events)
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand += demand
    }

    func cancel() {
        control?.removeTarget(self, action: #selector(eventFired), for: events)
        receive = nil
    }

    // Events are not buffered: one that fires without demand is dropped.
    @objc private func eventFired() {
        guard demand > .none, let receive else { return }
        demand -= 1
        demand += receive()
    }
}

private struct ControlEventPublisher: Publisher {
    typealias Output = Void
    typealias Failure = Never

    weak var control: UIControl?
    let events: UIControl.Event

    func receive<S: Subscriber>(subscriber: S) where S.Input == Void, S.Failure == Never {
        let subscription = ControlEventSubscription(control: control, events: events) {
            subscriber.receive()
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

/// Emits `value` of `control` each time one of `events` fires.
@MainActor
private func eventValues<Control: UIControl, Value>(
    of control: Control,
    for events: UIControl.Event,
    _ value: @escaping (Control) -> Value
) -> AnyPublisher<Value, Never> {
    control.publisher(for: events)
        .compactMap { [weak control] in control.map(value) }
        .eraseToAnyPublisher()
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
        eventValues(of: self, for: .editingChanged) { $0.text ?? "" }
    }

    /// Emits when the return key is pressed. UIKit dismisses the keyboard
    /// when this event has a target.
    var returnPublisher: AnyPublisher<Void, Never> {
        publisher(for: .editingDidEndOnExit)
    }
}

@MainActor
public extension UISwitch {

    var isOnPublisher: AnyPublisher<Bool, Never> {
        eventValues(of: self, for: .valueChanged, \.isOn)
    }
}

@MainActor
public extension UISlider {

    var valuePublisher: AnyPublisher<Float, Never> {
        eventValues(of: self, for: .valueChanged, \.value)
    }
}

@MainActor
public extension UIStepper {

    var valuePublisher: AnyPublisher<Double, Never> {
        eventValues(of: self, for: .valueChanged, \.value)
    }
}

@MainActor
public extension UISegmentedControl {

    var selectedSegmentIndexPublisher: AnyPublisher<Int, Never> {
        eventValues(of: self, for: .valueChanged, \.selectedSegmentIndex)
    }
}

@MainActor
public extension UIDatePicker {

    var datePublisher: AnyPublisher<Date, Never> {
        eventValues(of: self, for: .valueChanged, \.date)
    }
}

@MainActor
public extension UIPageControl {

    var currentPagePublisher: AnyPublisher<Int, Never> {
        eventValues(of: self, for: .valueChanged, \.currentPage)
    }
}

@MainActor
public extension UIRefreshControl {

    /// Emits when the user pulls to refresh.
    var refreshPublisher: AnyPublisher<Void, Never> {
        publisher(for: .valueChanged)
    }
}
