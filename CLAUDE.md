# kotobase-iOS

個人專案：日文學習筆記 App（SwiftUI + SwiftData + Firebase）。

## 必讀規則

實作前先讀過：

- `.claude/rules/sourcekit_diagnostics.md` — SourceKit 假警告判別（避免追白工）
- `.claude/rules/coding_style.md` — Swift / SwiftUI 程式碼風格
- `.claude/rules/architecture_principles.md` — 分層、職責、不重造輪子

## 技術棧

- **UI**：SwiftUI（iOS 26+）
- **本機儲存**：SwiftData（`@Model` Category / Subcategory / Word）
- **雲端**：Firebase Auth（Google / Apple）+ Firestore
- **後端 API**：Cloud Functions（asia-east1）— TTS / Furigana
- **OCR**：Apple Vision（日 / 繁中 / 英）

## 註解語言

繁體中文。

## 分層

View / ViewModel(可選) / UseCase / Service(Repository) / Model+DTO — 詳見 architecture_principles.md。

依賴注入入口在 [kotobase-iOS/Services/APIConfig.swift](kotobase-iOS/Services/APIConfig.swift)。

## Build 驗證

改完關鍵程式碼後優先用 Xcode MCP 的 `BuildProject` 驗證，不要被 SourceKit 紅字騙到。
