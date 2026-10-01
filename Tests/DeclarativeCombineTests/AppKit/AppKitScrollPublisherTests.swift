#if os(macOS)
import AppKit
import Combine
import XCTest
import DeclarativeCombine

@MainActor
final class AppKitScrollPublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    private func makeScrollView(documentHeight: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: documentHeight))
        return scrollView
    }

    func testDocumentVisibleRectPublisherEmitsEachChangeOfTheScrollPosition() {
        let scrollView = makeScrollView(documentHeight: 1000)
        var origins: [CGPoint] = []
        scrollView.documentVisibleRectPublisher.sink { origins.append($0.origin) }.store(in: &cancellables)
        XCTAssertTrue(origins.isEmpty)

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 200))
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 200))
        scrollView.documentView?.scroll(NSPoint(x: 0, y: 300))

        XCTAssertEqual(origins, [CGPoint(x: 0, y: 200), CGPoint(x: 0, y: 300)])
    }

    func testDocumentVisibleRectPublisherEmitsWhenTheVisibleAreaIsResized() {
        let scrollView = makeScrollView(documentHeight: 1000)
        var rects: [CGRect] = []
        scrollView.documentVisibleRectPublisher.sink { rects.append($0) }.store(in: &cancellables)

        scrollView.setFrameSize(NSSize(width: 100, height: 300))

        XCTAssertEqual(rects, [scrollView.documentVisibleRect])
        XCTAssertEqual(rects.last?.height, 300)
    }

    func testDocumentSizePublisherEmitsEachChangeOfTheDocumentSize() {
        let scrollView = makeScrollView(documentHeight: 500)
        var sizes: [CGSize] = []
        scrollView.documentSizePublisher.sink { sizes.append($0) }.store(in: &cancellables)
        XCTAssertTrue(sizes.isEmpty)

        // Moving the document view changes its frame but not its size.
        scrollView.documentView?.setFrameOrigin(NSPoint(x: 10, y: 0))
        XCTAssertTrue(sizes.isEmpty)

        scrollView.documentView?.setFrameSize(NSSize(width: 100, height: 600))
        XCTAssertEqual(sizes, [CGSize(width: 100, height: 600)])
    }

    func testDocumentSizePublisherFollowsAReplacedDocumentView() {
        let scrollView = makeScrollView(documentHeight: 500)
        let original = scrollView.documentView
        var sizes: [CGSize] = []
        scrollView.documentSizePublisher.sink { sizes.append($0) }.store(in: &cancellables)

        let replacement = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 700))
        scrollView.documentView = replacement
        XCTAssertEqual(sizes, [CGSize(width: 100, height: 700)])

        original?.setFrameSize(NSSize(width: 100, height: 900))
        XCTAssertEqual(sizes, [CGSize(width: 100, height: 700)])

        replacement.setFrameSize(NSSize(width: 100, height: 800))
        XCTAssertEqual(sizes, [CGSize(width: 100, height: 700), CGSize(width: 100, height: 800)])
    }

    // Review focus: a scroll view that has no document view yet.
    func testScrollPublishersOnAScrollViewWithoutADocumentView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        var sizes: [CGSize] = []
        var rects: [CGRect] = []
        scrollView.documentSizePublisher.sink { sizes.append($0) }.store(in: &cancellables)
        scrollView.documentVisibleRectPublisher.sink { rects.append($0) }.store(in: &cancellables)

        let document = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 400))
        scrollView.documentView = document
        document.setFrameSize(NSSize(width: 100, height: 500))
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 50))

        XCTAssertEqual(sizes, [CGSize(width: 100, height: 400), CGSize(width: 100, height: 500)])
        XCTAssertEqual(rects.last?.origin, CGPoint(x: 0, y: 50))
    }
}
#endif
