import AppKit
import Combine
import DeclarativeAppKit
import DeclarativeCombine

/// The state of the form. It knows nothing about views.
final class FormViewModel {

    let name = CurrentValueSubject<String, Never>("")
    let email = CurrentValueSubject<String, Never>("")
    let notes = CurrentValueSubject<String, Never>(FormViewModel.defaultNotes)
    let newsletter = CurrentValueSubject<Bool, Never>(true)
    let issuesPerWeek = CurrentValueSubject<Double, Never>(3)

    let submit = PassthroughSubject<Void, Never>()
    let clear = PassthroughSubject<Void, Never>()

    private static let defaultNotes = "Notes are a text view, bound in both directions."
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

/// The form from DeclarativeAppKit's example, with every control bound where it
/// is declared. The screen stores no view, sets no target and has no delegate.
final class FormExampleViewController: ExampleScreenViewController {

    private let model = FormViewModel()

    /// The name field's return key, received by the email field.
    private let nameReturned = PassthroughSubject<Void, Never>()

    init() {
        super.init(title: "Form")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The closures below capture the model, not the view controller.
        let model = model

        addScreen {
            sectionTitle("Contact")
            VStack(alignment: .fill, spacing: 12) {
                NSTextField()
                    .placeholderString("Name")
                    .bind(\.stringValue, to: model.name)
                    .send(\.stringValuePublisher, to: model.name)
                    .send(\.returnPublisher, to: nameReturned)

                NSTextField()
                    .placeholderString("Email")
                    .bind(\.stringValue, to: model.email)
                    .send(\.stringValuePublisher, to: model.email)
                    // AppKit selects the name field again when return ends its editing, so
                    // the focus moves on the next turn of the run loop.
                    .onReceive(nameReturned.receive(on: DispatchQueue.main)) { field, _ in
                        field.window?.makeFirstResponder(field)
                    }

                NSTextView()
                    .font(.preferredFont(forTextStyle: .body))
                    .frame(height: 64)
                    .configure { $0.textContainerInset = NSSize(width: 4, height: 6) }
                    // Setting a text view's string moves its insertion point, so the text
                    // is written only when the model differs from what was typed.
                    .onReceive(model.notes) { textView, notes in
                        if textView.string != notes {
                            textView.string = notes
                        }
                    }
                    .send(\.stringPublisher, to: model.notes)
            }
            .card()

            sectionTitle("Preferences")
            VStack(alignment: .fill, spacing: 12) {
                HStack(spacing: 8) {
                    NSTextField(labelWithString: "Newsletter")
                    Spacer()
                    NSSwitch()
                        .bind(\.state, to: model.newsletter.map { $0 ? .on : .off })
                        .sink(\.statePublisher) { model.newsletter.send($0 == .on) }
                }
                HStack(spacing: 8) {
                    NSTextField(labelWithString: "Issues per week")
                    Spacer()
                    NSTextField(labelWithString: "")
                        .textColor(.secondaryLabelColor)
                        .bind(\.stringValue, to: model.issuesPerWeekText)
                }
                // The tick marks keep the slider on whole numbers.
                NSSlider()
                    .minValue(1)
                    .maxValue(7)
                    .configure {
                        $0.numberOfTickMarks = 7
                        $0.allowsTickMarkValuesOnly = true
                    }
                    .bind(\.doubleValue, to: model.issuesPerWeek)
                    .send(\.doubleValuePublisher, to: model.issuesPerWeek)
            }
            .card()

            HStack(spacing: 12) {
                NSButton()
                    .title("Submit")
                    .bezelStyle(.rounded)
                    .bind(\.isEnabled, to: model.canSubmit)
                    .send(\.clickPublisher, to: model.submit)
                NSButton()
                    .title("Clear")
                    .bezelStyle(.rounded)
                    .send(\.clickPublisher, to: model.clear)
                Spacer()
            }

            NSTextField(wrappingLabelWithString: "")
                .font(.preferredFont(forTextStyle: .footnote))
                .textColor(.secondaryLabelColor)
                .bind(\.stringValue, to: model.result)

            note("""
                Submit is enabled once name and email are filled in. Clear resets the model, \
                and every control follows it. Return in the name field moves to the email field.
                """)
        }
    }
}
