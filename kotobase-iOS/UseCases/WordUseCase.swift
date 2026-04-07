import Foundation
import SwiftData

/// 筆記 CRUD 操作
/// - Note: 封裝 SwiftData 的筆記相關增刪改查邏輯
final class WordUseCase {

    // MARK: - Constants

    /// 各欄位最大長度
    private enum FieldLimit {
        static let title = 500
        static let jpContent = 20_000
        static let note = 5_000
    }

    /// 匯入筆記的最大數量
    static let maxImportCount = 10_000

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Init

    /// - Parameter modelContext: SwiftData 的 ModelContext
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// 新增筆記
    /// - Parameters:
    ///   - title: 標題
    ///   - jpContent: 日文內容
    ///   - note: 備註
    ///   - categoryId: 主分類 ID
    ///   - subcategoryIds: 子分類 ID 陣列
    /// - Returns: 新建的筆記
    @discardableResult
    func addWord(
        title: String,
        jpContent: String = "",
        note: String = "",
        categoryId: String? = nil,
        subcategoryIds: [String] = []
    ) -> Word {
        let word = Word(
            title: String(title.prefix(FieldLimit.title)),
            jpContent: String(jpContent.prefix(FieldLimit.jpContent)),
            note: String(note.prefix(FieldLimit.note)),
            categoryId: categoryId,
            subcategoryIds: subcategoryIds
        )
        modelContext.insert(word)
        return word
    }

    /// 複製筆記
    /// - Parameter original: 要複製的原始筆記
    /// - Returns: 新建的複製筆記
    @discardableResult
    func duplicateWord(_ original: Word, titleSuffix: String) -> Word {
        let word = Word(
            title: original.title + titleSuffix,
            jpContent: original.jpContent,
            note: original.note,
            categoryId: original.categoryId,
            subcategoryIds: original.subcategoryIds
        )
        modelContext.insert(word)
        return word
    }

    // MARK: - Read

    /// 取得所有筆記（依建立時間倒序）
    /// - Returns: 筆記陣列
    func fetchAllWords() throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 依 ID 取得筆記
    /// - Parameter id: 筆記 ID
    /// - Returns: 對應的筆記，找不到則回傳 nil
    func fetchWord(by id: String) throws -> Word? {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// 依分類篩選筆記
    /// - Parameter categoryId: 主分類 ID
    /// - Returns: 該分類下的筆記陣列
    func fetchWords(byCategoryId categoryId: String) throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.categoryId == categoryId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 依子分類篩選筆記
    /// - Parameter subcategoryId: 子分類 ID
    /// - Returns: 包含該子分類的筆記陣列
    func fetchWords(bySubcategoryId subcategoryId: String) throws -> [Word] {
        let allWords = try fetchAllWords()
        return allWords.filter { $0.subcategoryIds.contains(subcategoryId) }
    }

    /// 搜尋筆記（標題或內容含關鍵字）
    /// - Parameter keyword: 搜尋關鍵字
    /// - Returns: 符合條件的筆記陣列
    func searchWords(keyword: String) throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate {
                $0.title.localizedStandardContains(keyword) ||
                $0.jpContent.localizedStandardContains(keyword)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Update

    /// 更新筆記
    /// - Parameters:
    ///   - word: 要更新的筆記
    ///   - title: 新標題
    ///   - jpContent: 新日文內容
    ///   - note: 新備註
    ///   - categoryId: 新主分類 ID
    ///   - subcategoryIds: 新子分類 ID 陣列
    func updateWord(
        _ word: Word,
        title: String? = nil,
        jpContent: String? = nil,
        note: String? = nil,
        categoryId: String?? = nil,
        subcategoryIds: [String]? = nil
    ) {
        if let title {
            word.title = String(title.prefix(FieldLimit.title))
        }
        if let jpContent {
            word.jpContent = String(jpContent.prefix(FieldLimit.jpContent))
        }
        if let note {
            word.note = String(note.prefix(FieldLimit.note))
        }
        if let categoryId {
            word.categoryId = categoryId
        }
        if let subcategoryIds {
            word.subcategoryIds = subcategoryIds
        }
    }

    // MARK: - Delete

    /// 刪除筆記
    /// - Parameter word: 要刪除的筆記
    func deleteWord(_ word: Word) {
        modelContext.delete(word)
    }

    /// 清除所有筆記
    func clearAllWords() throws {
        let words = try fetchAllWords()
        for word in words {
            modelContext.delete(word)
        }
    }

    // MARK: - Sync Helpers

    /// 將本機筆記轉換為 DTO 陣列（供 Firestore 上傳使用）
    /// - Returns: WordDTO 陣列
    func exportAsDTO() throws -> [WordDTO] {
        let words = try fetchAllWords()
        return words.map { WordDTO(from: $0) }
    }

    /// 從雲端筆記資料匯入至本機（取代模式）
    /// - Parameter wordDTOs: 雲端下載的筆記 DTO 陣列
    func importFromCloud(_ wordDTOs: [WordDTO]) throws {
        // 清除現有筆記
        try clearAllWords()

        let formatter = ISO8601DateFormatter()

        // 匯入雲端筆記
        for dto in wordDTOs.prefix(Self.maxImportCount) {
            let createdAt = formatter.date(from: dto.createdAt) ?? .now
            let word = Word(
                id: dto.id,
                title: dto.title,
                jpContent: dto.jpContent,
                note: dto.note,
                categoryId: dto.categoryId,
                subcategoryIds: dto.subcategoryIds,
                createdAt: createdAt
            )
            modelContext.insert(word)
        }
    }

    /// 合併雲端筆記至本機（本機優先）
    /// - Parameter cloudWords: 雲端下載的筆記 DTO 陣列
    func mergeFromCloud(_ cloudWords: [WordDTO]) throws {
        let localWords = try fetchAllWords()
        let localIds = Set(localWords.map(\.id))
        let formatter = ISO8601DateFormatter()

        // 只匯入本機不存在的雲端筆記
        for dto in cloudWords {
            guard !localIds.contains(dto.id) else { continue }

            let createdAt = formatter.date(from: dto.createdAt) ?? .now
            let word = Word(
                id: dto.id,
                title: dto.title,
                jpContent: dto.jpContent,
                note: dto.note,
                categoryId: dto.categoryId,
                subcategoryIds: dto.subcategoryIds,
                createdAt: createdAt
            )
            modelContext.insert(word)
        }
    }
}
