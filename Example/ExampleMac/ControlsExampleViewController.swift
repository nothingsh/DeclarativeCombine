import AppKit
import Combine
import DeclarativeAppKit
import DeclarativeCombine

final class ControlsViewModel {

    static let sections = ["Stepper", "Date", "Pop-up"]
    static let sizes = ["Small", "Medium", "Large"]

    @Published var section = 0
    @Published var quantity = 1.0
    @Published var isGift = false
    @Published var date = Date()
    @Published var size = 1

    func reset() {
        quantity = 1
        isGift = false
        date = Date()
        size = 1
    }
}

/// One section is shown at a time. Each is bound to `isHidden`, and the stack
/// view closes the gap that a hidden section leaves.
final class ControlsExampleViewController: ExampleScreenViewController {

    private let model = ControlsViewModel()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()

    init() {
        super.init(title: "Controls")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            NSSegmentedControl(labels: ControlsViewModel.sections, trackingMode: .selectOne, target: nil, action: nil)
                .bind(\.selectedSegment, to: model.$section)
                .sink(\.selectedSegmentPublisher) { model.section = $0 }

            VStack(alignment: .fill, spacing: 12) {
                HStack(spacing: 8) {
                    NSTextField(labelWithString: "")
                        .bind(\.stringValue, to: model.$quantity.combineLatest(model.$isGift)
                            .map { "Quantity: \(Int($0))\($1 ? ", gift wrapped" : "")" })
                    Spacer()
                    NSStepper()
                        .configure {
                            $0.minValue = 1
                            $0.maxValue = 99
                        }
                        .bind(\.doubleValue, to: model.$quantity)
                        .sink(\.doubleValuePublisher) { model.quantity = $0 }
                }
                NSButton(checkboxWithTitle: "Gift wrap", target: nil, action: nil)
                    .bind(\.state, to: model.$isGift.map { $0 ? .on : .off })
                    .sink(\.statePublisher) { model.isGift = $0 == .on }
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 0 })

            VStack(alignment: .leading, spacing: 12) {
                NSDatePicker()
                    .configure {
                        $0.datePickerStyle = .textFieldAndStepper
                        $0.datePickerElements = .yearMonthDay
                    }
                    .bind(\.dateValue, to: model.$date)
                    .sink(\.dateValuePublisher) { model.date = $0 }
                NSTextField(wrappingLabelWithString: "")
                    .bind(\.stringValue, to: model.$date.map { Self.dateFormatter.string(from: $0) })
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 1 })

            VStack(alignment: .leading, spacing: 12) {
                NSPopUpButton()
                    .configure { $0.addItems(withTitles: ControlsViewModel.sizes) }
                    // `indexOfSelectedItem` is read-only, so the selection is set by a method.
                    .onReceive(model.$size) { popUp, size in popUp.selectItem(at: size) }
                    .sink(\.indexOfSelectedItemPublisher) { model.size = $0 }
                NSTextField(labelWithString: "")
                    .bind(\.stringValue, to: model.$size.map { "Size: \(ControlsViewModel.sizes[$0])" })
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 2 })

            NSTextField(labelWithString: "Hold here to reset")
                .textColor(.linkColor)
                // A press emits on every state change; only its start resets.
                .sink({ $0.pressGesturePublisher.filter { $0.state == .began } }) { _ in
                    model.reset()
                }

            note("The segmented control picks the section. The labels follow the model, and so do the controls when it is reset.")
        }
    }
}
