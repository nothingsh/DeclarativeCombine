import DeclarativeUIKit
import UIKit

// Small styling helpers shared by the example screens. They are plain functions
// over the library's public modifiers, not part of the library.

extension UIStackView {

    /// Pads the stack and puts a rounded card behind it.
    func card(padding: CGFloat = 16) -> Self {
        self.padding(padding)
            .background {
                UIView()
                    .background(.secondarySystemGroupedBackground)
                    .configure { $0.layer.cornerRadius = 12 }
            }
    }
}

@MainActor
func sectionTitle(_ text: String) -> UILabel {
    UILabel()
        .text(text.uppercased())
        .font(textStyle: .footnote)
        .textColor(.secondaryLabel)
}

@MainActor
func note(_ text: String) -> UILabel {
    UILabel()
        .text(text)
        .font(textStyle: .footnote)
        .textColor(.secondaryLabel)
        .numberOfLines(0)
}

/// The root of every screen: a vertical scroll view with fixed padding.
///
/// The scroll view is mounted inside the safe area, clear of the navigation bar, the home
/// indicator and the sensor housing, while the view's background color fills the display.
extension UIViewController {

    @discardableResult
    func addScreen(spacing: CGFloat = 16, @UIViewBuilder content: () -> [UIView]) -> VScroll {
        view.background(.systemGroupedBackground)
        return view.addVScroll(alignment: .fill, spacing: spacing, safeArea: .all, content: content)
            .padding(16)
    }
}
