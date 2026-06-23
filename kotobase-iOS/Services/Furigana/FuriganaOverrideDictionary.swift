import Foundation

/// JMdict 字典覆蓋查詢介面
/// - Note: 用於修正 Yahoo API 偶爾標錯的讀音
///   多義詞（同 surface 多讀音）由查詢方自行決定處理策略
protocol FuriganaOverrideDictionarying {
    /// 查詢指定表面形式對應的候選讀音
    /// - Parameter surface: 漢字表面形式（例：「海馬」「食べる」）
    /// - Returns: 候選讀音陣列；未命中或字典尚未載入時為空陣列
    ///   單一元素 → 單義詞，可安全覆蓋
    ///   多元素 → 多義詞，呼叫端應保留 Yahoo 原值並提供使用者選擇
    func candidates(for surface: String) async -> [String]
}

/// JMdict / JMnedict 字典覆蓋服務
/// - Note: 資料來源 https://github.com/Doublevil/JmdictFurigana
///   - `JmdictFurigana.txt`：一般詞彙（約 234k 筆）
///   - `JmnedictFurigana.txt`：人名地名專名（約 240k 筆）
///   兩檔皆需手動加入 Xcode target；缺檔時自動降級
///   格式：`surface|reading|segmentation` 每行一筆（例：`海馬|かいば|海[かい];馬[ば]`）
///   同 surface 多讀音時全部保留為候選清單
final class FuriganaOverrideDictionary: FuriganaOverrideDictionarying {

    // MARK: - Properties

    /// 載入任務（init 時啟動，背景解析）
    private let loadTask: Task<[String: [String]], Never>

    // MARK: - Init

    /// - Parameter resourceNames: bundle 內的資源檔名（不含副檔名）
    ///   預設同時載入 JmdictFurigana 與 JmnedictFurigana
    init(resourceNames: [String] = ["JmdictFurigana", "JmnedictFurigana"]) {
        self.loadTask = Task.detached(priority: .utility) {
            Self.loadDictionary(resourceNames: resourceNames)
        }
    }

    // MARK: - Actions

    /// 查詢候選讀音
    /// - Parameter surface: 漢字表面形式
    /// - Returns: 候選讀音陣列（按字典原始順序），未命中為空
    func candidates(for surface: String) async -> [String] {
        let dictionary = await loadTask.value
        return dictionary[surface] ?? []
    }

    // MARK: - Private

    /// 載入並解析字典檔
    /// - Parameter resourceNames: 要載入的資源檔名陣列
    /// - Returns: surface → [候選讀音] 對照表（資源全缺時為空）
    /// - Note: `nonisolated` — 純檔案解析無 actor state，可在 Task.detached 內呼叫
    private nonisolated static func loadDictionary(resourceNames: [String]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        result.reserveCapacity(400_000)

        for resourceName in resourceNames {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt") else {
                #if DEBUG
                print("[FuriganaOverrideDictionary] 資源檔 \(resourceName).txt 未找到，跳過")
                #endif
                continue
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                #if DEBUG
                print("[FuriganaOverrideDictionary] 讀取 \(resourceName).txt 失敗")
                #endif
                continue
            }

            var lineCount = 0
            content.enumerateLines { line, _ in
                let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
                guard parts.count >= 2 else { return }
                let surface = String(parts[0])
                let reading = String(parts[1])
                guard !surface.isEmpty, !reading.isEmpty else { return }
                lineCount += 1

                // 同 surface 的多筆讀音全部保留為候選，避免重複
                var readings = result[surface] ?? []
                guard !readings.contains(reading) else { return }
                readings.append(reading)
                result[surface] = readings
            }

            #if DEBUG
            print("[FuriganaOverrideDictionary] 載入 \(resourceName).txt：\(lineCount) 筆")
            #endif
        }

        #if DEBUG
        print("[FuriganaOverrideDictionary] 完成：\(result.count) 個 unique surface")
        #endif

        return result
    }
}
