import AppKit
import DeclarativeAppKit

// Small styling helpers shared by the example screens. They are plain functions
// over DeclarativeAppKit's public modifiers, not part of either library.

/// A borderless box filled with `color`, for rounded backgrounds.
@MainActor
func fill(_ color: NSColor, cornerRadius: CGFloat = 0) -> NSBox {
    NSBox().configure {
        $0.boxType = .custom
        $0.borderWidth = 0
        $0.cornerRadius = cornerRadius
        $0.fillColor = color
    }
}

extension NSStackView {

    /// Pads the stack and puts a rounded card behind it.
    ///
    /// The card is a translucent tint rather than a background color, so it stands out
    /// from the window in both appearances.
    func card(padding: CGFloat = 16) -> Self {
        self.padding(padding)
            .background { fill(.quaternaryLabelColor, cornerRadius: 12) }
    }
}

@MainActor
func sectionTitle(_ text: String) -> NSTextField {
    NSTextField(labelWithString: text.uppercased())
        .font(.preferredFont(forTextStyle: .footnote))
        .textColor(.secondaryLabelColor)
}

@MainActor
func note(_ text: String) -> NSTextField {
    NSTextField(wrappingLabelWithString: text)
        .font(.preferredFont(forTextStyle: .footnote))
        .textColor(.secondaryLabelColor)
}

/// A screen built in code: no nib, and an empty view for `addScreen` to mount into.
class ExampleScreenViewController: NSViewController {

    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The example screens are built in code.")
    }

    override func loadView() {
        view = NSView()
    }

    /// The root of every screen: a vertical scroll view with fixed padding, mounted inside
    /// the safe area.
    @discardableResult
    func addScreen(spacing: CGFloat = 16, @NSViewBuilder content: () -> [NSView]) -> VScroll {
        view.addVScroll(alignment: .fill, spacing: spacing, safeArea: .all, content: content)
            .padding(16)
    }
}
