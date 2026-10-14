# ``DeclarativeCombine``

Combine bindings for UIKit and AppKit views.

## Overview

DeclarativeCombine binds a view to Combine where the view is declared. The binding
modifiers return the view itself and keep their subscriptions on it, so they last as
long as the view, unless you remove them with `unbind()`. Any `UIView` or `NSView`
subclass, including your own, can be bound.

```swift
view.addVStack(alignment: .fill, spacing: 12, safeArea: .all) {
    UITextField()
        .placeholder("Name")
        .sink(\.textPublisher) { [weak self] in self?.model.name = $0 }

    UIButton(type: .system)
        .title("Submit")
        .bind(\.isEnabled, to: $model.map(\.canSubmit))
        .sink(\.tapPublisher) { [weak self] in self?.submit() }
}
```

Publishers must not fail and must emit on the main thread. The view publishers emit
on user interaction, or, for scroll views, when the value changes; none of them emits
its current value on subscription.

## Topics

### Binding

- ``PublisherBindable``
