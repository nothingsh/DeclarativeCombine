import AppKit
import Combine
import DeclarativeAppKit
import DeclarativeCombine

final class ScrollViewModel {

    @Published private(set) var isFavorite = false
    @Published private(set) var updatedAt = Date()
    @Published private(set) var isReloading = false

    func toggleFavorite() {
        isFavorite.toggle()
    }

    /// Stands in for a network request.
    func reload() {
        isReloading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.updatedAt = Date()
            self?.isReloading = false
        }
    }
}

/// A header that follows the scroll position, a click gesture, and a button
/// that is disabled while its request runs.
final class ScrollExampleViewController: ExampleScreenViewController {

    private let model = ScrollViewModel()

    /// How far the page has scrolled and how tall its content is, sent by the
    /// scroll view and received by the labels. No view knows another.
    private let offset = CurrentValueSubject<CGFloat, Never>(0)
    private let contentHeight = CurrentValueSubject<CGFloat, Never>(0)

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    init() {
        super.init(title: "Scrolling header")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            VStack(spacing: 8) {
                NSImageView()
                    .imageScaling(.scaleProportionallyUpOrDown)
                    .contentTintColor(.systemPink)
                    .frame(width: 72, height: 72)
                    .bind(\.image, to: model.$isFavorite.map {
                        NSImage(systemSymbolName: $0 ? "heart.fill" : "heart", accessibilityDescription: "Favorite")
                    })
                    .sink(\.clickGesturePublisher) { _ in model.toggleFavorite() }
                NSTextField(labelWithString: "")
                    .font(.preferredFont(forTextStyle: .headline))
                    .bind(\.stringValue, to: model.$isFavorite.map { $0 ? "Favorite" : "Click the heart" })
                NSTextField(labelWithString: "")
                    .font(.preferredFont(forTextStyle: .footnote))
                    .textColor(.secondaryLabelColor)
                    .bind(\.stringValue, to: offset.combineLatest(contentHeight)
                        .map { "Offset \(Int($0)) of \(Int($1))" }
                        .removeDuplicates())
            }
            .card()
            // Fades out over the first 120 points.
            .bind(\.alphaValue, to: offset.map { 1 - min(max($0 / 120, 0), 1) })

            HStack(spacing: 12) {
                NSTextField(labelWithString: "")
                    .font(.preferredFont(forTextStyle: .footnote))
                    .textColor(.secondaryLabelColor)
                    .bind(\.stringValue, to: model.$updatedAt.map {
                        "Updated at \(Self.timeFormatter.string(from: $0))"
                    })
                Spacer()
                NSButton()
                    .title("Reload")
                    .bezelStyle(.rounded)
                    .bind(\.isEnabled, to: model.$isReloading.map { !$0 })
                    .sink(\.clickPublisher) { model.reload() }
            }

            for index in 1...20 {
                HStack(spacing: 8) {
                    NSTextField(labelWithString: "Row \(index)")
                    Spacer()
                }
                .card(padding: 12)
            }

            note("The header fades as the page scrolls. Reload is disabled until its request finishes.")
        }
        // The content of a VScroll is flipped, so `y` grows as the page scrolls down.
        .send({ $0.documentVisibleRectPublisher.map(\.origin.y) }, to: offset)
        .send({ $0.documentSizePublisher.map(\.height) }, to: contentHeight)
    }
}
