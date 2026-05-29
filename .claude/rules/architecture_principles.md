# 架構設計原則

開始實作前、做設計判斷時參照此文件。

---

## 分層

本專案採用 **View / ViewModel / UseCase / Repository(Service) / Model+DTO** 五層架構。

```
┌─────────────────────────────────────────────────────────────┐
│ View（SwiftUI）                                              │
│  - 純描繪、@State / @Binding、UI 事件 → 呼叫 ViewModel        │
├─────────────────────────────────────────────────────────────┤
│ ViewModel（@Observable 可選）                                 │
│  - 表單狀態、UI 分支用 enum、組合 UseCase 結果                  │
├─────────────────────────────────────────────────────────────┤
│ UseCase                                                       │
│  - 業務邏輯、組合多個 Repository / Service                     │
│  - 不知道 SwiftData / Firestore 細節（只依賴 Protocol）         │
├─────────────────────────────────────────────────────────────┤
│ Repository / Service                                           │
│  - 對外資料存取（SwiftData ModelContext、Firestore、TTS API）  │
│  - 一律以 Protocol 對外暴露，方便注入測試替身                   │
├─────────────────────────────────────────────────────────────┤
│ Model（SwiftData @Model）+ DTO（Firestore 邊界）              │
└─────────────────────────────────────────────────────────────┘
```

---

## 各層職責

### View
- 純描繪、UI 事件
- **不**直接讀寫 SwiftData / Firestore / 網路
- 可以擁有純 UI 的 `@State`（表單輸入文字、開關狀態）
- 業務狀態交給 ViewModel 或直接呼叫 UseCase

### ViewModel
- 集中 UI 狀態 / 表單狀態
- 將多個 UseCase 結果合成單一 enum / struct 讓 View 用 `switch` 描繪
- 不直接呼叫 Firestore / SwiftData API，只依賴 UseCase
- 視畫面複雜度，**簡單畫面可省略**，View 直接用 UseCase

### UseCase
- 業務邏輯（例：合併本機與雲端筆記、驗證資料、組裝 OCR 流程）
- 透過 Protocol 注入 Repository / Service
- Stateless 為主（`struct` + factory）
- 不持有 UI 狀態

### Repository / Service
- 對外資料 I/O 的單一入口
- 一律以 Protocol 對外暴露
- 在 [APIConfig.swift](../../kotobase-iOS/Services/APIConfig.swift) 集中注入點

### Model / DTO
- `@Model class`：SwiftData 本機儲存
- `struct DTO`：Firestore / API 邊界，與 Model 互轉
- 不混用：Model 不放 Firestore 字典轉換邏輯，DTO 不依賴 SwiftData

---

## 判斷邏輯集中在 ViewModel / Presenter

View 不得在內部組合多個 boolean / state 推導分支結果。

```swift
// ❌ View 內組合判斷邏輯
let hasSelected = !selectedSubcategoryIds.isEmpty
let hasCategory = selectedCategoryId != nil
if hasCategory && hasSelected {
    showFullPath()
} else if hasCategory {
    showCategoryOnly()
}

// ✅ ViewModel 提供結果型別
enum CategoryDisplayMode {
    case empty
    case categoryOnly(String)
    case categoryWithSubs(String, [String])
}

switch viewModel.categoryDisplay {
case .empty:                        Text("未選擇")
case .categoryOnly(let label):      Text(label)
case .categoryWithSubs(let c, let s): Text(c + " / " + s.joined(separator: ", "))
}
```

---

## 元件間通訊方式

| 方式 | 應用情境 | 不應使用 |
|------|---------|---------|
| **Closure** | 非同步 callback、SwiftUI View 內回傳事件 | 長期持有（retain cycle 風險） |
| **Delegate** | UIKit 包裝（如 `UIImagePickerControllerDelegate`） | SwiftUI 內部，用 Closure |
| **Combine / async/await** | 資料流 / 非同步序列 | 簡單 1-shot 回傳，用 closure |
| **NotificationCenter** | 全 App 廣播（登出、設定變更） | 1 對 1 通訊 |
| **@Environment / @EnvironmentObject** | 跨層級共享狀態（ModelContext、ColorScheme） | 父子直接傳值，用參數 |

---

## 依賴注入

[APIConfig.swift](../../kotobase-iOS/Services/APIConfig.swift) 是依賴注入入口。
所有 Service / UseCase 由它組裝，View 從這裡取 instance 或用 factory。

```swift
// ✅ 從 APIConfig 取
let useCase = APIConfig.makeWordUseCase(context: modelContext)

// ❌ View 內直接 new Service
let service = FirestoreService.shared  // 違反，View 不該知道有 Firestore
```

測試時可替換為 Mock 實作（Protocol 注入）。

---

## 不重造輪子

實作前先檢查：

1. `Views/Common/` — 有沒有現成 UI 元件可用（FieldSection、BorderedTextEditor、CenteredOverlay、FlowLayout 等）
2. `Services/` — 有沒有現成 Service 可用（TTSAPIService、AudioCacheService 等）
3. `UseCases/` — 有沒有現成 UseCase 可用（WordUseCase、CategoryUseCase、CloudSyncUseCase 等）

若有 70% 以上相符的舊元件，**優先擴充舊元件**而非新建。
若新建，命名要明確區別，並在 PR 描述為何不能用舊的。

---

## 資料夾結構

```
kotobase-iOS/
├── Models/
│   ├── *.swift          # @Model（SwiftData）
│   └── DTOs/            # Firestore / API 邊界
├── Services/
│   ├── Auth/
│   ├── Firestore/
│   ├── Furigana/
│   ├── TTS/
│   ├── Audio/
│   └── APIConfig.swift  # 依賴注入入口
├── UseCases/
│   ├── Word/
│   ├── Category/
│   ├── CloudSync/
│   ├── Furigana/
│   └── TTS/
├── ViewModels/          # （需要時建立）
└── Views/
    ├── Common/          # 共用 UI 元件
    ├── Word/
    ├── Category/
    ├── Debug/
    └── ContentView.swift
```

新檔案請放對應資料夾。Xcode 已啟用 file system synchronized group，丟進去會自動加進 target。
