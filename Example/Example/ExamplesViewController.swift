import DeclarativeCombine
import DeclarativeUIKit
import UIKit

/// The list of example screens.
final class ExamplesViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DeclarativeCombine"
        addScreen(spacing: 12) {
            entry(
                "Form",
                detail: "Fields, a switch and a slider bound both ways to a view model. The screen keeps no view in a property."
            ) { FormExampleViewController() }
            entry(
                "Scrolling header",
                detail: "A header driven by the scroll offset, pull to refresh, and a tap gesture."
            ) { ScrollExampleViewController() }
            entry(
                "Controls",
                detail: "A segmented control that shows and hides sections, with a stepper, a date picker and a page control."
            ) { ControlsExampleViewController() }
        }
    }

    /// A card whose whole area is a button, placed with `overlay`.
    private func entry(
        _ title: String,
        detail: String,
        destination: @escaping () -> UIViewController
    ) -> UIView {
        VStack(alignment: .leading, spacing: 4) {
            UILabel()
                .text(title)
                .font(textStyle: .headline)
            UILabel()
                .text(detail)
                .font(textStyle: .subheadline)
                .textColor(.secondaryLabel)
                .numberOfLines(0)
        }
        .card()
        .overlay {
            UIButton(type: .system)
                .accessibilityLabel(title)
                .sink(\.tapPublisher) { [weak self] in
                    self?.navigationController?.pushViewController(destination(), animated: true)
                }
        }
    }
}
