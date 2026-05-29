import Foundation
import SwiftData

/// 使用者自訂的分類顏色
/// - Note: 獨立於 Category 儲存，刪除分類不會影響此清單
@Model
final class PaletteColor {
    /// 顏色 Hex（`#RRGGBB`），同色不重複
    @Attribute(.unique) var hex: String
    /// 建立時間
    var createdAt: Date

    init(hex: String, createdAt: Date = .now) {
        self.hex = hex
        self.createdAt = createdAt
    }
}
