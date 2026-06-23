# Furigana 讀音修正功能 — 進度與待辦

更新日: 2026-06-10

## 功能總覽

解決 Yahoo Furigana API 偶爾標錯讀音的問題（例：「海馬」被標成 `とど`，正確應為 `かいば`）。

採用三層覆蓋策略，優先序由高到低：

| 優先序 | 來源 | 行為 |
|---|---|---|
| 1 | **使用者修正**（`UserFuriganaOverride`） | 使用者在 sheet 明確選擇的讀音，最優先 |
| 2 | **JMdict 單義詞** | 字典只有一個候選 → 安全自動覆蓋 |
| 3 | **Yahoo 原值** | 多義詞或字典未命中 → 保留，等使用者點選 |

**關鍵設計**：使用者修正以 **per-text（contextHash）** 為範圍——同一首歌詞內把「愛」改成 `かなしい` 只影響這段文字，不會污染其他筆記的「愛＝あい」。

---

## 資料流

```
FuriganaText(text:)
  │  .task → fetchRawReadings(Yahoo) → applyOverrides → 渲染
  │  @Query(contextHash) 監聽使用者修正
  ▼
點擊漢字 token → KanjiActionSheet（半屏）
  │  顯示漢字 / 讀音 / 朗讀（唸平假名，避開漢字多義誤讀）
  │  修正讀音 → 候選 picker + 自訂輸入 → 寫入 UserFuriganaOverride
  ▼
SwiftData 變動 → @Query → overrideSignature 變動
  ▼
FuriganaText.reapply（不重打 Yahoo）→ 畫面即時更新
```

---

## 已完成 ✅

| # | 項目 | 檔案 |
|---|---|---|
| 1 | JMdict/JMnedict 字典載入服務（背景解析、缺檔降級、多義候選） | `Services/Furigana/FuriganaOverrideDictionary.swift` |
| 2 | UseCase 三層覆蓋邏輯（fetchRaw / applyOverrides / candidates） | `UseCases/Furigana/FuriganaUseCase.swift` |
| 3 | 使用者修正 Model（per-text 複合鍵 contextHash + surface） | `Models/UserFuriganaOverride.swift` |
| 4 | 文字 hash 工具（SHA256） | `Services/Furigana/StringHashing.swift` |
| 5 | 漢字操作 sheet（朗讀 / 修正讀音 / 自訂輸入 / 即時反映） | `Views/Common/KanjiActionSheet.swift` |
| 6 | 漢字 token 可點擊（onKanjiTap callback） | `Views/Common/FuriganaTextView.swift` |
| 7 | FuriganaText 整合 @Query + sheet present + reapply | `Views/Common/FuriganaText.swift` |
| 8 | DI 注入 + Schema 註冊 | `Services/APIConfig.swift`, `kotobase_iOSApp.swift` |
| 9 | 測試頁改用 FuriganaText（除錯 tab 可實測完整流程） | `Views/Debug/APITestView.swift`, `ContentView.swift` |
| 10 | 字典資料（JmdictFurigana 12MB / JmnedictFurigana 28MB） | `Resources/*.txt` |
| 11 | Swift 6 concurrency 修正（nonisolated / Task 取代 Timer） | `FuriganaOverrideDictionary.swift`, `AudioPlayerEngine.swift` |
| 12 | 朗讀狀態改綁 @Observable（移除 polling 反模式） | `KanjiActionSheet.swift` |

---

## 待辦 ⬜

### 🔴 上架前必修

| # | 項目 | 原因 | 對應檔案 |
|---|---|---|---|
| A1 | `save()` 直接操作 SwiftData → 抽 `UserFuriganaOverrideUseCase` | 違反「View 不直接讀寫 SwiftData」架構規則 | `KanjiActionSheet.swift:261` |
| A2 | 自訂讀音 input validation（限平假名/片假名/長音符、長度上限） | 目前可輸入英數/emoji/超長字串，會污染資料 + 撐歪 UI | `KanjiActionSheet.swift:187` |
| A3 | SwiftData `VersionedSchema` + `SchemaMigrationPlan` | schema 已改過，App ship 後升級會 migration crash | `kotobase_iOSApp.swift` |
| A4 | `UserFuriganaOverride` 接入 `CloudSyncUseCase` | 換機/重裝後修正會全部消失 | `UseCases/CloudSync/` |

### 🟡 品質改善（觀察後再決定）

| # | 項目 | 說明 |
|---|---|---|
| B1 | 字典預編譯（binary plist / SQLite） | 目前純文字解析首次載入 1-3 秒、heap ~40-60MB；首次標注會延遲 |
| B2 | upsert dedupe（清理邏輯重複紀錄） | `existing.first` 假設只有一筆，若曾有 bug 殘留多筆不會清 |
| B3 | error 訊息包裝 | `error.localizedDescription` 可能洩漏 internal API path |
| B4 | `actionRow` 抽到 `Views/Common/` | B-2 漢字收藏 sheet 若重用相同 row 再抽 |

### 🔵 未來功能（Phase B-2，待 UI 設計稿）

| # | 項目 | 說明 |
|---|---|---|
| C1 | `SavedKanji` Model + UseCase | 漢字收藏資料層 |
| C2 | 漢字收藏 Tab（list / 搜尋 / CRUD） | 新頁籤 |
| C3 | sheet 加「加入詞庫」按鈕 | 收藏入口（HelloTalk 風） |
| C4 | 「還原為預設讀音」按鈕 | 刪除自己的修正、回到字典/Yahoo |
| C5 | 跨筆記預設讀音（修正 N 次後詢問設為全域預設，僅影響新筆記） | 減少重複修正 |

---

## Commit 前確認清單

- [ ] Xcode `BuildProject` 通過（SourceKit 紅字非真錯，以實機 build 為準）
- [ ] simulator **刪除 App 重裝**（schema 改過，舊資料需清）
- [ ] `Resources/JmdictFurigana.txt`、`JmnedictFurigana.txt` 的 Target Membership 勾選 `kotobase-iOS`
- [ ] 新增 `.swift` 檔的 Target Membership 確認
- [ ] 除錯 tab → 產生 Furigana → 點「海馬」→ 改 `かいば` → 確認該段即時變更、朗讀唸新讀音
- [ ] console 確認 `[FuriganaOverrideDictionary] 載入 ...` 與 `[Furigana ambiguous] 海馬 ...` log
