# DeclarativeUIKitCombine

[English](README.md) | **简体中文** | [繁體中文](README.zh-Hant.md)

为 UIKit 视图提供 Combine 绑定，配合 [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) 的内容闭包使用。

需要更新或上报事件的视图，不必再存成布局之外的属性。在声明它的地方直接绑定：

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

每个 modifier 都返回视图本身，订阅的生命周期与视图完全一致。不需要继承基类，也不需要遵循协议：任何 `UIView` 子类，包括你自己的，都可以绑定。

## 环境要求

- iOS 13+
- Swift 5.9+

## 安装

使用 Swift Package Manager。在 `Package.swift` 中：

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeUIKitCombine.git", from: "0.1.0")
]
```

或在 Xcode 中选择 File → Add Package Dependencies，输入 `https://github.com/nothingsh/DeclarativeUIKitCombine`。

本包不依赖 DeclarativeUIKit。两个包一起添加即可配合使用，也可以单独用在任何 UIKit 代码里。

## 用法

### 数据到视图

`bind(_:to:)` 把 publisher 发出的每个值赋给视图的一个属性：

```swift
UILabel().bind(\.text, to: viewModel.$title)
UIButton().bind(\.isEnabled, to: viewModel.$canSubmit)
AvatarView().bind(\.user, to: viewModel.$user)   // 你自己的视图和属性
```

用 Combine 的操作符从较大的模型里取出一个字段：

```swift
UILabel().bind(\.text, to: $model.map(\.title).removeDuplicates())
```

`onReceive(_:perform:)` 用于不是单个属性的情况。闭包会收到视图和值：

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

要显示或隐藏视图，绑定 `isHidden`。stack view 会收起隐藏的子视图：

```swift
UILabel().bind(\.isHidden, to: $model.map(\.error.isEmpty))
```

### 视图的事件

`sink(_:receiveValue:)` 订阅视图自己的某个 publisher：

```swift
UIButton(type: .system)
    .sink(\.tapPublisher) { [weak self] in self?.submit() }

UITextField()
    .sink({ $0.publisher(for: .editingDidEnd) }) { [weak self] in self?.validate() }
```

`send(_:to:)` 把值转发给一个 subject。completion 不会被转发：

```swift
let taps = PassthroughSubject<Void, Never>()

UIButton(type: .system).send(\.tapPublisher, to: taps)
```

在同一个 subject 上同时 bind 和 send，就是双向绑定：

```swift
let name = CurrentValueSubject<String, Never>("")

UITextField()
    .bind(\.text, to: name)
    .send(\.textPublisher, to: name)
```

### Publisher

| 视图 | Publisher | 发出 |
|---|---|---|
| `UIControl` | `publisher(for:)` | `Void`，每次其中一个事件触发时 |
| `UIButton` | `tapPublisher` | `Void`，`.touchUpInside` 时 |
| `UITextField` | `textPublisher` | `String`，`.editingChanged` 时 |
| `UISwitch` | `isOnPublisher` | `Bool`，`.valueChanged` 时 |
| `UISlider` | `valuePublisher` | `Float`，`.valueChanged` 时 |
| `UITextView` | `textPublisher` | `String`，用户编辑文本时 |

它们可以脱离绑定 modifier 单独使用：

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

这些 publisher 只在用户交互时发出。订阅时不发出，用代码赋值时也不发出。它们弱引用视图，并且不会结束。

## 规则

- **弱引用 `self`。** 视图在存活期间一直持有你的闭包。闭包强引用视图控制器会造成循环引用。
- **publisher 不能失败。** 只接受 `Failure == Never`。绑定前先处理错误，例如用 `replaceError(with:)`。
- **值在 publisher 发出的线程上应用。** 在后台发出的 publisher 要加 `receive(on: DispatchQueue.main)`。
- **每个值都会被赋值。** 加 `removeDuplicates()` 可以跳过没有变化的值。
- **使用传给闭包的值。** `@Published` 在属性改变之前发出，在 `onReceive` 或 `sink` 里读这个属性得到的是旧值。
- **同一个属性绑定两次，两个订阅都会保留。** 以最新的值为准。

## 已知限制

- 内容闭包仍然只运行一次。绑定更新的是属性，不会增加、移除或重排视图。
- 绑定在视图释放之前无法移除，所以不要在每次配置可复用 cell 时重新绑定。
- 没有手势识别器和代理的 publisher。

## 许可

MIT。见 [LICENSE](LICENSE)。
