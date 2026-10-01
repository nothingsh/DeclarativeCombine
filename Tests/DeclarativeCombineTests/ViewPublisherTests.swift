import Combine
import UIKit
import XCTest
import DeclarativeCombine

@MainActor
final class ViewPublisherTests: XCTestCase {

    // The test process cannot deliver touches, so the targets are recorded
    // here and called directly.
    private final class RecordingTapRecognizer: UITapGestureRecognizer {
        private(set) var targets: [(target: NSObject, action: Selector)] = []

        override func addTarget(_ target: Any, action: Selector) {
            targets.append((target as! NSObject, action))
            super.addTarget(target, action: action)
        }

        override func removeTarget(_ target: Any?, action: Selector?) {
            targets.removeAll { $0.target === target as AnyObject? && $0.action == action }
            super.removeTarget(target, action: action)
        }

        func fire() {
            for (target, action) in targets {
                target.perform(action)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func testScrollPublishersEmitEachChange() {
        let scrollView = UIScrollView()
        var offsets: [CGPoint] = []
        var sizes: [CGSize] = []
        scrollView.contentOffsetPublisher.sink { offsets.append($0) }.store(in: &cancellables)
        scrollView.contentSizePublisher.sink { sizes.append($0) }.store(in: &cancellables)
        XCTAssertTrue(offsets.isEmpty)
        XCTAssertTrue(sizes.isEmpty)

        scrollView.contentSize = CGSize(width: 100, height: 400)
        scrollView.contentOffset = CGPoint(x: 0, y: 10)

        XCTAssertEqual(sizes, [CGSize(width: 100, height: 400)])
        XCTAssertEqual(offsets, [CGPoint(x: 0, y: 10)])
    }

    func testGesturePublisherAddsItsRecognizerAndEmitsItUntilCancelled() {
        let view = UIView()
        let recognizer = RecordingTapRecognizer()
        var received: [UITapGestureRecognizer] = []
        let cancellable = view.gesturePublisher(recognizer).sink { received.append($0) }
        XCTAssertEqual(view.gestureRecognizers, [recognizer])

        recognizer.fire()
        XCTAssertEqual(received, [recognizer])

        cancellable.cancel()
        XCTAssertTrue(recognizer.targets.isEmpty)
        XCTAssertEqual(view.gestureRecognizers ?? [], [])
    }

    func testTapAndLongPressPublishersAddTheirOwnRecognizer() {
        let view = UIView()
        view.tapGesturePublisher.sink { _ in }.store(in: &cancellables)
        view.longPressGesturePublisher.sink { _ in }.store(in: &cancellables)

        let recognizers = view.gestureRecognizers ?? []
        XCTAssertEqual(recognizers.count, 2)
        XCTAssertTrue(recognizers.first is UITapGestureRecognizer)
        XCTAssertTrue(recognizers.last is UILongPressGestureRecognizer)
    }

    func testSubscribedPublishersDoNotKeepTheirViewAlive() {
        weak var scrollView: UIScrollView?
        weak var view: UIView?
        var publisher: AnyPublisher<CGPoint, Never>?
        autoreleasepool {
            let strongScrollView = UIScrollView()
            let strongView = UIView()
            publisher = strongScrollView.contentOffsetPublisher
            publisher?.sink { _ in }.store(in: &cancellables)
            strongView.tapGesturePublisher.sink { _ in }.store(in: &cancellables)
            scrollView = strongScrollView
            view = strongView
        }

        XCTAssertNil(scrollView)
        XCTAssertNil(view)
        XCTAssertNotNil(publisher)
    }
}
