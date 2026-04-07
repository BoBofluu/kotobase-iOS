import Foundation

/// 音訊快取服務
/// - Note: 對應 Web 版 audioCache.js，使用 FileManager 儲存音訊檔案，設定上限避免佔用過多空間
final class AudioCacheService {

    // MARK: - Singleton

    static let shared = AudioCacheService()

    /// 快取上限數量
    private let maxCacheCount = 500

    /// 快取目錄
    private let cacheDirectory: URL

    /// 快取索引檔路徑
    private let indexFilePath: URL

    /// 快取索引（key → metadata）
    private var cacheIndex: [String: CacheEntry] = [:]

    // MARK: - Init

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = caches.appendingPathComponent("AudioCache", isDirectory: true)
        self.indexFilePath = cacheDirectory.appendingPathComponent("index.json")

        // 建立快取目錄
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 載入索引
        loadIndex()
    }

    // MARK: - Actions

    /// 取得快取的音訊資料
    /// - Parameter key: 快取鍵（由文字 + 語音參數組合）
    /// - Returns: Base64 音訊資料，無快取則回傳 nil
    func get(key: String) -> String? {
        guard let entry = cacheIndex[key] else { return nil }

        let filePath = cacheDirectory.appendingPathComponent(entry.filename)
        guard let data = try? Data(contentsOf: filePath) else {
            // 檔案遺失，清除索引
            cacheIndex.removeValue(forKey: key)
            saveIndex()
            return nil
        }

        // 更新存取時間（LRU）
        cacheIndex[key]?.timestamp = Date().timeIntervalSince1970
        saveIndex()

        return data.base64EncodedString()
    }

    /// 儲存音訊至快取
    /// - Parameters:
    ///   - key: 快取鍵
    ///   - base64Audio: Base64 編碼的音訊資料
    func set(key: String, base64Audio: String) {
        guard let audioData = Data(base64Encoded: base64Audio) else { return }

        // 超過上限時淘汰最舊的
        if cacheIndex.count >= maxCacheCount {
            evictOldest()
        }

        let filename = UUID().uuidString + ".audio"
        let filePath = cacheDirectory.appendingPathComponent(filename)

        do {
            try audioData.write(to: filePath)
            cacheIndex[key] = CacheEntry(filename: filename, timestamp: Date().timeIntervalSince1970)
            saveIndex()
        } catch {
            // 寫入失敗時靜默處理
        }
    }

    /// 產生快取鍵
    /// - Parameters:
    ///   - text: 文字內容
    ///   - languageCode: 語言代碼
    ///   - voiceName: 語音名稱
    ///   - prompt: 提示詞
    /// - Returns: 組合後的鍵
    func makeKey(text: String, languageCode: String, voiceName: String, prompt: String = "") -> String {
        "\(text)|\(languageCode)|\(voiceName)|\(prompt)"
    }

    /// 清除所有快取
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cacheIndex.removeAll()
        saveIndex()
    }

    // MARK: - Private

    /// 淘汰最舊的快取項目
    private func evictOldest() {
        guard let oldest = cacheIndex.min(by: { $0.value.timestamp < $1.value.timestamp }) else {
            return
        }
        let filePath = cacheDirectory.appendingPathComponent(oldest.value.filename)
        try? FileManager.default.removeItem(at: filePath)
        cacheIndex.removeValue(forKey: oldest.key)
    }

    /// 載入快取索引
    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexFilePath),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
            return
        }
        cacheIndex = decoded
    }

    /// 儲存快取索引
    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(cacheIndex) else { return }
        try? data.write(to: indexFilePath)
    }
}

// MARK: - CacheEntry

/// 快取項目的 metadata
private struct CacheEntry: Codable {
    let filename: String
    var timestamp: TimeInterval
}
