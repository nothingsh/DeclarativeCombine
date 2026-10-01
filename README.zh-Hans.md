# DeclarativeCombine

[English](README.md) | **简体中文** | [繁體中文](README.zh-Hant.md)

为 UIKit 和 AppKit 视图提供 Combine 绑定，配合 [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) 和 [DeclarativeAppKit](https://github.com/nothingsh/DeclarativeAppKit) 的内容闭包使用。

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

每个 modifier 都返回视图本身，订阅的生命周期与视图完全一致。不需要继承基类，也不需要遵循协议：任何 `UIView` 或 `NSView` 子类，包括你自己的，都可以绑定。

## 目录

- [环境要求](#环境要求)
- [安装](#安装)
- [用法](#用法)
  - [数据到视图](#数据到视图)
  - [视图的事件](#视图的事件)
  - [Publisher](#publisher)
  - [AppKit](#appkit)
- [规则](#规则)
- [示例 App](#示例-app)
  - [Form](#form)
  - [Scrolling header](#scrolling-header)
  - [Controls](#controls)
  - [macOS form](#macos-form)
- [已知限制](#已知限制)
- [许可](#许可)

## 环境要求

- iOS 13+ 或 macOS 11+
- Swift 5.9+

## 安装

使用 Swift Package Manager。在 `Package.swift` 中：

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeCombine.git", from: "0.1.0")
]
```

或在 Xcode 中选择 File → Add Package Dependencies，输入 `https://github.com/nothingsh/DeclarativeCombine`。

本包不依赖 DeclarativeUIKit 或 DeclarativeAppKit。和其中任何一个一起添加即可配合使用，也可以单独用在任何 UIKit 或 AppKit 代码里。

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
| `UITextField` | `returnPublisher` | `Void`，按下回车键时 |
| `UITextView` | `textPublisher` | `String`，用户编辑文本时 |
| `UISwitch` | `isOnPublisher` | `Bool`，`.valueChanged` 时 |
| `UISlider` | `valuePublisher` | `Float`，`.valueChanged` 时 |
| `UIStepper` | `valuePublisher` | `Double`，`.valueChanged` 时 |
| `UISegmentedControl` | `selectedSegmentIndexPublisher` | `Int`，`.valueChanged` 时 |
| `UIDatePicker` | `datePublisher` | `Date`，`.valueChanged` 时 |
| `UIPageControl` | `currentPagePublisher` | `Int`，`.valueChanged` 时 |
| `UIRefreshControl` | `refreshPublisher` | `Void`，用户下拉刷新时 |
| `UIScrollView` | `contentOffsetPublisher` | `CGPoint`，每次偏移量变化时 |
| `UIScrollView` | `contentSizePublisher` | `CGSize`，每次内容尺寸变化时 |
| `UIView` | `tapGesturePublisher` | `UITapGestureRecognizer`，每次点击时 |
| `UIView` | `longPressGesturePublisher` | `UILongPressGestureRecognizer`，每次状态变化时 |
| `UIView` | `gesturePublisher(_:)` | 你传入的识别器，每次它发送 action 时 |

它们可以脱离绑定 modifier 单独使用：

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

控件的 publisher 只在用户交互时发出：订阅时不发出，用代码赋值时也不发出。scroll view 的 publisher 在每次变化时发出，包括代码造成的变化，订阅时同样不发出。所有 publisher 都不会让视图无法释放，也都不会结束。

`returnPublisher` 使用 `.editingDidEndOnExit`，这个事件有 target 时 UIKit 会收起键盘。

搜索栏的文本框是 `UITextField`，所以 `searchBar.searchTextField.textPublisher` 可以直接用。

#### 手势

订阅手势 publisher 会给视图添加一个识别器，取消订阅时移除：

```swift
UIImageView(image: photo)
    .isUserInteractionEnabled(true)
    .sink(\.tapGesturePublisher) { [weak self] _ in self?.showPhoto() }

UIView()
    .sink({ $0.gesturePublisher(UIPanGestureRecognizer()) }) { [weak self] pan in
        self?.drag(by: pan.translation(in: pan.view))
    }
```

`UILabel` 和 `UIImageView` 在 `isUserInteractionEnabled` 为 `true` 之前不响应触摸。连续手势在每次状态变化时都发出，用 `state` 区分。

### AppKit

在 macOS 上绑定 modifier 完全相同，publisher 按 AppKit 自己的属性命名：

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

| 视图 | Publisher | 发出 |
|---|---|---|
| `NSControl` | `actionPublisher` | `Void`，控件每次发送 action 时 |
| `NSButton` | `clickPublisher` | `Void`，每次点击时 |
| `NSButton` | `statePublisher` | `NSControl.StateValue`，每次点击之后 |
| `NSSwitch` | `statePublisher` | `NSControl.StateValue`，用户拨动开关时 |
| `NSSlider` | `doubleValuePublisher` | `Double`，用户拖动时 |
| `NSStepper` | `doubleValuePublisher` | `Double`，每次步进时 |
| `NSSegmentedControl` | `selectedSegmentPublisher` | `Int`，用户选择分段时 |
| `NSDatePicker` | `dateValuePublisher` | `Date`，用户修改日期时 |
| `NSPopUpButton` | `indexOfSelectedItemPublisher` | `Int`，用户选择条目时 |
| `NSTextField` | `stringValuePublisher` | `String`，用户编辑文本时 |
| `NSTextField` | `returnPublisher` | `Void`，按回车键结束编辑时 |
| `NSTextView` | `stringPublisher` | `String`，用户编辑文本时 |
| `NSScrollView` | `documentVisibleRectPublisher` | `CGRect`，每次文档的可见部分变化时 |
| `NSScrollView` | `documentSizePublisher` | `CGSize`，每次 document view 的尺寸变化时 |
| `NSView` | `clickGesturePublisher` | `NSClickGestureRecognizer`，每次点击时 |
| `NSView` | `pressGesturePublisher` | `NSPressGestureRecognizer`，每次状态变化时 |
| `NSView` | `gesturePublisher(_:)` | 你传入的识别器，每次它发送 action 时 |

规则与 iOS 上相同：控件和文本的 publisher 只在用户交互时发出，scroll view 的 publisher 在每次变化时发出，订阅时都不发出。

`NSControl` 只有一个 target 和一个 action，控件的 publisher 会接管它们。不要给你订阅的控件设置 `target` 或 `action`。同一个控件可以有任意多个订阅。`NSTextField` 的两个 publisher 是例外：它们监听通知，所以文本框自己的 action 照常工作。

控件何时发送 action 仍由 AppKit 决定。连续模式的 `NSSlider` 在拖动过程中持续发出，`sendAction(on:)` 会改变按钮发出的时机。

`documentVisibleRectPublisher` 的 origin 是滚动位置，使用 document view 的坐标系。document view 是 flipped 时 `y` 向下增大，DeclarativeAppKit 的 `VScroll` 和 `HScroll` 的内容就是这样。可见区域的大小改变时这个矩形也会变化。

手势识别器同样只有一个 target，所以每个识别器只传给一个订阅。

## 规则

- **弱引用 `self`。** 视图在存活期间一直持有你的闭包，也包括你绑定的 publisher 里的闭包，例如 `map { self.format($0) }`。闭包强引用视图控制器会造成循环引用。
- **publisher 不能失败。** 只接受 `Failure == Never`。绑定前先处理错误，例如用 `replaceError(with:)`。
- **在主线程发出。** 值在 publisher 发出的地方同步应用，库不会替你切到主线程。在后台发出的 publisher 要加 `receive(on: DispatchQueue.main)`。
- **每个值都会被赋值。** 加 `removeDuplicates()` 可以跳过没有变化的值。
- **使用传给闭包的值。** `@Published` 在属性改变之前发出，在 `onReceive` 里读这个属性得到的是旧值。
- **同一个属性绑定两次，两个订阅都会保留。** 以最新的值为准。
- **在 macOS 上，控件的 publisher 占用控件的 target 和 action。** 不要改动你订阅的控件的这两个属性。两个都换掉，publisher 就不再发出，直到这个控件再次被订阅。只换掉其中一个，控件的 target 就不再实现它的 action，控件触发时 AppKit 会抛出异常。

## 示例 App

`Example/Example.xcodeproj` 里有两个小型 App，都以本地包的方式使用本包：iOS App 搭配 DeclarativeUIKit，macOS App 搭配 DeclarativeAppKit，两者都从 GitHub 引入。用 Xcode 打开，在 iOS 模拟器上运行 `Example` scheme，或在你的 Mac 上运行 `ExampleMac` scheme。两个 App 有同样的三个页面。下面的代码片段摘自 iOS App，最后是 [macOS App 的表单](#macos-form)。

### Form

这就是 DeclarativeUIKit 示例 App 里的那个表单。在那边，视图控制器把八个视图存成属性，添加了四个 target，还需要三个 `@objc` 方法和一个文本框代理。在这里这些都不需要，因为每个控件都在声明它的地方绑定。view model 是纯 Combine，对视图一无所知。在 name 文本框里按回车，会通过 `nameReturned` 这个 subject 传到 email 文本框，两个文本框互不引用。

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
<img src="docs/images/example-form.png" width="300" alt="表单页面">
</td>
</tr>
</table>

### Scrolling header

scroll view 把偏移量发给 `offset`，这是视图控制器持有的一个 subject，头部再从它读回来：页面上滑时头部淡出。头部和 scroll view 互不引用。心形是一个带点击手势的 image view，下拉刷新在 model 发布新时间时结束。

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
<img src="docs/images/example-scroll.png" width="300" alt="滚动头部页面">
</td>
</tr>
</table>

### Controls

分段控件把选中的区块写入 model，每个区块把 `isHidden` 绑定到它。stack view 会收起隐藏区块留下的空隙，所以没有视图被添加或移除。长按在每次状态变化时都发出，所以重置时只取长按开始的那一次。

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
<img src="docs/images/example-controls.png" width="300" alt="控件页面">
</td>
</tr>
</table>

### macOS form

AppKit 版的同一张表单，来自 `Example/ExampleMac`。publisher 用的是 AppKit 的名字，另有两处与 iOS 不同。回车结束编辑时 AppKit 会重新选中姓名文本框，所以焦点在 run loop 的下一轮才移到邮箱文本框。给 text view 的 `string` 赋值会移动插入点，所以只有当模型与输入的内容不同时才写入备注。

```swift
NSTextField()
    .placeholderString("Name")
    .bind(\.stringValue, to: model.name)
    .send(\.stringValuePublisher, to: model.name)
    .send(\.returnPublisher, to: nameReturned)

NSTextField()
    .placeholderString("Email")
    .bind(\.stringValue, to: model.email)
    .send(\.stringValuePublisher, to: model.email)
    .onReceive(nameReturned.receive(on: DispatchQueue.main)) { field, _ in
        field.window?.makeFirstResponder(field)
    }

NSTextView()
    .onReceive(model.notes) { textView, notes in
        if textView.string != notes {
            textView.string = notes
        }
    }
    .send(\.stringPublisher, to: model.notes)

NSSwitch()
    .bind(\.state, to: model.newsletter.map { $0 ? .on : .off })
    .sink(\.statePublisher) { model.newsletter.send($0 == .on) }

NSButton()
    .title("Submit")
    .bind(\.isEnabled, to: model.canSubmit)
    .send(\.clickPublisher, to: model.submit)
```

## 已知限制

- 内容闭包仍然只运行一次。绑定更新的是属性，不会增加、移除或重排视图。
- 绑定在视图释放之前无法移除，所以不要在每次配置可复用 cell 时重新绑定。
- 没有代理回调的 publisher，例如选中表格的一行。请自己设置代理。
- 在 macOS 上，从 `NSComboBox` 的下拉列表里选择条目不会让 `stringValuePublisher` 发出，只有键入才会。
- 在 macOS 上，`documentVisibleRectPublisher` 使用 document view 自己的坐标系，所以除非 document view 是 flipped，否则 `origin.y` 向上增大。

## 许可

MIT。见 [LICENSE](LICENSE)。
