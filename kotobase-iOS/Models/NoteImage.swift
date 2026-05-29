import Foundation
import SwiftData

/// 筆記附圖
/// - Note: 影像資料以外部檔案儲存（`externalStorage`），不會撐大資料庫本體
@Model
final class NoteImage {
    /// 唯一識別碼
    @Attribute(.unique) var id: String
    /// 影像資料（JPEG），外部儲存
    @Attribute(.externalStorage) var data: Data
    /// 建立時間
    var createdAt: Date

    /// 所屬筆記
    var word: Word?

    init(id: String = UUID().uuidString, data: Data, createdAt: Date = .now) {
        self.id = id
        self.data = data
        self.createdAt = createdAt
    }
}
