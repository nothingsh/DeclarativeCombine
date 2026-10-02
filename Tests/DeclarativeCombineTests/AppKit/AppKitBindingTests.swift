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

    func testUnbindCancelsTheViewsBindingsButNotItsSubviews() {
        let alpha = PassthroughSubject<CGFloat, Never>()
        var clickCount = 0
        let field: NSTextField = NSTextField().bind(\.alphaValue, to: alpha)
        let button: NSButton = NSButton()
            .bind(\.alphaValue, to: alpha)
            .sink(\.clickPublisher) { clickCount += 1 }
        button.addSubview(field)

        button.unbind()
        alpha.send(0.5)
        button.fire()

        XCTAssertEqual(button.alphaValue, 1)
        XCTAssertEqual(clickCount, 0)
        XCTAssertEqual(field.alphaValue, 0.5)
    }

    func testUnbindRecursivelyCancelsTheBindingsOfTheViewAndItsDescendants() {
        let alpha = PassthroughSubject<CGFloat, Never>()
        let grandchild: NSView = NSView().bind(\.alphaValue, to: alpha)
        let child = NSView()
        let root: NSView = NSView().bind(\.alphaValue, to: alpha)
        child.addSubview(grandchild)
        root.addSubview(child)

        root.unbindRecursively()
        alpha.send(0.5)

        XCTAssertEqual(root.alphaValue, 1)
        XCTAssertEqual(grandchild.alphaValue, 1)
    }
}
#endif
