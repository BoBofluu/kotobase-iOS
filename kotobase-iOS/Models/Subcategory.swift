import Foundation
import SwiftData

/// 子分類模型
/// - Note: 從屬於主分類（Category）
@Model
final class Subcategory {
    /// 唯一識別碼
    @Attribute(.unique) var id: String
    /// 子分類名稱
    var label: String
    /// 建立時間
    var createdAt: Date

    /// 所屬的主分類
    var category: Category?

    init(
        id: String = UUID().uuidString,
        label: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.createdAt = createdAt
    }
}
