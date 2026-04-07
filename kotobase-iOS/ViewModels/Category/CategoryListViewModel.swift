import Foundation
import SwiftData
import Observation

/// 分類管理主頁（畫面 A）的 ViewModel
/// - Note: 管理主分類的一覽表示、新增、刪除
@Observable
final class CategoryListViewModel {

    // MARK: - Properties

    /// 新分類名稱的輸入值
    var newCategoryName: String = ""

    // MARK: - Actions

    /// 新增主分類
    /// - Parameter context: SwiftData 的 ModelContext
    func addCategory(context: ModelContext) {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let useCase = CategoryUseCase(modelContext: context)
        useCase.addCategory(label: trimmed)
        newCategoryName = ""
    }

    /// 刪除主分類
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - category: 要刪除的分類
    func deleteCategory(context: ModelContext, category: Category) {
        let useCase = CategoryUseCase(modelContext: context)
        useCase.deleteCategory(category)
    }
}
