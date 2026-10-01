# DeclarativeCombine

[English](README.md) | [简体中文](README.zh-Hans.md) | **繁體中文**

為 UIKit 和 AppKit 視圖提供 Combine 繫結，搭配 [DeclarativeUIKit](https://github.com/nothingsh/DeclarativeUIKit) 和 [DeclarativeAppKit](https://github.com/nothingsh/DeclarativeAppKit) 的內容閉包使用。

需要更新或回報事件的視圖，不必再存成版面配置之外的屬性。在宣告它的地方直接繫結：

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

每個 modifier 都回傳視圖本身，訂閱的生命週期與視圖完全一致。不需要繼承基底類別，也不需要遵循協定：任何 `UIView` 或 `NSView` 子類別，包括你自己的，都可以繫結。

## 目錄

- [環境需求](#環境需求)
- [安裝](#安裝)
- [用法](#用法)
  - [資料到視圖](#資料到視圖)
  - [視圖的事件](#視圖的事件)
  - [Publisher](#publisher)
  - [AppKit](#appkit)
- [規則](#規則)
- [範例 App](#範例-app)
  - [Form](#form)
  - [Scrolling header](#scrolling-header)
  - [Controls](#controls)
- [已知限制](#已知限制)
- [授權](#授權)

## 環境需求

- iOS 13+ 或 macOS 11+
- Swift 5.9+

## 安裝

使用 Swift Package Manager。在 `Package.swift` 中：

```swift
dependencies: [
    .package(url: "https://github.com/nothingsh/DeclarativeCombine.git", from: "0.1.0")
]
```

或在 Xcode 中選擇 File → Add Package Dependencies，輸入 `https://github.com/nothingsh/DeclarativeCombine`。

本套件不依賴 DeclarativeUIKit 或 DeclarativeAppKit。和其中任何一個一起加入即可搭配使用，也可以單獨用在任何 UIKit 或 AppKit 程式碼裡。

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

要顯示或隱藏視圖，繫結 `isHidden`。stack view 會收合隱藏的子視圖：

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

在同一個 subject 上同時 bind 和 send，就是雙向繫結：

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
| `UITextField` | `returnPublisher` | `Void`，按下 return 鍵時 |
| `UITextView` | `textPublisher` | `String`，使用者編輯文字時 |
| `UISwitch` | `isOnPublisher` | `Bool`，`.valueChanged` 時 |
| `UISlider` | `valuePublisher` | `Float`，`.valueChanged` 時 |
| `UIStepper` | `valuePublisher` | `Double`，`.valueChanged` 時 |
| `UISegmentedControl` | `selectedSegmentIndexPublisher` | `Int`，`.valueChanged` 時 |
| `UIDatePicker` | `datePublisher` | `Date`，`.valueChanged` 時 |
| `UIPageControl` | `currentPagePublisher` | `Int`，`.valueChanged` 時 |
| `UIRefreshControl` | `refreshPublisher` | `Void`，使用者下拉重新整理時 |
| `UIScrollView` | `contentOffsetPublisher` | `CGPoint`，每次位移量變化時 |
| `UIScrollView` | `contentSizePublisher` | `CGSize`，每次內容尺寸變化時 |
| `UIView` | `tapGesturePublisher` | `UITapGestureRecognizer`，每次點按時 |
| `UIView` | `longPressGesturePublisher` | `UILongPressGestureRecognizer`，每次狀態變化時 |
| `UIView` | `gesturePublisher(_:)` | 你傳入的辨識器，每次它送出 action 時 |

它們可以脫離繫結 modifier 單獨使用：

```swift
button.tapPublisher
    .sink { print("tapped") }
    .store(in: &cancellables)
```

控制項的 publisher 只在使用者互動時發出：訂閱時不發出，用程式碼指派時也不發出。scroll view 的 publisher 在每次變化時發出，包括程式碼造成的變化，訂閱時同樣不發出。所有 publisher 都不會讓視圖無法釋放，也都不會結束。

`returnPublisher` 使用 `.editingDidEndOnExit`，這個事件有 target 時 UIKit 會收起鍵盤。

搜尋列的文字欄位是 `UITextField`，所以 `searchBar.searchTextField.textPublisher` 可以直接用。

#### 手勢

訂閱手勢 publisher 會替視圖加入一個辨識器，取消訂閱時移除：

```swift
UIImageView(image: photo)
    .isUserInteractionEnabled(true)
    .sink(\.tapGesturePublisher) { [weak self] _ in self?.showPhoto() }

UIView()
    .sink({ $0.gesturePublisher(UIPanGestureRecognizer()) }) { [weak self] pan in
        self?.drag(by: pan.translation(in: pan.view))
    }
```

`UILabel` 和 `UIImageView` 在 `isUserInteractionEnabled` 為 `true` 之前不回應觸控。連續手勢在每次狀態變化時都發出，用 `state` 區分。

### AppKit

在 macOS 上繫結 modifier 完全相同，publisher 依 AppKit 自己的屬性命名：

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

| 視圖 | Publisher | 發出 |
|---|---|---|
| `NSControl` | `actionPublisher` | `Void`，控制項每次送出 action 時 |
| `NSButton` | `clickPublisher` | `Void`，每次點按時 |
| `NSButton` | `statePublisher` | `NSControl.StateValue`，每次點按之後 |
| `NSSwitch` | `statePublisher` | `NSControl.StateValue`，使用者切換開關時 |
| `NSSlider` | `doubleValuePublisher` | `Double`，使用者拖移時 |
| `NSStepper` | `doubleValuePublisher` | `Double`，每次步進時 |
| `NSSegmentedControl` | `selectedSegmentPublisher` | `Int`，使用者選擇分段時 |
| `NSDatePicker` | `dateValuePublisher` | `Date`，使用者修改日期時 |
| `NSPopUpButton` | `indexOfSelectedItemPublisher` | `Int`，使用者選擇項目時 |
| `NSTextField` | `stringValuePublisher` | `String`，使用者編輯文字時 |
| `NSTextField` | `returnPublisher` | `Void`，按 return 鍵結束編輯時 |
| `NSTextView` | `stringPublisher` | `String`，使用者編輯文字時 |
| `NSScrollView` | `documentVisibleRectPublisher` | `CGRect`，每次文件的可見部分變化時 |
| `NSScrollView` | `documentSizePublisher` | `CGSize`，每次 document view 的尺寸變化時 |
| `NSView` | `clickGesturePublisher` | `NSClickGestureRecognizer`，每次點按時 |
| `NSView` | `pressGesturePublisher` | `NSPressGestureRecognizer`，每次狀態變化時 |
| `NSView` | `gesturePublisher(_:)` | 你傳入的辨識器，每次它送出 action 時 |

規則與 iOS 上相同：控制項和文字的 publisher 只在使用者互動時發出，scroll view 的 publisher 在每次變化時發出，訂閱時都不發出。

`NSControl` 只有一個 target 和一個 action，控制項的 publisher 會接管它們。不要替你訂閱的控制項設定 `target` 或 `action`。同一個控制項可以有任意多個訂閱。`NSTextField` 的兩個 publisher 是例外：它們監聽通知，所以文字欄位自己的 action 照常運作。

控制項何時送出 action 仍由 AppKit 決定。連續模式的 `NSSlider` 在拖移過程中持續發出，`sendAction(on:)` 會改變按鈕發出的時機。

`documentVisibleRectPublisher` 的 origin 是捲動位置，使用 document view 的座標系。document view 是 flipped 時 `y` 向下增大，DeclarativeAppKit 的 `VScroll` 和 `HScroll` 的內容就是這樣。可見區域的大小改變時這個矩形也會變化。

手勢辨識器同樣只有一個 target，所以每個辨識器只傳給一個訂閱。

## 規則

- **弱參考 `self`。** 視圖在存活期間一直持有你的閉包，也包括你繫結的 publisher 裡的閉包，例如 `map { self.format($0) }`。閉包強參考視圖控制器會造成循環參考。
- **publisher 不能失敗。** 只接受 `Failure == Never`。繫結前先處理錯誤，例如用 `replaceError(with:)`。
- **在主執行緒發出。** 值在 publisher 發出的地方同步套用，函式庫不會替你切到主執行緒。在背景發出的 publisher 要加 `receive(on: DispatchQueue.main)`。
- **每個值都會被指派。** 加 `removeDuplicates()` 可以略過沒有變化的值。
- **使用傳給閉包的值。** `@Published` 在屬性改變之前發出，在 `onReceive` 裡讀這個屬性得到的是舊值。
- **同一個屬性繫結兩次，兩個訂閱都會保留。** 以最新的值為準。
- **在 macOS 上，控制項的 publisher 佔用控制項的 target 和 action。** 不要更動你訂閱的控制項的這兩個屬性。兩個都換掉，publisher 就不再發出，直到這個控制項再次被訂閱。只換掉其中一個，控制項的 target 就不再實作它的 action，控制項觸發時 AppKit 會拋出例外。

## 範例 App

`Example/Example.xcodeproj` 是一個小型 iOS App，以本機套件的方式使用本套件，並從 GitHub 引入 DeclarativeUIKit。用 Xcode 開啟，選擇 `Example` scheme 和一個 iOS 模擬器即可執行。下面的程式碼片段摘自它的三個畫面。

### Form

這就是 DeclarativeUIKit 範例 App 裡的那個表單。在那邊，視圖控制器把八個視圖存成屬性，加入了四個 target，還需要三個 `@objc` 方法和一個文字欄位委派。在這裡這些都不需要，因為每個控制項都在宣告它的地方繫結。view model 是純 Combine，對視圖一無所知。在 name 文字欄位裡按 return，會透過 `nameReturned` 這個 subject 傳到 email 文字欄位，兩個文字欄位互不參考。

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
<img src="docs/images/example-form.png" width="300" alt="表單畫面">
</td>
</tr>
</table>

### Scrolling header

scroll view 把位移量送給 `offset`，這是視圖控制器持有的一個 subject，標頭再從它讀回來：頁面上滑時標頭淡出。標頭和 scroll view 互不參考。愛心是一個帶點按手勢的 image view，下拉重新整理在 model 發布新時間時結束。

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
<img src="docs/images/example-scroll.png" width="300" alt="捲動標頭畫面">
</td>
</tr>
</table>

### Controls

分段控制項把選取的區塊寫入 model，每個區塊把 `isHidden` 繫結到它。stack view 會收合隱藏區塊留下的空隙，所以沒有視圖被加入或移除。長按在每次狀態變化時都發出，所以重設時只取長按開始的那一次。

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
<img src="docs/images/example-controls.png" width="300" alt="控制項畫面">
</td>
</tr>
</table>

## 已知限制

- 內容閉包仍然只執行一次。繫結更新的是屬性，不會新增、移除或重排視圖。
- 繫結在視圖釋放之前無法移除，所以不要在每次設定可重用 cell 時重新繫結。
- 沒有委派回呼的 publisher，例如選取表格的一列。請自己設定委派。
- 在 macOS 上，從 `NSComboBox` 的下拉清單裡選擇項目不會讓 `stringValuePublisher` 發出，只有鍵入才會。
- 在 macOS 上，`documentVisibleRectPublisher` 使用 document view 自己的座標系，所以除非 document view 是 flipped，否則 `origin.y` 向上增大。
- 範例 App 只有 iOS 版。

## 授權

MIT。見 [LICENSE](LICENSE)。
