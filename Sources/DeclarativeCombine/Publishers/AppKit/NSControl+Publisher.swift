#if os(macOS)
import AppKit
import Combine

private var actionRelayKey: UInt8 = 0

/// The control's only target while it has subscribers. A control has a single
/// target and action, so one relay passes each action on to every
/// subscription.
private final class ActionRelay: NSObject {

    private var handlers: [(owner: ObjectIdentifier, handler: () -> Void)] = []

    var isEmpty: Bool { handlers.isEmpty }

    static func existing(on control: NSControl) -> ActionRelay? {
        objc_getAssociatedObject(control, &actionRelayKey) as? ActionRelay
    }

    static func relay(on control: NSControl) -> ActionRelay {
        if let relay = existing(on: control) {
            return relay
        }
        let relay = ActionRelay()
        objc_setAssociatedObject(control, &actionRelayKey, relay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return relay
    }

    func add(_ handler: @escaping () -> Void, for owner: AnyObject) {
        handlers.append((ObjectIdentifier(owner), handler))
    }

    func remove(for owner: AnyObject) {
        handlers.removeAll { $0.owner == ObjectIdentifier(owner) }
    }

    // A handler may cancel a subscription, which changes `handlers`, so the
    // loop runs over a copy.
    @objc func actionSent() {
        for entry in handlers {
            entry.handler()
        }
    }
}

/// Registers with the control's relay for as long as it is subscribed.
private final class ActionSubscription: Subscription {

    private weak var control: NSControl?
    private var receive: (() -> Subscribers.Demand)?
    private var demand = Subscribers.Demand.none

    init(control: NSControl?, receive: @escaping () -> Subscribers.Demand) {
        self.control = control
        self.receive = receive
        guard let control else { return }
        let relay = ActionRelay.relay(on: control)
        relay.add({ [weak self] in self?.actionSent() }, for: self)
        // Set on every subscription, so that a new one takes the control back
        // if its target was replaced in the meantime.
        control.target = relay
        control.action = #selector(ActionRelay.actionSent)
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand += demand
    }

    func cancel() {
        receive = nil
        guard let control, let relay = ActionRelay.existing(on: control) else { return }
        relay.remove(for: self)
        guard relay.isEmpty else { return }
        // The caller may have replaced the target, the action or both, so
        // each is cleared only if it is still the relay's.
        if control.target === relay {
            control.target = nil
        }
        if control.action == #selector(ActionRelay.actionSent) {
            control.action = nil
        }
    }

    // Actions are not buffered: one that is sent without demand is dropped.
    private func actionSent() {
        guard demand > .none, let receive else { return }
        demand -= 1
        demand += receive()
    }
}

private struct ActionPublisher: Publisher {
    typealias Output = Void
    typealias Failure = Never

    weak var control: NSControl?

    func receive<S: Subscriber>(subscriber: S) where S.Input == Void, S.Failure == Never {
        let subscription = ActionSubscription(control: control) {
            subscriber.receive()
        }
        subscriber.receive(subscription: subscription)
    }
}

/// These publishers take over the control's `target` and `action`: do not set
/// either on a control you subscribe to. They emit when AppKit sends the
/// action, which is on user interaction only: nothing on subscription, and
/// nothing when the value is set in code. They hold the control weakly and
/// never complete.
@MainActor
public extension NSControl {

    /// Emits each time the control sends its action. `isContinuous` and
    /// `sendAction(on:)` decide when that is.
    var actionPublisher: AnyPublisher<Void, Never> {
        ActionPublisher(control: self).eraseToAnyPublisher()
    }
}

/// Emits `value` of `control` each time it sends its action.
@MainActor
private func actionValues<Control: NSControl, Value>(
    of control: Control,
    _ value: @escaping (Control) -> Value
) -> AnyPublisher<Value, Never> {
    control.actionPublisher
        .compactMap { [weak control] in control.map(value) }
        .eraseToAnyPublisher()
}

@MainActor
public extension NSButton {

    var clickPublisher: AnyPublisher<Void, Never> {
        actionPublisher
    }

    /// Emits the state after each click, for a checkbox, radio or toggle
    /// button.
    var statePublisher: AnyPublisher<NSControl.StateValue, Never> {
        actionValues(of: self, \.state)
    }
}

@MainActor
public extension NSSwitch {

    var statePublisher: AnyPublisher<NSControl.StateValue, Never> {
        actionValues(of: self, \.state)
    }
}

@MainActor
public extension NSSlider {

    var doubleValuePublisher: AnyPublisher<Double, Never> {
        actionValues(of: self, \.doubleValue)
    }
}

@MainActor
public extension NSStepper {

    var doubleValuePublisher: AnyPublisher<Double, Never> {
        actionValues(of: self, \.doubleValue)
    }
}

@MainActor
public extension NSSegmentedControl {

    var selectedSegmentPublisher: AnyPublisher<Int, Never> {
        actionValues(of: self, \.selectedSegment)
    }
}

@MainActor
public extension NSDatePicker {

    var dateValuePublisher: AnyPublisher<Date, Never> {
        actionValues(of: self, \.dateValue)
    }
}

@MainActor
public extension NSPopUpButton {

    var indexOfSelectedItemPublisher: AnyPublisher<Int, Never> {
        actionValues(of: self, \.indexOfSelectedItem)
    }
}
#endif
