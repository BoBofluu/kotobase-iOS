import Foundation
import SwiftData

/// 使用者自訂的平假名讀音覆蓋（per-text）
/// - Note: 修正範圍 = 同段文字內所有相同 surface
///   邏輯唯一鍵：(contextHash, surface)；同段文字 + 同 surface 只保留一筆，新的覆寫舊的
///   不同段文字的同 surface 互不影響——例：歌詞內把「愛」改成「かなしい」
///   不會影響其他筆記裡的「愛=あい」
@Model
final class UserFuriganaOverride {

    /// 來源文字的 SHA256 hash（隔離不同筆記的修正）
    var contextHash: String

    /// 漢字表面形式
    var surface: String

    /// 使用者選擇的平假名讀音
    var reading: String

    /// 最後一次更新時間
    var updatedAt: Date

    init(
        contextHash: String,
        surface: String,
        reading: String,
        updatedAt: Date = .now
    ) {
        self.contextHash = contextHash
        self.surface = surface
        self.reading = reading
        self.updatedAt = updatedAt
    }
}
