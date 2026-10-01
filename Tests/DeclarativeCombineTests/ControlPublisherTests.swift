import Combine
import UIKit
import XCTest
import DeclarativeCombine

@MainActor
final class ControlPublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func testEventPublisherEmitsItsEventsUntilCancelled() {
        let button = UIButton()
        var count = 0
        let cancellable = button.publisher(for: .touchUpInside).sink { count += 1 }

        button.fire(.touchUpInside)
        button.fire(.touchDown)
        XCTAssertEqual(count, 1)

        cancellable.cancel()
        XCTAssertTrue(button.allTargets.isEmpty)
    }

    func testEventPublisherDropsEventsWithoutDemand() {
        let button = UIButton()
        var started = 0
        button.tapPublisher
            .flatMap(maxPublishers: .max(1)) { _ -> PassthroughSubject<Void, Never> in
                started += 1
                return PassthroughSubject()
            }
            .sink {}
            .store(in: &cancellables)

        button.fire(.touchUpInside)
        button.fire(.touchUpInside)
        button.fire(.touchUpInside)

        XCTAssertEqual(started, 1)
    }

    func testTapPublisherEmitsOnTouchUpInside() {
        let button = UIButton()
        var count = 0
        button.tapPublisher.sink { count += 1 }.store(in: &cancellables)

        button.fire(.touchUpInside)

        XCTAssertEqual(count, 1)
    }

    func testValuePublishersEmitTheCurrentValueOnTheirEvent() {
        let field = UITextField()
        let toggle = UISwitch()
        let slider = UISlider()
        var texts: [String] = []
        var states: [Bool] = []
        var values: [Float] = []
        field.textPublisher.sink { texts.append($0) }.store(in: &cancellables)
        toggle.isOnPublisher.sink { states.append($0) }.store(in: &cancellables)
        slider.valuePublisher.sink { values.append($0) }.store(in: &cancellables)

        field.text = "abc"
        toggle.isOn = true
        slider.value = 0.25
        XCTAssertTrue(texts.isEmpty)
        XCTAssertTrue(states.isEmpty)
        XCTAssertTrue(values.isEmpty)

        field.fire(.editingChanged)
        toggle.fire(.valueChanged)
        slider.fire(.valueChanged)
        XCTAssertEqual(texts, ["abc"])
        XCTAssertEqual(states, [true])
        XCTAssertEqual(values, [0.25])
    }

    func testTextViewPublisherEmitsOnlyItsOwnChanges() {
        let textView = UITextView()
        let other = UITextView()
        var texts: [String] = []
        textView.textPublisher.sink { texts.append($0) }.store(in: &cancellables)

        textView.text = "abc"
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: other)
        XCTAssertTrue(texts.isEmpty)

        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
        XCTAssertEqual(texts, ["abc"])
    }

    func testSubscribedPublishersDoNotKeepTheirViewAlive() {
        weak var button: UIButton?
        weak var field: UITextField?
        weak var textView: UITextView?
        autoreleasepool {
            let strongButton = UIButton()
            let strongField = UITextField()
            let strongTextView = UITextView()
            strongButton.tapPublisher.sink {}.store(in: &cancellables)
            strongField.textPublisher.sink { _ in }.store(in: &cancellables)
            strongTextView.textPublisher.sink { _ in }.store(in: &cancellables)
            button = strongButton
            field = strongField
            textView = strongTextView
        }

        XCTAssertNil(button)
        XCTAssertNil(field)
        XCTAssertNil(textView)
    }
}
