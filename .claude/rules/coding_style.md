# Swift / SwiftUI 程式碼風格規範

本專案撰寫 Swift / SwiftUI 時必須遵守的規則。

---

## 語言

- 註解一律 **繁體中文**
- 字面 UI 文字盡量走 Localizable.xcstrings（多語系）
- 變數 / 函式 / 型別命名仍用英文

---

## switch / if-else

- enum 分支必須用 `switch`，禁止 `if-else if` 鏈
- `switch` 禁止 `default`，必須明示所有 case
- 使用 `default` 會導致未來新增 case 時編譯器不發出警告

```swift
// ✅ 明示所有 case
switch responseCode {
case .success:    handleSuccess()
case .needOAuth:  handleOAuth()
case .error:      handleError()
}

// ❌ default 禁止
switch responseCode {
case .success: handleSuccess()
default:       handleError()
}
```

---

## 禁止 Force Unwrap（`!`）

禁止 `!` 強制解包，這是 crash 最直接的來源。
必須用 `guard let` 或 `if let`，並明確處理 nil。

```swift
// ✅
guard let url = URL(string: urlString) else { return }
loadURL(url)

// ❌
let url = URL(string: urlString)!
loadURL(url)
```

例外：`@IBOutlet`（本專案 SwiftUI 不使用）、單元測試、伴隨 `fatalError` 的初始化（需註解說明）

---

## 使用 guard 提前返回

條件不滿足時用 `guard` 提前返回，減少巢狀。
`if` 巢狀超過 2 層時優先改 `guard`。

---

## Closure 與 `[weak self]`

捕捉 `self` 的 `class` closure 原則上必須用 `[weak self]`。
**注意：`struct`（包含 SwiftUI View）為值型別，不需要 `[weak self]`**。

```swift
// ✅ class 內捕捉 self 用 [weak self]
networkService.fetch { [weak self] result in
    guard let self else { return }
    self.handleResult(result)
}

// ✅ SwiftUI View（struct）不需要 [weak self]
Button("Save") {
    save()  // self 是值型別，沒有 retain cycle 風險
}
```

`[weak self]` 解包必須用 `guard let self else { return }`，禁止 `self?.foo` 連續鏈式。

---

## class 與 struct 的選用

不確定時選 `struct`。只有明確需要 `class` 的理由時才用。

| 型別 | 使用條件 |
|---|---|
| `struct` | SwiftUI View / UseCase / DTO / Validator / Service 預設 |
| `class` | 需要繼承（NSObject、UIKit 包裝）／需要 `weak` 參照／`@Observable` ViewModel／Singleton |
| `actor` | 需要 thread-safe 的可變狀態 |

---

## final

不打算被繼承的 `class` 必須加 `final`。`struct` / `enum` / `protocol` 不需要。

```swift
// ✅
final class FirebaseAuthService: NSObject { ... }

// ❌
class CategoryUseCase { ... }
```

---

## 存取修飾子

- 預設不寫修飾子（`internal`）
- 明確寫 `internal` 是冗餘的，禁止
- `private` / `fileprivate` 用於限定 scope
- `public` 在 app target 內幾乎用不到（沒有 module 邊界）

```swift
// ✅
struct AddNoteView: View { ... }
private func save() { ... }

// ❌
internal struct AddNoteView: View { ... }
```

---

## DocC 註解

- 型別 / 方法定義的正上方用 `///`
- 方法內的行內註解用 `//`（禁止方法內用 `///`）
- `// MARK:` / `// TODO:` / `// NOTE:` 用 `//`

參數註解：
- 參數 **1 個** → `- Parameter xxx:`
- 參數 **多個** → `- Parameters:` + 縮排 `- xxx:`

```swift
// ✅
/// 判斷資料型別
/// - Parameter data: 判定對象的資料字串
/// - Returns: 判定後的資料型別
func determineDataType(data: String) -> Result<SharedDataType, SharedDataError>

// ✅ 方法內
func fetchChatList() {
    // 新搜尋時重置既有資料
    self.chats.removeAll()
}

// ❌ 方法內禁止 ///
func fetchChatList() {
    /// 新搜尋時重置
    self.chats.removeAll()
}
```

---

## SwiftUI 特有規則

### View body 過大時切分

View body 超過 ~60 行就切成 computed property 或子 View。

```swift
// ✅ 切成小區塊
var body: some View {
    VStack {
        header
        formSection
        footer
    }
}
private var header: some View { ... }
private var formSection: some View { ... }
```

### State 集中

`@State` / `@Binding` / `@Environment` 等屬性集中在 View 頂部，分區用 `// MARK:`。

### 共用元件抽到 `Views/Common/`

按鈕樣式、輸入框、彈窗框架等橫跨多畫面的元件，抽到 `Views/Common/`。
**不重造輪子**：在新建 View 元件前，先 grep 看 Common/ 有沒有現成的。

---

## Protocol 設計

- 所有實作型別回傳相同型別時，**不用** `associatedtype`
- 不要在 `extension` 提供空的 default 實作（implementer 漏實作會無警告）
- 加新方法時，先檢查該 class 是否經由 protocol 被引用，若是要同步更新 protocol

---

## UI 更新必須在 Main Thread

SwiftUI 的 `@State` / `@Published` 更新必須在 main actor 上。

```swift
// ✅
Task { @MainActor in
    self.items = await fetch()
}

// ✅ 用 await MainActor.run
let items = await fetch()
await MainActor.run { self.items = items }

// ❌ 背景執行緒直接寫 State
Task.detached {
    self.items = await fetch()  // 違反
}
```

---

## import 管理

- 刪除未使用的 `import`
- 必要的 `import`（如 `Foundation`、`SwiftUI`、`SwiftData`）明確記載
- 檔案開頭不加多餘空行
- import 順序：標準 library → 第三方 → 本專案
