# DeclarativeCombine

**English** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

Combine bindings for UIKit and AppKit views, made for [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) and [DeclarativeAppKit](https://github.com/nothingsh/DeclarativeAppKit) content closures.

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

Every modifier returns the view itself, and the subscription lives exactly as long as the view. There is no base class to inherit and no protocol to adopt: any `UIView` or `NSView` subclass, including your own, can be bound.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Data to a view](#data-to-a-view)
  - [Events from a view](#events-from-a-view)
  - [Publishers](#publishers)
  - [AppKit](#appkit)
- [Rules](#rules)
- [Example app](#example-app)
  - [Form](#form)
  - [Scrolling header](#scrolling-header)
  - [Controls](#controls)
- [Known limitations](#known-limitations)
- [License](#license)

## Requirements

- iOS 13+ or macOS 11+
- Swift 5.9+

## Installation

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeCombine.git", from: "0.1.0")
]
```

Or in Xcode, choose File → Add Package Dependencies and enter `https://github.com/nothingsh/DeclarativeCombine`.

This package does not depend on DeclarativeUIKit or DeclarativeAppKit. Add it next to either one, or use it on its own with any UIKit or AppKit code.

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
| `UITextField` | `returnPublisher` | `Void`, when the return key is pressed |
| `UITextView` | `textPublisher` | `String`, when the user edits the text |
| `UISwitch` | `isOnPublisher` | `Bool`, on `.valueChanged` |
| `UISlider` | `valuePublisher` | `Float`, on `.valueChanged` |
| `UIStepper` | `valuePublisher` | `Double`, on `.valueChanged` |
| `UISegmentedControl` | `selectedSegmentIndexPublisher` | `Int`, on `.valueChanged` |
| `UIDatePicker` | `datePublisher` | `Date`, on `.valueChanged` |
| `UIPageControl` | `currentPagePublisher` | `Int`, on `.valueChanged` |
| `UIRefreshControl` | `refreshPublisher` | `Void`, when the user pulls to refresh |
| `UIScrollView` | `contentOffsetPublisher` | `CGPoint`, each time the offset changes |
| `UIScrollView` | `contentSizePublisher` | `CGSize`, each time the content size changes |
| `UIView` | `tapGesturePublisher` | `UITapGestureRecognizer`, on each tap |
| `UIView` | `longPressGesturePublisher` | `UILongPressGestureRecognizer`, on each state change |
| `UIView` | `gesturePublisher(_:)` | the recognizer you pass, each time it sends its action |

They can be used without the binding modifiers:

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

Control publishers emit on user interaction only: nothing when you subscribe, and nothing when you set the value in code. The scroll view publishers emit on every change, including one made in code, and still nothing when you subscribe. No publisher keeps its view alive, and none of them completes.

`returnPublisher` uses `.editingDidEndOnExit`, and UIKit dismisses the keyboard when that event has a target.

A search bar's text field is a `UITextField`, so `searchBar.searchTextField.textPublisher` works.

#### Gestures

Subscribing to a gesture publisher adds a recognizer to the view, and cancelling removes it:

```swift
UIImageView(image: photo)
    .isUserInteractionEnabled(true)
    .sink(\.tapGesturePublisher) { [weak self] _ in self?.showPhoto() }

UIView()
    .sink({ $0.gesturePublisher(UIPanGestureRecognizer()) }) { [weak self] pan in
        self?.drag(by: pan.translation(in: pan.view))
    }
```

`UILabel` and `UIImageView` ignore touches until `isUserInteractionEnabled` is `true`. A continuous gesture emits on every state change; read `state` to tell them apart.

### AppKit

On macOS the binding modifiers are the same, and the publishers are named after AppKit's own properties:

```swift
view.addVStack(alignment: .leading, spacing: 12) {
    NSTextField()
        .placeholderString("Name")
        .sink(\.stringValuePublisher) { [weak self] in self?.model.name = $0 }

    NSTextField(labelWithString: "")
        .bind(\.stringValue, to: $model.map(\.hint))

    NSButton()
        .title("Submit")
        .bind(\.isEnabled, to: $model.map(\.canSubmit))
        .sink(\.clickPublisher) { [weak self] in self?.submit() }
}
```

| View | Publisher | Emits |
|---|---|---|
| `NSControl` | `actionPublisher` | `Void`, each time the control sends its action |
| `NSButton` | `clickPublisher` | `Void`, on each click |
| `NSButton` | `statePublisher` | `NSControl.StateValue`, after each click |
| `NSSwitch` | `statePublisher` | `NSControl.StateValue`, when the user flips it |
| `NSSlider` | `doubleValuePublisher` | `Double`, when the user moves it |
| `NSStepper` | `doubleValuePublisher` | `Double`, on each step |
| `NSSegmentedControl` | `selectedSegmentPublisher` | `Int`, when the user picks a segment |
| `NSDatePicker` | `dateValuePublisher` | `Date`, when the user changes the date |
| `NSPopUpButton` | `indexOfSelectedItemPublisher` | `Int`, when the user picks an item |
| `NSTextField` | `stringValuePublisher` | `String`, when the user edits the text |
| `NSTextField` | `returnPublisher` | `Void`, when the return key ends editing |
| `NSTextView` | `stringPublisher` | `String`, when the user edits the text |
| `NSScrollView` | `documentVisibleRectPublisher` | `CGRect`, each time the visible part of the document changes |
| `NSScrollView` | `documentSizePublisher` | `CGSize`, each time the document view's size changes |
| `NSView` | `clickGesturePublisher` | `NSClickGestureRecognizer`, on each click |
| `NSView` | `pressGesturePublisher` | `NSPressGestureRecognizer`, on each state change |
| `NSView` | `gesturePublisher(_:)` | the recognizer you pass, each time it sends its action |

The same rules apply as on iOS: control and text publishers emit on user interaction only, the scroll view publishers emit on every change, and none of them emits when you subscribe.

An `NSControl` has one target and one action, and a control publisher takes both over. Do not set `target` or `action` on a control you subscribe to. Any number of subscriptions can share one control. The two `NSTextField` publishers are the exception: they observe notifications, so the field's own action still works.

AppKit still decides when a control sends its action. A continuous `NSSlider` emits throughout a drag, and `sendAction(on:)` changes when a button does.

The origin of `documentVisibleRectPublisher` is the scroll position, in the document view's coordinates. Its `y` grows downwards when the document view is flipped, as the content of DeclarativeAppKit's `VScroll` and `HScroll` is. The rectangle also changes when the visible area is resized.

A gesture recognizer has a single target too, so pass each recognizer to one subscription only.

## Rules

- **Capture `self` weakly.** The view keeps your closure for as long as it lives, and that includes closures inside the publisher you bind, such as `map { self.format($0) }`. A closure that captures the view controller strongly creates a retain cycle.
- **Publishers must not fail.** Only `Failure == Never` is accepted. Handle errors before binding, for example with `replaceError(with:)`.
- **Emit on the main thread.** Values are applied synchronously, wherever the publisher emits; nothing hops to the main thread for you. Add `receive(on: DispatchQueue.main)` to a publisher that emits in the background.
- **Every value is assigned.** Add `removeDuplicates()` to skip values that did not change.
- **Use the value passed to the closure.** `@Published` emits before the property changes, so reading the property inside `onReceive` returns the old value.
- **Binding one property twice keeps both subscriptions.** The latest value wins.
- **On macOS, a control publisher owns the control's target and action.** Leave both alone on a control you subscribe to. If you replace both, the publisher stops emitting until something subscribes to that control again. If you replace only one, the control's target no longer implements its action, and AppKit raises an exception when the control fires.

## Example app

`Example/Example.xcodeproj` is a small iOS app that uses this package as a local package and DeclarativeUIKit from GitHub. Open it in Xcode, choose the `Example` scheme and an iOS Simulator, and run. The snippets below are trimmed from its three screens.

### Form

This is the form from DeclarativeUIKit's example app. There, the view controller keeps eight views in properties, adds four targets, and needs three `@objc` methods and a text field delegate. Here it keeps none of them, because every control is bound where it is declared. The view model is plain Combine and knows nothing about views. Return in the name field reaches the email field through a subject, `nameReturned`, so neither field refers to the other.

<table>
<tr>
<td>

```swift
UITextField()
    .placeholder("Name")
    .returnKeyType(.next)
    .bind(\.text, to: model.name)
    .send(\.textPublisher, to: model.name)
    .send(\.returnPublisher, to: nameReturned)

UITextField()
    .placeholder("Email")
    .bind(\.text, to: model.email)
    .send(\.textPublisher, to: model.email)
    .onReceive(nameReturned) { field, _ in
        field.becomeFirstResponder()
    }

UISlider()
    .minimumValue(1)
    .maximumValue(7)
    .bind(\.value, to: model.issuesPerWeek)
    .sink(\.valuePublisher) {
        model.issuesPerWeek.send($0.rounded())
    }

UIButton(type: .system)
    .title("Submit")
    .bind(\.isEnabled, to: model.canSubmit)
    .send(\.tapPublisher, to: model.submit)

UILabel()
    .numberOfLines(0)
    .bind(\.text, to: model.result)
```

</td>
<td width="300">
<img src="docs/images/example-form.png" width="300" alt="Form screen">
</td>
</tr>
</table>

### Scrolling header

The scroll view sends its offset to `offset`, a subject kept by the view controller, and the header reads it back: it fades as the page scrolls up. The header and the scroll view never refer to each other. The heart is an image view with a tap gesture, and pull to refresh ends when the model publishes a new time.

<table>
<tr>
<td>

```swift
addScreen {
    VStack(spacing: 8) {
        UIImageView()
            .isUserInteractionEnabled(true)
            .bind(\.image, to: model.$isFavorite.map {
                UIImage(systemName: $0 ? "heart.fill" : "heart")
            })
            .sink(\.tapGesturePublisher) { _ in
                model.toggleFavorite()
            }
        UILabel()
            .bind(\.text, to: offset.map { "Offset \(Int($0))" })
    }
    .card()
    .bind(\.alpha, to: offset.map {
        1 - min(max($0 / 120, 0), 1)
    })

    // ...
}
.send({ $0.contentOffsetPublisher.map(\.y) }, to: offset)
.configure {
    $0.refreshControl = UIRefreshControl()
        .sink(\.refreshPublisher) { model.reload() }
        .onReceive(model.$updatedAt.dropFirst()) { control, _ in
            control.endRefreshing()
        }
}
```

</td>
<td width="300">
<img src="docs/images/example-scroll.png" width="300" alt="Scrolling header screen">
</td>
</tr>
</table>

### Controls

The segmented control writes the selected section to the model, and each section binds `isHidden` to it. The stack view closes the gap a hidden section leaves, so nothing is added or removed. A long press emits on every state change, so the reset filters for the start of the press.

<table>
<tr>
<td>

```swift
UISegmentedControl(items: ControlsViewModel.sections)
    .bind(\.selectedSegmentIndex, to: model.$section)
    .sink(\.selectedSegmentIndexPublisher) {
        model.section = $0
    }

VStack(alignment: .leading, spacing: 12) {
    UIDatePicker()
        .bind(\.date, to: model.$date)
        .sink(\.datePublisher) { model.date = $0 }
    UILabel()
        .bind(\.text, to: model.$date.map {
            Self.dateFormatter.string(from: $0)
        })
}
.card()
.bind(\.isHidden, to: model.$section.map { $0 != 1 })

UILabel()
    .text("Hold here to reset")
    .isUserInteractionEnabled(true)
    .sink({
        $0.longPressGesturePublisher.filter { $0.state == .began }
    }) { _ in model.reset() }
```

</td>
<td width="300">
<img src="docs/images/example-controls.png" width="300" alt="Controls screen">
</td>
</tr>
</table>

## Known limitations

- A content closure still runs once. Bindings update properties; they do not add, remove or reorder views.
- A binding cannot be removed before its view is released, so do not bind again each time a reusable cell is configured.
- There are no publishers for delegate callbacks, such as selecting a table view row. Set the delegate yourself.
- On macOS, choosing an item from an `NSComboBox` list does not emit from `stringValuePublisher`; only typing does.
- On macOS, `documentVisibleRectPublisher` reports the document view's own coordinates, so `origin.y` runs upwards unless the document view is flipped.
- The example app is iOS only.

## License

MIT. See [LICENSE](LICENSE).
