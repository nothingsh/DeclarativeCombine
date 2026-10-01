import Combine
import UIKit

/// These publishers emit each time the property changes, whether the user
/// scrolls or the value is set in code. They emit nothing on subscription,
/// hold the scroll view weakly and never complete.
@MainActor
public extension UIScrollView {

    var contentOffsetPublisher: AnyPublisher<CGPoint, Never> {
        changes(of: \.contentOffset)
    }

    var contentSizePublisher: AnyPublisher<CGSize, Never> {
        changes(of: \.contentSize)
    }
}

@MainActor
private extension UIScrollView {

    // KVO's publisher retains the object it observes, so it is created when
    // a subscriber arrives rather than stored in the returned publisher. KVO
    // also fires when a property is set to the value it already has, so the
    // initial value is observed, compared against and then dropped.
    func changes<Value: Equatable>(of keyPath: KeyPath<UIScrollView, Value>) -> AnyPublisher<Value, Never> {
        Deferred { [weak self] () -> AnyPublisher<Value, Never> in
            guard let self else {
                return Empty(completeImmediately: false).eraseToAnyPublisher()
            }
            return self.publisher(for: keyPath, options: [.initial, .new])
                .removeDuplicates()
                .dropFirst()
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
