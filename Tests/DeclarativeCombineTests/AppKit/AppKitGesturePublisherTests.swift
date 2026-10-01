#if os(macOS)
import AppKit
import Combine
import XCTest
import DeclarativeCombine

@MainActor
final class AppKitGesturePublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func testGesturePublisherAddsItsRecognizerAndEmitsItUntilCancelled() {
        let view = NSView()
        let recognizer = NSClickGestureRecognizer()
        var received: [NSClickGestureRecognizer] = []
        let cancellable = view.gesturePublisher(recognizer).sink { received.append($0) }
        XCTAssertEqual(view.gestureRecognizers, [recognizer])

        recognizer.fire()
        XCTAssertEqual(received, [recognizer])

        cancellable.cancel()
        XCTAssertNil(recognizer.target)
        XCTAssertNil(recognizer.action)
        XCTAssertEqual(view.gestureRecognizers, [])
    }

    func testClickAndPressPublishersAddTheirOwnRecognizer() {
        let view = NSView()
        view.clickGesturePublisher.sink { _ in }.store(in: &cancellables)
        view.pressGesturePublisher.sink { _ in }.store(in: &cancellables)

        let recognizers = view.gestureRecognizers
        XCTAssertEqual(recognizers.count, 2)
        XCTAssertTrue(recognizers.first is NSClickGestureRecognizer)
        XCTAssertTrue(recognizers.last is NSPressGestureRecognizer)
    }

    // Review focus: one recognizer passed to two subscriptions.
    func testCancellingAnEarlierSubscriptionLeavesARecognizerALaterOneTookOver() {
        let view = NSView()
        let recognizer = NSClickGestureRecognizer()
        var second = 0
        let first = view.gesturePublisher(recognizer).sink { _ in }
        view.gesturePublisher(recognizer).sink { _ in second += 1 }.store(in: &cancellables)

        first.cancel()
        recognizer.fire()

        XCTAssertEqual(second, 1)
        XCTAssertEqual(view.gestureRecognizers, [recognizer])
    }

    // NSTextView is covered in AppKitTextPublisherTests: AppKit releases one
    // only after the run loop has turned, so it needs a wait.
    func testSubscribedPublishersDoNotKeepTheirViewAlive() {
        weak var scrollView: NSScrollView?
        weak var field: NSTextField?
        weak var view: NSView?
        var publisher: AnyPublisher<CGRect, Never>?
        autoreleasepool {
            let strongScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            strongScrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 500))
            let strongField = NSTextField()
            let strongView = NSView()
            publisher = strongScrollView.documentVisibleRectPublisher
            publisher?.sink { _ in }.store(in: &cancellables)
            strongScrollView.documentSizePublisher.sink { _ in }.store(in: &cancellables)
            strongField.stringValuePublisher.sink { _ in }.store(in: &cancellables)
            strongField.returnPublisher.sink { _ in }.store(in: &cancellables)
            strongView.clickGesturePublisher.sink { _ in }.store(in: &cancellables)
            scrollView = strongScrollView
            field = strongField
            view = strongView
        }

        XCTAssertNil(scrollView)
        XCTAssertNil(field)
        XCTAssertNil(view)
        XCTAssertNotNil(publisher)
    }
}
#endif
