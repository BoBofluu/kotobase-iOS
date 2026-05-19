import Foundation

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
