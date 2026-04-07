import Foundation
import FirebaseFirestore

/// Firestore 資料存取服務
/// - Note: 對應 Web 版 cloudSync.js，操作 users/{uid}/words 集合與 categories 欄位
final class FirestoreService {

    // MARK: - Singleton

    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    /// Firestore 批次操作上限
    private let batchLimit = 499

    private init() {}

    // MARK: - Words

    /// 上傳所有筆記至雲端（取代模式）
    /// - Parameters:
    ///   - uid: 使用者 UID
    ///   - words: 本機筆記陣列
    ///   - categories: 分類資料字典
    func uploadWords(uid: String, words: [WordDTO], categories: [String: CategoryDTO]) async throws {
        let userRef = db.collection("users").document(uid)
        let wordsRef = userRef.collection("words")

        // 寫入分類資料至使用者文件
        try await userRef.setData([
            "categories": categories.mapValues { $0.toDictionary() },
            "updatedAt": FieldValue.serverTimestamp()
        ])

        // 取得雲端現有筆記 ID，刪除本機不存在的
        let cloudSnapshot = try await wordsRef.getDocuments()
        let localIds = Set(words.map(\.id))
        let orphanDocs = cloudSnapshot.documents.filter { !localIds.contains($0.documentID) }

        // 批次刪除孤立筆記
        try await batchDelete(documents: orphanDocs)

        // 批次寫入本機筆記
        try await batchWrite(words: words, to: wordsRef)
    }

    /// 合併上傳筆記至雲端（保留雲端資料）
    /// - Parameters:
    ///   - uid: 使用者 UID
    ///   - words: 本機筆記陣列
    ///   - categories: 分類資料字典
    func mergeUploadWords(uid: String, words: [WordDTO], categories: [String: CategoryDTO]) async throws {
        let userRef = db.collection("users").document(uid)
        let wordsRef = userRef.collection("words")

        // 合併分類：雲端為底，本機覆蓋
        let existingDoc = try await userRef.getDocument()
        var mergedCategories = (existingDoc.data()?["categories"] as? [String: Any]) ?? [:]
        for (key, value) in categories {
            mergedCategories[key] = value.toDictionary()
        }

        try await userRef.setData([
            "categories": mergedCategories,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        // 寫入本機筆記（同 ID 覆蓋，不刪除雲端獨有的）
        try await batchWrite(words: words, to: wordsRef)
    }

    /// 從雲端下載所有筆記
    /// - Parameter uid: 使用者 UID
    /// - Returns: 筆記陣列與分類資料
    func downloadWords(uid: String) async throws -> CloudData? {
        let userRef = db.collection("users").document(uid)
        let userDoc = try await userRef.getDocument()

        guard userDoc.exists else { return nil }

        let wordsSnapshot = try await userRef.collection("words").getDocuments()
        let words = wordsSnapshot.documents.compactMap { WordDTO(from: $0.data()) }
        let categories = userDoc.data()?["categories"] as? [String: Any]

        return CloudData(words: words, categoriesRaw: categories)
    }

    /// 清除雲端所有資料
    /// - Parameter uid: 使用者 UID
    func clearCloud(uid: String) async throws {
        let userRef = db.collection("users").document(uid)
        let wordsSnapshot = try await userRef.collection("words").getDocuments()

        try await batchDelete(documents: wordsSnapshot.documents)
        try await userRef.delete()
    }

    // MARK: - Private Helpers

    /// 批次寫入筆記
    private func batchWrite(words: [WordDTO], to collectionRef: CollectionReference) async throws {
        var batch = db.batch()
        var count = 0

        for word in words {
            let docRef = collectionRef.document(word.id)
            batch.setData(word.toDictionary(), forDocument: docRef)
            count += 1

            if count >= batchLimit {
                try await batch.commit()
                batch = db.batch()
                count = 0
            }
        }

        if count > 0 {
            try await batch.commit()
        }
    }

    /// 批次刪除文件
    private func batchDelete(documents: [QueryDocumentSnapshot]) async throws {
        guard !documents.isEmpty else { return }

        var batch = db.batch()
        var count = 0

        for doc in documents {
            batch.deleteDocument(doc.reference)
            count += 1

            if count >= batchLimit {
                try await batch.commit()
                batch = db.batch()
                count = 0
            }
        }

        if count > 0 {
            try await batch.commit()
        }
    }
}

// MARK: - DTO

/// 雲端下載資料的容器
struct CloudData {
    let words: [WordDTO]
    let categoriesRaw: [String: Any]?
}

/// 筆記的資料傳輸物件（對應 Firestore 文件結構）
struct WordDTO {
    let id: String
    let title: String
    let jpContent: String
    let note: String
    let categoryId: String?
    let subcategoryIds: [String]
    let createdAt: String

    /// 從 Firestore 文件資料建立
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let createdAt = data["created_at"] as? String else {
            return nil
        }
        self.id = id
        self.title = data["title"] as? String ?? ""
        self.jpContent = data["jp_content"] as? String ?? ""
        self.note = data["note"] as? String ?? ""
        self.categoryId = data["category"] as? String
        self.subcategoryIds = data["subcategories"] as? [String] ?? []
        self.createdAt = createdAt
    }

    /// 從本機 Word 模型建立
    init(from word: Word) {
        self.id = word.id
        self.title = word.title
        self.jpContent = word.jpContent
        self.note = word.note
        self.categoryId = word.categoryId
        self.subcategoryIds = word.subcategoryIds

        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.string(from: word.createdAt)
    }

    /// 轉換為 Firestore 字典
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "jp_content": jpContent,
            "note": note,
            "subcategories": subcategoryIds,
            "created_at": createdAt
        ]
        if let categoryId {
            dict["category"] = categoryId
        }
        return dict
    }
}

/// 分類的資料傳輸物件（對應 Firestore categories 欄位）
struct CategoryDTO {
    let label: String
    let customColor: String
    let subcats: [SubcategoryDTO]

    /// 轉換為 Firestore 字典
    func toDictionary() -> [String: Any] {
        [
            "label": label,
            "customColor": customColor,
            "subcats": subcats.map { $0.toDictionary() }
        ]
    }
}

/// 子分類的資料傳輸物件
struct SubcategoryDTO {
    let id: String
    let label: String

    /// 轉換為 Firestore 字典
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "label": label
        ]
    }
}
