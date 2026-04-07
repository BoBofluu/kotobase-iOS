import Foundation
import SwiftData

/// 筆記（單字 / 例句）模型
/// - Note: 對應 Web 版 IndexedDB 的 words store，以及 Firestore 的 users/{uid}/words/{wordId}
@Model
final class Word {
    /// 唯一識別碼
    @Attribute(.unique) var id: String
    /// 標題（單字或片語）
    var title: String
    /// 日文內容 / 解釋
    var jpContent: String
    /// 備註
    var note: String
    /// 所屬主分類 ID（對應 Category.id）
    var categoryId: String?
    /// 所屬子分類 ID 陣列（對應 Subcategory.id）
    var subcategoryIds: [String]
    /// 建立時間
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        jpContent: String = "",
        note: String = "",
        categoryId: String? = nil,
        subcategoryIds: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.jpContent = jpContent
        self.note = note
        self.categoryId = categoryId
        self.subcategoryIds = subcategoryIds
        self.createdAt = createdAt
    }
}
