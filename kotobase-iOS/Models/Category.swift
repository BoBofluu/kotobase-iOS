import Foundation
import SwiftData

/// 主分類模型
/// - Note: 每個分類擁有自訂顏色與多個子分類
@Model
final class Category {
    /// 唯一識別碼
    @Attribute(.unique) var id: String
    /// 分類名稱
    var label: String
    /// 分類顯示色（Hex 格式，例：#818cf8）
    var customColor: String
    /// 建立時間
    var createdAt: Date

    /// 該分類下的子分類
    @Relationship(deleteRule: .cascade)
    var subcategories: [Subcategory]

    init(
        id: String = UUID().uuidString,
        label: String,
        customColor: String = "#818cf8",
        createdAt: Date = .now,
        subcategories: [Subcategory] = []
    ) {
        self.id = id
        self.label = label
        self.customColor = customColor
        self.createdAt = createdAt
        self.subcategories = subcategories
    }
}
