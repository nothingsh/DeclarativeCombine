import Combine
import DeclarativeCombine
import DeclarativeUIKit
import UIKit

/// The state of the form. It knows nothing about views.
final class FormViewModel {

    let name = CurrentValueSubject<String, Never>("")
    let email = CurrentValueSubject<String, Never>("")
    let notes = CurrentValueSubject<String, Never>(FormViewModel.defaultNotes)
    let newsletter = CurrentValueSubject<Bool, Never>(true)
    let issuesPerWeek = CurrentValueSubject<Float, Never>(3)

    let submit = PassthroughSubject<Void, Never>()
    let clear = PassthroughSubject<Void, Never>()

    private static let defaultNotes = "Notes grow with their text, because scrolling is off."
    private var cancellables = Set<AnyCancellable>()

    init() {
        clear
            .sink { [weak self] in self?.reset() }
            .store(in: &cancellables)
    }

    var canSubmit: AnyPublisher<Bool, Never> {
        name.combineLatest(email)
            .map { !$0.isEmpty && !$1.isEmpty }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var issuesPerWeekText: AnyPublisher<String, Never> {
        issuesPerWeek
            .map { "\(Int($0))" }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// The summary of the last submission, emptied again by Clear.
    var result: AnyPublisher<String, Never> {
        let saved = submit.map { [name, email, notes, newsletter, issuesPerWeek] in
            """
            Saved \(name.value) <\(email.value)>, \
            newsletter \(newsletter.value ? "on" : "off"), \
            \(Int(issuesPerWeek.value)) per week.
            Notes: \(notes.value)
            """
        }
        return saved.merge(with: clear.map { "" }).eraseToAnyPublisher()
    }

    private func reset() {
        name.send("")
        email.send("")
        notes.send(Self.defaultNotes)
        newsletter.send(true)
        issuesPerWeek.send(3)
    }
}

/// The form from DeclarativeUIKit's example, with every control bound where it
/// is declared. The screen stores no view, adds no target and has no delegate.
final class FormExampleViewController: UIViewController {

    private let model = FormViewModel()

    /// The name field's return key, received by the email field.
    private let nameReturned = PassthroughSubject<Void, Never>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Form"
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            sectionTitle("Contact")
            VStack(alignment: .fill, spacing: 12) {
                UITextField()
                    .placeholder("Name")
                    .font(textStyle: .body)
                    .returnKeyType(.next)
                    .configure { $0.borderStyle = .roundedRect }
                    .bind(\.text, to: model.name)
                    .send(\.textPublisher, to: model.name)
                    .send(\.returnPublisher, to: nameReturned)

                UITextField()
                    .placeholder("Email")
                    .font(textStyle: .body)
                    .keyboardType(.emailAddress)
                    .returnKeyType(.done)
                    .configure {
                        $0.borderStyle = .roundedRect
                        $0.autocapitalizationType = .none
                        $0.autocorrectionType = .no
                    }
                    .bind(\.text, to: model.email)
                    .send(\.textPublisher, to: model.email)
                    .onReceive(nameReturned) { field, _ in field.becomeFirstResponder() }
                    // UIKit dismisses the keyboard on return once this event has a subscriber.
                    .sink(\.returnPublisher) {}

                // Not scrollable, so it is as tall as its text and grows while you type.
                UITextView()
                    .font(textStyle: .body)
                    .isScrollEnabled(false)
                    .frame(minHeight: 44)
                    .configure {
                        $0.layer.cornerRadius = 6
                        $0.layer.borderWidth = 1
                        $0.layer.borderColor = UIColor.separator.cgColor
                    }
                    .bind(\.text, to: model.notes)
                    .send(\.textPublisher, to: model.notes)
            }
            .card()

            sectionTitle("Preferences")
            VStack(alignment: .fill, spacing: 12) {
                HStack(spacing: 8) {
                    UILabel()
                        .text("Newsletter")
                        .font(textStyle: .body)
                        .numberOfLines(0)
                    Spacer()
                    UISwitch()
                        .bind(\.isOn, to: model.newsletter)
                        .send(\.isOnPublisher, to: model.newsletter)
                }
                HStack(spacing: 8) {
                    UILabel()
                        .text("Issues per week")
                        .font(textStyle: .body)
                        .numberOfLines(0)
                    Spacer()
                    UILabel()
                        .font(textStyle: .body)
                        .textColor(.secondaryLabel)
                        .bind(\.text, to: model.issuesPerWeekText)
                }
                // The model keeps whole numbers, and the binding snaps the thumb to them.
                UISlider()
                    .minimumValue(1)
                    .maximumValue(7)
                    .bind(\.value, to: model.issuesPerWeek)
                    .sink(\.valuePublisher) { model.issuesPerWeek.send($0.rounded()) }
            }
            .card()

            HStack(spacing: 16) {
                UIButton(type: .system)
                    .title("Submit")
                    .titleColor(.tertiaryLabel, for: .disabled)
                    .bind(\.isEnabled, to: model.canSubmit)
                    .send(\.tapPublisher, to: model.submit)
                    .sink(\.tapPublisher) { [weak self] in self?.view.endEditing(true) }
                UIButton(type: .system)
                    .title("Clear")
                    .send(\.tapPublisher, to: model.clear)
                Spacer()
            }

            UILabel()
                .font(textStyle: .footnote)
                .textColor(.secondaryLabel)
                .numberOfLines(0)
                .bind(\.text, to: model.result)

            note("""
                Submit is enabled once name and email are filled in. Clear resets the model, \
                and every control follows it. Return in the name field moves to the email field.
                """)
        }
        .alwaysBounceVertical(true)
        .configure { $0.keyboardDismissMode = .onDrag }
    }
}
