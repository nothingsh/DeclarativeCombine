import Combine
import DeclarativeCombine
import DeclarativeUIKit
import UIKit

final class ControlsViewModel {

    static let sections = ["Stepper", "Date", "Pages"]
    static let pageCount = 5

    @Published var section = 0
    @Published var quantity = 1.0
    @Published var date = Date()
    @Published var page = 0

    func reset() {
        quantity = 1
        date = Date()
        page = 0
    }
}

/// One section is shown at a time. Each is bound to `isHidden`, and the stack
/// view closes the gap that a hidden section leaves.
final class ControlsExampleViewController: UIViewController {

    private let model = ControlsViewModel()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Controls"
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            UISegmentedControl(items: ControlsViewModel.sections)
                .bind(\.selectedSegmentIndex, to: model.$section)
                .sink(\.selectedSegmentIndexPublisher) { model.section = $0 }

            VStack(alignment: .fill, spacing: 12) {
                HStack(spacing: 8) {
                    UILabel()
                        .font(textStyle: .body)
                        .bind(\.text, to: model.$quantity.map { "Quantity: \(Int($0))" })
                    Spacer()
                    UIStepper()
                        .configure { $0.minimumValue = 1 }
                        .bind(\.value, to: model.$quantity)
                        .sink(\.valuePublisher) { model.quantity = $0 }
                }
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 0 })

            VStack(alignment: .leading, spacing: 12) {
                UIDatePicker()
                    .configure {
                        $0.datePickerMode = .date
                        $0.preferredDatePickerStyle = .compact
                    }
                    .bind(\.date, to: model.$date)
                    .sink(\.datePublisher) { model.date = $0 }
                UILabel()
                    .font(textStyle: .body)
                    .numberOfLines(0)
                    .bind(\.text, to: model.$date.map { Self.dateFormatter.string(from: $0) })
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 1 })

            VStack(alignment: .center, spacing: 12) {
                UILabel()
                    .font(textStyle: .body)
                    .bind(\.text, to: model.$page.map { "Page \($0 + 1) of \(ControlsViewModel.pageCount)" })
                UIPageControl()
                    .configure {
                        $0.numberOfPages = ControlsViewModel.pageCount
                        $0.pageIndicatorTintColor = .tertiaryLabel
                        $0.currentPageIndicatorTintColor = .label
                    }
                    .bind(\.currentPage, to: model.$page)
                    .sink(\.currentPagePublisher) { model.page = $0 }
            }
            .card()
            .bind(\.isHidden, to: model.$section.map { $0 != 2 })

            UILabel()
                .text("Hold here to reset")
                .font(textStyle: .body)
                .textColor(.systemBlue)
                .isUserInteractionEnabled(true)
                // A long press emits on every state change; only its start resets.
                .sink({ $0.longPressGesturePublisher.filter { $0.state == .began } }) { _ in
                    model.reset()
                }

            note("The segmented control picks the section. The labels follow the model, and so do the controls when it is reset.")
        }
        .alwaysBounceVertical(true)
    }
}
