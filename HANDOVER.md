# Handover Note
更新日時: 2026-06-10 17:13

## 今回やったこと

Yahoo Furigana API の誤標注問題（例：「海馬」が `かいば` ではなく `とど` と標注される）への対策を実装。

**背景の課題**：Yahoo API は任意の日本語文を tokenize + 読み付与してくれるが、多義語の読みを間違えることがある。

**実装した解決策（Phase A + Phase B-1）**：

### Phase A — JMdict 字典覆蓋層
- 新規 `Services/Furigana/FuriganaOverrideDictionary.swift`
  - JMdict/JMnedict の辞書ファイルを background で load（`Task.detached(.utility)`）
  - `candidates(for:)` で surface → 候選読み配列を返す（多義語は複数返す）
  - 辞書ファイル欠損時は自動降級（純 Yahoo）
- `UseCases/Furigana/FuriganaUseCase.swift` 改造
  - `fetchRawReadings` / `applyOverrides` / `candidates` に分割
  - 覆蓋優先序：**User override > JMdict 単義語 > Yahoo**
  - 単義語（候補1個）→ 自動覆蓋、多義語（候補2個以上）→ Yahoo 保留 + DEBUG log

### Phase B-1 — ユーザー手動修正 + 漢字操作 Sheet
- 新規 `Models/UserFuriganaOverride.swift`（`@Model`）
  - 論理複合キー `(contextHash, surface)` — **per-text スコープ**（同じ文章内でのみ修正が効く）
- 新規 `Services/Furigana/StringHashing.swift` — `String.sha256Hex`（CryptoKit）
- 新規 `Views/Common/KanjiActionSheet.swift` — 半屏 sheet
  - 漢字 / 読み表示 / 朗読ボタン（**読み＝平假名で TTS**、漢字だと多義で誤読するため）/ 読み修正（候補 picker + 自訂入力）
- `Views/Common/FuriganaTextView.swift` — 漢字 token に `onKanjiTap` callback 追加
- `Views/Common/FuriganaText.swift` — `@Query` で contextHash 単位の override を監視、tap → sheet present、override 変動時は Yahoo 再呼び出しせず reapply のみ
- `Services/APIConfig.swift` — `furiganaOverrideDictionary` DI 追加
- `kotobase_iOSApp.swift` — Schema に `UserFuriganaOverride` 登録

### 辞書データ配置
- `kotobase-iOS/Resources/JmdictFurigana.txt`（12MB / 234,024 行）— 一般語彙
- `kotobase-iOS/Resources/JmnedictFurigana.txt`（28MB）— 人名地名専名（ユーザーは旅行記録等で地名・駅名も記憶したいため保持を希望）

## 決定事項

- **修正のスコープは per-text（contextHash 単位）**。全 app 一括変更はしない。
  - 理由：歌詞で「愛」を `かなしい` と読ませる等、同じ漢字でも文脈で読みが異なるケースがあり、全置換すると他のノートが壊れる。
- **朗読対象は平假名（読み）であって漢字ではない**。多義語の場合 AI/TTS は漢字を見ても誤読するため。
- **JMdict 単義語のみ自動覆蓋**。多義語は Yahoo を保留しユーザーの手動選択に委ねる（字典には文脈がないので「正しい読みを別の誤読に書き換える」リスクを回避）。
- 辞書は JmdictFurigana + JmnedictFurigana の**両方**を load。
- Phase B-2（漢字収藏 + 新規 Tab での CRUD）は**未着手**。UI デザイン稿が無いため後回しと合意。

## 捨てた選択肢と理由

- **Yahoo を別 API に置換**：却下。tokenize + 読み付与の一体型サービスは貴重で、置換は大工事。
- **Yahoo + Google AI 修正レイヤー**：却下。AI が「どれが誤りか」を知るには全件再チェックが必要 = 実質「AI 直接利用」で二重コスト。
- **JmdictFurigana を Yahoo の代替にする**：却下。これは静的辞書データのみで tokenize 機能が無い。Yahoo の後段 override 層としてのみ価値が出る。
- **修正を surface 単位で全 app グローバルに記憶**：却下（上記「決定事項」の per-text 理由）。
- **`FuriganaReading` を直接 `Identifiable` 拡張**：却下。DTO が UI 境界に染まるため、private `TappedKanji` wrapper に変更。

## ハマりどころ

- **ユーザーが最初 JMnedict（人名地名）を誤ダウンロード**。`JmdictFurigana`（一般語）と `JmnedictFurigana`（専名）の n の有無に注意。一般語「食べる」「記憶」等は JMnedict に入らない。
- **「海馬」は JMdict 内に5読み**（せいうち/とど/あしか/かいば/うみうま）の多義語で、字典の最大の罠。「第一筆を採用」だと `せいうち` になりやはり誤り → 単義語のみ自動覆蓋の設計に至った。
- SourceKit の偽警告（`Cannot find type 'FuriganaReading' in scope` 等）が多発するが、`.claude/rules/sourcekit_diagnostics.md` の通り iOS-only target の cross-module 解析失敗で実機 build には無関係。**無視可**。

## 学び

- 既存コードベースの分層：View / ViewModel / UseCase / Repository(Service) / Model+DTO。DI 入口は `Services/APIConfig.swift`。
- **View は SwiftData / Firestore を直接触ってはいけない**（`architecture_principles.md` 明文）。→ 現状 `KanjiActionSheet` がこれに違反中（下記レビュー #1）。
- `AudioPlayerEngine`（`Services/Audio/`）は `@Observable` で `isPlaying` 等を公開済み。delegate が再生終了時に自動で `isPlaying = false` にする。
- TTS は `APIConfig.ttsUseCase.synthesizeWord(text:)` で base64 取得 → `AudioPlayerEngine.load(data:)` → `play()`。
- file system synchronized group 有効なので、フォルダに置けば自動で target に追加される（要 Target Membership 確認）。
- SwiftData schema 変更後は simulator の app 削除→再インストールが必要。

## 次にやること

**コードレビューで指摘した修正（優先順）**：

1. **【必修 #1】** `KanjiActionSheet.save(reading:)` 内の直接 SwiftData 操作を `UserFuriganaOverrideUseCase`（新規）に抽出。`WordUseCase` / `CategoryUseCase` と同様 `APIConfig` に factory 追加（`make...(context:)`）。違反箇所：`KanjiActionSheet.swift:226-247` 付近。
2. **【必修 #2】** `KanjiActionSheet` の `@State isPlaying` + polling（`while audioPlayer.isPlaying { sleep }`、`KanjiActionSheet.swift:198-201`）を削除。`audioPlayer.isPlaying` を直接 binding（`@Observable` に任せる）。二重 source-of-truth 解消。
3. **【検証後 #3】** 自訂読み入力に validation 追加（平假名/片假名/長音符のみ、30文字以内）。`KanjiActionSheet.swift:128` の TextField。
4. **【検証後 #7】** upsert の論理重複クリーンアップ（`existing.dropFirst().forEach { delete }`）。
5. **【上架前 #4】** `VersionedSchema` + `SchemaMigrationPlan` を実装（schema 変更済みのため）。
6. **【上架前 #5】** `UserFuriganaOverride` を `CloudSyncUseCase` に接続（機種変更で修正が消えないように）。他 Model の Firestore 同期方法を `CloudSyncUseCase` で確認。
7. **【観察後 #6】** 辞書（40-60MB heap, load 1-3秒）を binary plist / SQLite にプリコンパイルして load 高速化（実測で体感したら）。

**動作確認（未実施）**：
- simulator で app 削除→再インストール（schema 変更のため）。
- 「海馬」を含む文を表示 → 漢字 tap → sheet で候補から `かいば` 選択 → その文章内のみ反映、他ノートは不変、を確認。
- console で `[FuriganaOverrideDictionary] 載入 ...` と `[Furigana ambiguous] 海馬 ...` log を確認。
- **Resources/ の2つの .txt と新規 .swift の Target Membership（kotobase-iOS）を Xcode で確認**。

**Phase B-2（後日、UI デザイン確定後）**：
- `SavedKanji` Model + `SavedKanjiUseCase` + 新規 Tab「漢字収藏」（list / 検索 / CRUD）。
- `KanjiActionSheet` に「漢字を収藏」ボタン追加（HelloTalk 風）。

## 関連ファイル

**新規作成**：
- `kotobase-iOS/Models/UserFuriganaOverride.swift`
- `kotobase-iOS/Services/Furigana/FuriganaOverrideDictionary.swift`
- `kotobase-iOS/Services/Furigana/StringHashing.swift`
- `kotobase-iOS/Views/Common/KanjiActionSheet.swift`

**変更**：
- `kotobase-iOS/UseCases/Furigana/FuriganaUseCase.swift`
- `kotobase-iOS/Views/Common/FuriganaText.swift`
- `kotobase-iOS/Views/Common/FuriganaTextView.swift`
- `kotobase-iOS/Services/APIConfig.swift`
- `kotobase-iOS/kotobase_iOSApp.swift`

**辞書データ（要 Target Membership 確認）**：
- `kotobase-iOS/Resources/JmdictFurigana.txt`
- `kotobase-iOS/Resources/JmnedictFurigana.txt`

**調査のみ（未変更）**：
- `kotobase-iOS/Services/Furigana/FuriganaAPIService.swift`
- `kotobase-iOS/Services/Audio/AudioPlayerEngine.swift`
- `kotobase-iOS/UseCases/TTS/TTSUseCase.swift`
- `kotobase-iOS/Models/PaletteColor.swift`（@Model 参考）
- `kotobase-iOS/Views/Debug/APITestView.swift`（TTS 再生パターン参考）
