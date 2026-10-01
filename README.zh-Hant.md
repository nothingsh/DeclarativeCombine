# DeclarativeUIKitCombine

[English](README.md) | [简体中文](README.zh-Hans.md) | **繁體中文**

為 UIKit 視圖提供 Combine 綁定，搭配 [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) 的內容閉包使用。

需要更新或回報事件的視圖，不必再存成版面配置之外的屬性。在宣告它的地方直接綁定：

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

每個 modifier 都回傳視圖本身，訂閱的生命週期與視圖完全一致。不需要繼承基底類別，也不需要遵循協定：任何 `UIView` 子類別，包括你自己的，都可以綁定。

## 環境需求

- iOS 13+
- Swift 5.9+

## 安裝

使用 Swift Package Manager。在 `Package.swift` 中：

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeUIKitCombine.git", from: "0.1.0")
]
```

或在 Xcode 中選擇 File → Add Package Dependencies，輸入 `https://github.com/nothingsh/DeclarativeUIKitCombine`。

本套件不依賴 DeclarativeUIKit。兩個套件一起加入即可搭配使用，也可以單獨用在任何 UIKit 程式碼裡。

## 用法

### 資料到視圖

`bind(_:to:)` 把 publisher 發出的每個值指派給視圖的一個屬性：

```swift
UILabel().bind(\.text, to: viewModel.$title)
UIButton().bind(\.isEnabled, to: viewModel.$canSubmit)
AvatarView().bind(\.user, to: viewModel.$user)   // 你自己的視圖和屬性
```

用 Combine 的運算子從較大的模型裡取出一個欄位：

```swift
UILabel().bind(\.text, to: $model.map(\.title).removeDuplicates())
```

`onReceive(_:perform:)` 用於不是單一屬性的情況。閉包會收到視圖和值：

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

要顯示或隱藏視圖，綁定 `isHidden`。stack view 會收合隱藏的子視圖：

```swift
UILabel().bind(\.isHidden, to: $model.map(\.error.isEmpty))
```

### 視圖的事件

`sink(_:receiveValue:)` 訂閱視圖自己的某個 publisher：

```swift
UIButton(type: .system)
    .sink(\.tapPublisher) { [weak self] in self?.submit() }

UITextField()
    .sink({ $0.publisher(for: .editingDidEnd) }) { [weak self] in self?.validate() }
```

`send(_:to:)` 把值轉送給一個 subject。completion 不會被轉送：

```swift
let taps = PassthroughSubject<Void, Never>()

UIButton(type: .system).send(\.tapPublisher, to: taps)
```

在同一個 subject 上同時 bind 和 send，就是雙向綁定：

```swift
let name = CurrentValueSubject<String, Never>("")

UITextField()
    .bind(\.text, to: name)
    .send(\.textPublisher, to: name)
```

### Publisher

| 視圖 | Publisher | 發出 |
|---|---|---|
| `UIControl` | `publisher(for:)` | `Void`，每次其中一個事件觸發時 |
| `UIButton` | `tapPublisher` | `Void`，`.touchUpInside` 時 |
| `UITextField` | `textPublisher` | `String`，`.editingChanged` 時 |
| `UISwitch` | `isOnPublisher` | `Bool`，`.valueChanged` 時 |
| `UISlider` | `valuePublisher` | `Float`，`.valueChanged` 時 |
| `UITextView` | `textPublisher` | `String`，使用者編輯文字時 |

它們可以脫離綁定 modifier 單獨使用：

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

這些 publisher 只在使用者互動時發出。訂閱時不發出，用程式碼指派時也不發出。它們弱參考視圖，並且不會結束。

## 規則

- **弱參考 `self`。** 視圖在存活期間一直持有你的閉包。閉包強參考視圖控制器會造成循環參考。
- **publisher 不能失敗。** 只接受 `Failure == Never`。綁定前先處理錯誤，例如用 `replaceError(with:)`。
- **值在 publisher 發出的執行緒上套用。** 在背景發出的 publisher 要加 `receive(on: DispatchQueue.main)`。
- **每個值都會被指派。** 加 `removeDuplicates()` 可以略過沒有變化的值。
- **使用傳給閉包的值。** `@Published` 在屬性改變之前發出，在 `onReceive` 或 `sink` 裡讀這個屬性得到的是舊值。
- **同一個屬性綁定兩次，兩個訂閱都會保留。** 以最新的值為準。

## 已知限制

- 內容閉包仍然只執行一次。綁定更新的是屬性，不會新增、移除或重排視圖。
- 綁定在視圖釋放之前無法移除，所以不要在每次設定可重用 cell 時重新綁定。
- 沒有手勢辨識器和代理的 publisher。

## 授權

MIT。見 [LICENSE](LICENSE)。
