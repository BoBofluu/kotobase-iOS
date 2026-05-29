# SourceKit 假警告（無視可）

`<new-diagnostics>` 系統提醒中的 SourceKit 警告，部分屬於 SourceKit 解析器在跨 module / iOS-only target 環境下無法看到完整 module graph 而產生的假警告。
這類警告**不是實際編譯錯誤**，實機 build（Xcode IDE / `xcodebuild`）不會出現。

審查 / 修改程式碼時遇到下列模式可直接忽略，不需追查、不需調整、回答中也不必提及（除非使用者主動問）。

---

## 可忽略的警告模式

| 警告 | 原因 |
|------|------|
| `No such module 'UIKit'` | SourceKit 在 macOS 上下文中解析，UIKit 不存在 |
| `No such module 'Foundation'` | 同上 |
| `Cannot find type 'UIViewController' in scope` | UIKit 未載入導致連帶失敗 |
| `Cannot find 'CameraPicker' / 'AddNoteView' / 其他專案內部型別 in scope` | SourceKit index 尚未完成、或檔案間 cross-reference 解析失敗 |
| `Reference to member 'systemBackground' / 'systemGray4' / 'systemGroupedBackground' cannot be resolved without a contextual type` | UIColor / SwiftUI Color 在 macOS 上下文中不存在 |
| `Value of type 'Category' (aka 'OpaquePointer') has no member 'xxx'` | `@Model` 型別在 macOS SourceKit 中被誤判為 Foundation 的 OpaquePointer |
| `No exact matches in call to macro 'Query'` | SwiftData 的 `@Query` 在 macOS 上下文中無法解析 |
| `'navigationBarTitleDisplayMode' is unavailable in macOS` | iOS-only API，macOS 上下文不支援（本專案 iOS-only） |
| `Type 'ShapeStyle' / 'Color' has no member 'brandCyan'` 等自訂 extension | extension 檔尚未被 index 解析到 |

---

## 判定流程

1. `<new-diagnostics>` 出現警告時，先看是否屬上表模式
2. 屬於 → **直接忽略**
3. 不屬於 → 視為真實錯誤，照常處理

---

## 真實錯誤的判別

下列才是必須處理的：

- `error:` / `expected ...` / `'xxx' is unavailable`：語法・呼叫端錯誤
- `Use of unresolved identifier` 但**該識別符在當下變更檔案內定義**：拼寫錯誤、scope 錯誤
- `Cannot convert value of type 'A' to expected argument type 'B'`：型別不符
- `'xxx' has been renamed to 'yyy'`：API deprecation
- 編譯器（非 SourceKit）發出的錯誤

---

## 確認方式

不確定時，用 Xcode MCP 的 `BuildProject` 跑一次 build。能 build 過 = SourceKit 警告全是假的。
