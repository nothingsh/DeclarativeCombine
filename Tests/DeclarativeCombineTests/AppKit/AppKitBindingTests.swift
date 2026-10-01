#if os(macOS)
import AppKit
import Combine
import XCTest
import DeclarativeCombine

@MainActor
final class AppKitBindingTests: XCTestCase {

    func testBindAssignsEachValueWithTheConcreteViewType() {
        let text = PassthroughSubject<String, Never>()
        let field: NSTextField = NSTextField().bind(\.stringValue, to: text)

        text.send("abc")
        XCTAssertEqual(field.stringValue, "abc")

        text.send("abcd")
        XCTAssertEqual(field.stringValue, "abcd")
    }

    func testViewIsReleasedAndItsSubscriptionsAreCancelled() {
        let text = PassthroughSubject<String, Never>()
        var cancelCount = 0
        weak var field: NSTextField?
        autoreleasepool {
            let source = text.handleEvents(receiveCancel: { cancelCount += 1 })
            field = NSTextField()
                .bind(\.stringValue, to: source)
                .onReceive(source) { field, value in field.toolTip = value }
        }

        XCTAssertNil(field)
        XCTAssertEqual(cancelCount, 2)
        text.send("abc")
    }
}
#endif
