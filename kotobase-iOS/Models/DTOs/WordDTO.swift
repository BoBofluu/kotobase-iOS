import Foundation

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
