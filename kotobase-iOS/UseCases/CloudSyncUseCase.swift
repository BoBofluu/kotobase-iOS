import Foundation
import SwiftData

/// 雲端同步操作
/// - Note: 協調 SwiftData 本機資料與 Firestore 雲端資料的同步
final class CloudSyncUseCase {

    // MARK: - Properties

    private let wordUseCase: WordUseCase
    private let categoryUseCase: CategoryUseCase
    private let firestoreService: FirestoreService
    private let authService: FirebaseAuthService

    // MARK: - Init

    /// - Parameters:
    ///   - modelContext: SwiftData 的 ModelContext
    ///   - firestoreService: Firestore 服務實例
    ///   - authService: 認證服務實例
    init(
        modelContext: ModelContext,
        firestoreService: FirestoreService = .shared,
        authService: FirebaseAuthService = .shared
    ) {
        self.wordUseCase = WordUseCase(modelContext: modelContext)
        self.categoryUseCase = CategoryUseCase(modelContext: modelContext)
        self.firestoreService = firestoreService
        self.authService = authService
    }

    // MARK: - Upload

    /// 上傳本機資料至雲端（取代模式：雲端資料會被本機資料完全覆蓋）
    func uploadToCloud() async throws {
        let uid = try requireUID()
        let words = try wordUseCase.exportAsDTO()
        let categories = try categoryUseCase.exportAsDTO()
        try await firestoreService.uploadWords(uid: uid, words: words, categories: categories)
    }

    /// 合併上傳本機資料至雲端（保留雲端獨有的資料）
    func mergeUploadToCloud() async throws {
        let uid = try requireUID()
        let words = try wordUseCase.exportAsDTO()
        let categories = try categoryUseCase.exportAsDTO()
        try await firestoreService.mergeUploadWords(uid: uid, words: words, categories: categories)
    }

    // MARK: - Download

    /// 從雲端下載資料至本機（取代模式：本機資料會被雲端資料完全覆蓋）
    func downloadFromCloud() async throws {
        let uid = try requireUID()

        guard let cloudData = try await firestoreService.downloadWords(uid: uid) else {
            throw SyncError.noCloudData
        }

        try wordUseCase.importFromCloud(cloudData.words)

        if let categoriesRaw = cloudData.categoriesRaw {
            try categoryUseCase.importFromCloud(categoriesRaw)
        }
    }

    /// 從雲端合併下載至本機（本機優先，僅匯入本機不存在的資料）
    func mergeDownloadFromCloud() async throws {
        let uid = try requireUID()

        guard let cloudData = try await firestoreService.downloadWords(uid: uid) else {
            throw SyncError.noCloudData
        }

        try wordUseCase.mergeFromCloud(cloudData.words)

        // 分類合併：目前採取雲端覆蓋策略（與 Web 版一致）
        if let categoriesRaw = cloudData.categoriesRaw {
            try categoryUseCase.importFromCloud(categoriesRaw)
        }
    }

    // MARK: - Clear

    /// 清除雲端所有資料
    func clearCloud() async throws {
        let uid = try requireUID()
        try await firestoreService.clearCloud(uid: uid)
    }

    // MARK: - Export / Import

    /// 匯出本機資料為 JSON Data
    /// - Returns: 可匯出的 JSON Data
    func exportData() throws -> Data {
        let words = try wordUseCase.exportAsDTO()
        let categories = try categoryUseCase.exportAsDTO()

        let exportPayload: [String: Any] = [
            "version": "v2",
            "exportedAt": ISO8601DateFormatter().string(from: .now),
            "words": words.map { $0.toDictionary() },
            "categories": categories.mapValues { $0.toDictionary() }
        ]

        return try JSONSerialization.data(withJSONObject: exportPayload, options: .prettyPrinted)
    }

    /// 匯入 JSON 檔案的資料
    /// - Parameter jsonData: JSON 格式的匯入資料
    func importData(_ jsonData: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SyncError.invalidFormat
        }

        // 驗證格式
        guard json["version"] as? String == "v2" || (json["words"] != nil && json["categories"] != nil) else {
            throw SyncError.invalidFormat
        }

        // 匯入筆記
        if let wordsArray = json["words"] as? [[String: Any]] {
            guard wordsArray.count <= WordUseCase.maxImportCount else {
                throw SyncError.tooManyWords
            }
            let wordDTOs = wordsArray.compactMap { WordDTO(from: $0) }
            try wordUseCase.importFromCloud(wordDTOs)
        }

        // 匯入分類
        if let categoriesDict = json["categories"] as? [String: Any] {
            try categoryUseCase.importFromCloud(categoriesDict)
        }
    }

    // MARK: - Private

    /// 取得目前登入使用者的 UID，未登入則拋出錯誤
    private func requireUID() throws -> String {
        guard let uid = authService.currentUID else {
            throw SyncError.notSignedIn
        }
        return uid
    }
}

// MARK: - Error

/// 同步相關錯誤
enum SyncError: Error {
    /// 使用者未登入
    case notSignedIn
    /// 雲端無資料
    case noCloudData
    /// 匯入檔案格式無效
    case invalidFormat
    /// 匯入筆記數量超過上限
    case tooManyWords
}
