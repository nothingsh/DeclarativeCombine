#if os(macOS)
import AppKit
import Combine
import XCTest
import DeclarativeCombine

@MainActor
final class AppKitControlPublisherTests: XCTestCase {

    private final class Target: NSObject {
        var count = 0
        @objc func fired() { count += 1 }
    }

    private var cancellables = Set<AnyCancellable>()

    func testEverySubscriptionReceivesTheActionUntilItIsCancelled() {
        let button = NSButton()
        var first = 0
        var second = 0
        let firstCancellable = button.actionPublisher.sink { first += 1 }
        let secondCancellable = button.clickPublisher.sink { second += 1 }
        XCTAssertEqual(first, 0)

        button.fire()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)

        firstCancellable.cancel()
        button.fire()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertNotNil(button.target)

        secondCancellable.cancel()
        XCTAssertNil(button.target)
        XCTAssertNil(button.action)
    }

    func testActionPublisherDropsActionsWithoutDemand() {
        let button = NSButton()
        var started = 0
        button.clickPublisher
            .flatMap(maxPublishers: .max(1)) { _ -> PassthroughSubject<Void, Never> in
                started += 1
                return PassthroughSubject()
            }
            .sink {}
            .store(in: &cancellables)

        button.fire()
        button.fire()
        button.fire()

        XCTAssertEqual(started, 1)
    }

    func testValuePublishersEmitTheValueOnActionAndNotWhenSetInCode() {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        let toggle = NSSwitch()
        let slider = NSSlider()
        let stepper = NSStepper()
        let segments = NSSegmentedControl(labels: ["A", "B"], trackingMode: .selectOne, target: nil, action: nil)
        let picker = NSDatePicker()
        let popUp = NSPopUpButton()
        popUp.addItems(withTitles: ["A", "B"])
        let date = Date(timeIntervalSinceReferenceDate: 86_400)

        var checkboxStates: [NSControl.StateValue] = []
        var toggleStates: [NSControl.StateValue] = []
        var sliderValues: [Double] = []
        var stepperValues: [Double] = []
        var selectedSegments: [Int] = []
        var dates: [Date] = []
        var selectedItems: [Int] = []
        checkbox.statePublisher.sink { checkboxStates.append($0) }.store(in: &cancellables)
        toggle.statePublisher.sink { toggleStates.append($0) }.store(in: &cancellables)
        slider.doubleValuePublisher.sink { sliderValues.append($0) }.store(in: &cancellables)
        stepper.doubleValuePublisher.sink { stepperValues.append($0) }.store(in: &cancellables)
        segments.selectedSegmentPublisher.sink { selectedSegments.append($0) }.store(in: &cancellables)
        picker.dateValuePublisher.sink { dates.append($0) }.store(in: &cancellables)
        popUp.indexOfSelectedItemPublisher.sink { selectedItems.append($0) }.store(in: &cancellables)

        checkbox.state = .on
        toggle.state = .on
        slider.doubleValue = 0.5
        stepper.doubleValue = 3
        segments.selectedSegment = 1
        picker.dateValue = date
        popUp.selectItem(at: 1)
        XCTAssertTrue(checkboxStates.isEmpty)
        XCTAssertTrue(toggleStates.isEmpty)
        XCTAssertTrue(sliderValues.isEmpty)
        XCTAssertTrue(stepperValues.isEmpty)
        XCTAssertTrue(selectedSegments.isEmpty)
        XCTAssertTrue(dates.isEmpty)
        XCTAssertTrue(selectedItems.isEmpty)

        checkbox.fire()
        toggle.fire()
        slider.fire()
        stepper.fire()
        segments.fire()
        picker.fire()
        popUp.fire()
        XCTAssertEqual(checkboxStates, [.on])
        XCTAssertEqual(toggleStates, [.on])
        XCTAssertEqual(sliderValues, [0.5])
        XCTAssertEqual(stepperValues, [3])
        XCTAssertEqual(selectedSegments, [1])
        XCTAssertEqual(dates, [date])
        XCTAssertEqual(selectedItems, [1])
    }

    // Review focus: the caller replaces the target after subscribing.
    func testALaterSubscriptionTakesTheControlBackFromAReplacedTarget() {
        let button = NSButton()
        let target = Target()
        var first = 0
        var second = 0
        button.clickPublisher.sink { first += 1 }.store(in: &cancellables)

        button.target = target
        button.action = #selector(Target.fired)
        button.fire()
        XCTAssertEqual(first, 0)
        XCTAssertEqual(target.count, 1)

        button.clickPublisher.sink { second += 1 }.store(in: &cancellables)
        button.fire()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
        XCTAssertEqual(target.count, 1)
    }

    // Review focus: cancelling must not clear a target the caller set.
    func testCancellingLeavesATargetTheCallerSetInPlace() {
        let button = NSButton()
        let target = Target()
        let cancellable = button.clickPublisher.sink {}
        button.target = target
        button.action = #selector(Target.fired)

        cancellable.cancel()

        XCTAssertTrue(button.target === target)
        XCTAssertEqual(button.action, #selector(Target.fired))
    }

    // The caller replaced only the action: the target is still the relay's.
    func testCancellingLeavesAnActionTheCallerSetInPlace() {
        let button = NSButton()
        let cancellable = button.clickPublisher.sink {}
        button.action = #selector(Target.fired)

        cancellable.cancel()

        XCTAssertNil(button.target)
        XCTAssertEqual(button.action, #selector(Target.fired))
    }

    // The caller replaced only the target: the action is still the relay's.
    func testCancellingClearsItsOwnActionFromATargetTheCallerSet() {
        let button = NSButton()
        let target = Target()
        let cancellable = button.clickPublisher.sink {}
        button.target = target

        cancellable.cancel()

        XCTAssertTrue(button.target === target)
        XCTAssertNil(button.action)
    }

    // Review focus: a subscription that cancels itself while the action is
    // being passed on.
    func testASubscriptionMayCancelItselfWhileTheActionIsPassedOn() {
        let button = NSButton()
        var first = 0
        var second = 0
        var third = 0
        button.clickPublisher.sink { first += 1 }.store(in: &cancellables)
        button.clickPublisher.first().sink { second += 1 }.store(in: &cancellables)
        button.clickPublisher.sink { third += 1 }.store(in: &cancellables)

        button.fire()
        button.fire()

        XCTAssertEqual(first, 2)
        XCTAssertEqual(second, 1)
        XCTAssertEqual(third, 2)
    }

    // Review focus: the subscription outlives the control.
    func testControlIsReleasedWhileSubscribedAndCancellingAfterwardsIsSafe() {
        weak var button: NSButton?
        var cancellable: AnyCancellable?
        autoreleasepool {
            let strongButton = NSButton()
            cancellable = strongButton.clickPublisher.sink {}
            button = strongButton
        }

        XCTAssertNil(button)
        cancellable?.cancel()
    }
}
#endif
