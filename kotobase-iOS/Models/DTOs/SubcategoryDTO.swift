import Foundation

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
