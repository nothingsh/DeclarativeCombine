#if canImport(UIKit)
import UIKit

extension UIControl {

    /// The test process has no UIApplication to deliver actions, so this calls
    /// the actions registered for `event` on their targets directly.
    func fire(_ event: UIControl.Event) {
        for target in allTargets {
            for action in actions(forTarget: target, forControlEvent: event) ?? [] {
                (target as NSObject).perform(Selector(action))
            }
        }
    }
}
#endif
