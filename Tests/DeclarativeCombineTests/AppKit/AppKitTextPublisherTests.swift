#if os(macOS)
import AppKit
import Combine
import XCTest
import DeclarativeCombine

@MainActor
final class AppKitTextPublisherTests: XCTestCase {

    private final class Target: NSObject {
        var count = 0
        @objc func fired() { count += 1 }
    }

    private var cancellables = Set<AnyCancellable>()

    func testStringValuePublisherEmitsUserEditsOfItsOwnFieldOnly() {
        let field = NSTextField()
        let other = NSTextField()
        let host = EditingHost(field, other)
        var values: [String] = []
        field.stringValuePublisher.sink { values.append($0) }.store(in: &cancellables)

        field.stringValue = "set in code"
        host.type("typed elsewhere", into: other)
        XCTAssertTrue(values.isEmpty)

        field.stringValue = ""
        host.type("ab", into: field)
        XCTAssertEqual(values, ["ab"])
    }

    func testReturnPublisherEmitsOnReturnAndNotWhenFocusMoves() {
        let field = NSTextField()
        let other = NSTextField()
        let host = EditingHost(field, other)
        let target = Target()
        field.target = target
        field.action = #selector(Target.fired)
        var count = 0
        field.returnPublisher.sink { count += 1 }.store(in: &cancellables)

        host.type("ab", into: field)
        host.focus(other)
        XCTAssertEqual(count, 0)

        host.pressReturn(in: other)
        XCTAssertEqual(count, 0)

        host.pressReturn(in: field)
        XCTAssertEqual(count, 1)
        // The field's own target and action are left alone.
        XCTAssertEqual(target.count, 1)
    }

    // Review focus: subclasses with their own cell and field editor.
    func testSecureAndSearchFieldsInheritTheTextPublishers() {
        let secure = NSSecureTextField()
        let search = NSSearchField()
        let host = EditingHost(secure, search)
        var secureValues: [String] = []
        var searchValues: [String] = []
        secure.stringValuePublisher.sink { secureValues.append($0) }.store(in: &cancellables)
        search.stringValuePublisher.sink { searchValues.append($0) }.store(in: &cancellables)

        host.type("pw", into: secure)
        host.type("query", into: search)

        XCTAssertEqual(secureValues, ["pw"])
        XCTAssertEqual(searchValues, ["query"])
    }

    func testTextViewStringPublisherEmitsUserEditsAndNotCodeChanges() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let host = EditingHost(textView)
        var values: [String] = []
        textView.stringPublisher.sink { values.append($0) }.store(in: &cancellables)

        textView.string = "set in code"
        XCTAssertTrue(values.isEmpty)

        textView.string = ""
        host.type("ab", into: textView)
        XCTAssertEqual(values, ["ab"])
    }

    // AppKit releases a text view only after the run loop has turned for a
    // while, so this waits for it instead of checking straight away.
    func testSubscribedStringPublisherDoesNotKeepItsTextViewAlive() {
        weak var textView: NSTextView?
        autoreleasepool {
            let strongTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            strongTextView.stringPublisher.sink { _ in }.store(in: &cancellables)
            textView = strongTextView
        }

        let deadline = Date().addingTimeInterval(3)
        while textView != nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTAssertNil(textView)
    }
}
#endif
