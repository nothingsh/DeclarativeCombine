# DeclarativeUIKitCombine

**English** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

Combine bindings for UIKit views, made for [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) content closures.

A view that needs to change, or to report events, no longer has to be stored in a property outside the layout. Bind it where it is declared:

```swift
view.addVStack(alignment: .fill, spacing: 12, safeArea: .all) {
    UITextField()
        .placeholder("Name")
        .sink(\.textPublisher) { [weak self] in self?.model.name = $0 }

    UILabel()
        .font(textStyle: .footnote)
        .bind(\.text, to: $model.map(\.hint))

    UIButton(type: .system)
        .title("Submit")
        .bind(\.isEnabled, to: $model.map(\.canSubmit))
        .sink(\.tapPublisher) { [weak self] in self?.submit() }
}
```

Every modifier returns the view itself, and the subscription lives exactly as long as the view. There is no base class to inherit and no protocol to adopt: any `UIView` subclass, including your own, can be bound.

## Requirements

- iOS 13+
- Swift 5.9+

## Installation

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeUIKitCombine.git", from: "0.1.0")
]
```

Or in Xcode, choose File → Add Package Dependencies and enter `https://github.com/nothingsh/DeclarativeUIKitCombine`.

This package does not depend on DeclarativeUIKit. Add both packages to use them together, or use this one on its own with any UIKit code.

## Usage

### Data to a view

`bind(_:to:)` assigns each value a publisher emits to a property of the view:

```swift
UILabel().bind(\.text, to: viewModel.$title)
UIButton().bind(\.isEnabled, to: viewModel.$canSubmit)
AvatarView().bind(\.user, to: viewModel.$user)   // your own view and property
```

Use Combine's operators to pick a field out of a larger model:

```swift
UILabel().bind(\.text, to: $model.map(\.title).removeDuplicates())
```

`onReceive(_:perform:)` is for anything that is not a single property. The closure receives the view and the value:

```swift
UIButton(type: .system)
    .onReceive(viewModel.$title) { button, title in
        button.setTitle(title, for: .normal)
    }

UITextField()
    .onReceive(viewModel.focusName) { field, _ in
        field.becomeFirstResponder()
    }
```

To show or hide a view, bind `isHidden`. A stack view collapses its hidden arranged subviews:

```swift
UILabel().bind(\.isHidden, to: $model.map(\.error.isEmpty))
```

### Events from a view

`sink(_:receiveValue:)` subscribes to one of the view's own publishers:

```swift
UIButton(type: .system)
    .sink(\.tapPublisher) { [weak self] in self?.submit() }

UITextField()
    .sink({ $0.publisher(for: .editingDidEnd) }) { [weak self] in self?.validate() }
```

`send(_:to:)` forwards the values to a subject. Completion is not forwarded:

```swift
let taps = PassthroughSubject<Void, Never>()

UIButton(type: .system).send(\.tapPublisher, to: taps)
```

Bind and send on the same subject for a two-way binding:

```swift
let name = CurrentValueSubject<String, Never>("")

UITextField()
    .bind(\.text, to: name)
    .send(\.textPublisher, to: name)
```

### Publishers

| View | Publisher | Emits |
|---|---|---|
| `UIControl` | `publisher(for:)` | `Void`, each time one of the events fires |
| `UIButton` | `tapPublisher` | `Void`, on `.touchUpInside` |
| `UITextField` | `textPublisher` | `String`, on `.editingChanged` |
| `UISwitch` | `isOnPublisher` | `Bool`, on `.valueChanged` |
| `UISlider` | `valuePublisher` | `Float`, on `.valueChanged` |
| `UITextView` | `textPublisher` | `String`, when the user edits the text |

They can be used without the binding modifiers:

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

These publishers emit on user interaction only. They emit nothing when you subscribe and nothing when you set the value in code. They hold the view weakly and never complete.

## Rules

- **Capture `self` weakly.** The view keeps your closure for as long as it lives. A closure that captures the view controller strongly creates a retain cycle.
- **Publishers must not fail.** Only `Failure == Never` is accepted. Handle errors before binding, for example with `replaceError(with:)`.
- **Emit on the main thread.** Values are applied synchronously, wherever the publisher emits; nothing hops to the main thread for you. Add `receive(on: DispatchQueue.main)` to a publisher that emits in the background.
- **Every value is assigned.** Add `removeDuplicates()` to skip values that did not change.
- **Use the value passed to the closure.** `@Published` emits before the property changes, so reading the property inside `onReceive` returns the old value.
- **Binding one property twice keeps both subscriptions.** The latest value wins.

## Known limitations

- A content closure still runs once. Bindings update properties; they do not add, remove or reorder views.
- A binding cannot be removed before its view is released, so do not bind again each time a reusable cell is configured.
- There are no publishers for gesture recognizers or delegates.

## License

MIT. See [LICENSE](LICENSE).
