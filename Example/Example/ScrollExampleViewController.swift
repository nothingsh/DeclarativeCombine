import Combine
import DeclarativeCombine
import DeclarativeUIKit
import UIKit

final class ScrollViewModel {

    @Published private(set) var isFavorite = false
    @Published private(set) var updatedAt = Date()

    func toggleFavorite() {
        isFavorite.toggle()
    }

    /// Stands in for a network request.
    func reload() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.updatedAt = Date()
        }
    }
}

/// A header that follows the scroll offset, pull to refresh, and a tap gesture.
final class ScrollExampleViewController: UIViewController {

    private let model = ScrollViewModel()

    /// How far the page has scrolled, sent by the scroll view and received by
    /// the header. Neither view knows the other.
    private let offset = CurrentValueSubject<CGFloat, Never>(0)

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scrolling header"
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            VStack(spacing: 8) {
                UIImageView()
                    .contentMode(.scaleAspectFit)
                    .tintColor(.systemPink)
                    .frame(width: 72, height: 72)
                    .isUserInteractionEnabled(true)
                    .bind(\.image, to: model.$isFavorite.map { UIImage(systemName: $0 ? "heart.fill" : "heart") })
                    .sink(\.tapGesturePublisher) { _ in model.toggleFavorite() }
                UILabel()
                    .font(textStyle: .headline)
                    .bind(\.text, to: model.$isFavorite.map { $0 ? "Favorite" : "Tap the heart" })
                UILabel()
                    .font(textStyle: .footnote)
                    .textColor(.secondaryLabel)
                    .bind(\.text, to: offset.map { "Offset \(Int($0))" }.removeDuplicates())
            }
            .card()
            // Fades out over the first 120 points, and grows while the page is pulled down.
            .bind(\.alpha, to: offset.map { 1 - min(max($0 / 120, 0), 1) })
            .onReceive(offset) { header, offset in
                let scale = 1 + max(-offset, 0) / 300
                header.transform = CGAffineTransform(scaleX: scale, y: scale)
            }

            UILabel()
                .font(textStyle: .footnote)
                .textColor(.secondaryLabel)
                .bind(\.text, to: model.$updatedAt.map { "Updated at \(Self.timeFormatter.string(from: $0))" })

            for index in 1...20 {
                HStack(spacing: 8) {
                    UILabel()
                        .text("Row \(index)")
                        .font(textStyle: .body)
                    Spacer()
                }
                .card(padding: 12)
            }

            note("Pull down to refresh. The header fades as the page scrolls up and grows as it is pulled down.")
        }
        .alwaysBounceVertical(true)
        .send({ $0.contentOffsetPublisher.map(\.y) }, to: offset)
        .configure {
            $0.refreshControl = UIRefreshControl()
                .sink(\.refreshPublisher) { model.reload() }
                .onReceive(model.$updatedAt.dropFirst()) { control, _ in control.endRefreshing() }
        }
    }
}
