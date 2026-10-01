import Combine
import UIKit
import XCTest
import DeclarativeUIKitCombine

@MainActor
final class BindingTests: XCTestCase {

    func testBindAssignsEachValue() {
        let alpha = PassthroughSubject<CGFloat, Never>()
        let view: UIView = UIView().bind(\.alpha, to: alpha)

        alpha.send(0.5)
        XCTAssertEqual(view.alpha, 0.5)

        alpha.send(0.25)
        XCTAssertEqual(view.alpha, 0.25)
    }

    func testBindAssignsNonOptionalValuesToAnOptionalProperty() {
        let text = PassthroughSubject<String, Never>()
        let label: UILabel = UILabel().bind(\.text, to: text)

        text.send("abc")

        XCTAssertEqual(label.text, "abc")
    }

    func testBindAppliesTheCurrentValueWhenBound() {
        let label: UILabel = UILabel().bind(\.text, to: CurrentValueSubject<String, Never>("abc"))

        XCTAssertEqual(label.text, "abc")
    }

    func testOnReceivePassesTheViewAndTheValue() {
        let title = PassthroughSubject<String, Never>()
        let button: UIButton = UIButton().onReceive(title) { button, title in
            button.setTitle(title, for: .normal)
        }

        title.send("Go")

        XCTAssertEqual(button.title(for: .normal), "Go")
    }

    func testSinkReceivesValuesFromTheViewsOwnPublisher() {
        var count = 0
        let button: UIButton = UIButton().sink(\.tapPublisher) { count += 1 }

        button.fire(.touchUpInside)

        XCTAssertEqual(count, 1)
    }

    func testSendForwardsValuesToTheSubject() {
        let taps = PassthroughSubject<Void, Never>()
        var count = 0
        let cancellable = taps.sink { count += 1 }
        let button: UIButton = UIButton().send(\.tapPublisher, to: taps)

        button.fire(.touchUpInside)

        XCTAssertEqual(count, 1)
        cancellable.cancel()
    }

    func testBindAndSendOnOneSubjectBindBothWays() {
        let name = CurrentValueSubject<String, Never>("abc")
        let field: UITextField = UITextField()
            .bind(\.text, to: name)
            .send(\.textPublisher, to: name)
        XCTAssertEqual(field.text, "abc")

        field.text = "abcd"
        field.fire(.editingChanged)
        XCTAssertEqual(name.value, "abcd")

        name.send("xyz")
        XCTAssertEqual(field.text, "xyz")
    }

    func testViewIsReleasedAndItsSubscriptionsAreCancelled() {
        let text = PassthroughSubject<String, Never>()
        let taps = PassthroughSubject<Void, Never>()
        var cancelCount = 0
        weak var label: UILabel?
        weak var button: UIButton?
        weak var textView: UITextView?
        autoreleasepool {
            let source = text.handleEvents(receiveCancel: { cancelCount += 1 })
            label = UILabel()
                .bind(\.text, to: source)
                .onReceive(source) { label, value in label.accessibilityLabel = value }
            button = UIButton()
                .sink(\.tapPublisher) {}
                .send(\.tapPublisher, to: taps)
            textView = UITextView().sink(\.textPublisher) { _ in }
        }

        XCTAssertNil(label)
        XCTAssertNil(button)
        XCTAssertNil(textView)
        XCTAssertEqual(cancelCount, 2)
        text.send("abc")
    }
}
