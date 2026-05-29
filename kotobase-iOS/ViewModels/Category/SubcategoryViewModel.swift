import Foundation
import SwiftData
import Observation

/// 子分類管理（畫面 B）的 ViewModel
/// - Note: 管理特定主分類底下的子分類新增、刪除與顏色變更
@Observable
final class SubcategoryViewModel {

    // MARK: - Properties

    /// 新子分類名稱的輸入值
    var newSubcategoryName: String = ""

    // MARK: - Actions

    /// 更新主分類的顏色
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - category: 要更新的主分類
    ///   - color: 新的 Hex 顏色碼
    func updateCategoryColor(context: ModelContext, category: Category, color: String) {
        let useCase = CategoryUseCase(modelContext: context)
        useCase.updateCategoryColor(category, color: color)
    }

    /// 登錄自訂顏色到獨立色盤
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - hex: 顏色 Hex（預設色 / 重複 / 已達上限會自動略過）
    func registerCustomColor(context: ModelContext, hex: String) {
        let useCase = PaletteUseCase(modelContext: context)
        useCase.addColor(hex: hex)
    }

    /// 從色盤刪除自訂顏色
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - color: 要刪除的自訂顏色
    func deletePaletteColor(context: ModelContext, color: PaletteColor) {
        let useCase = PaletteUseCase(modelContext: context)
        useCase.deleteColor(color)
    }

    /// 新增子分類
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - category: 父主分類
    func addSubcategory(context: ModelContext, category: Category) {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let useCase = CategoryUseCase(modelContext: context)
        useCase.addSubcategory(label: trimmed, to: category)
        newSubcategoryName = ""
    }

    /// 重新命名子分類
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - subcategory: 要更新的子分類
    ///   - label: 新名稱
    func updateSubcategoryLabel(context: ModelContext, subcategory: Subcategory, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let useCase = CategoryUseCase(modelContext: context)
        useCase.updateSubcategoryLabel(subcategory, label: trimmed)
    }

    /// 刪除子分類
    /// - Parameters:
    ///   - context: SwiftData 的 ModelContext
    ///   - subcategory: 要刪除的子分類
    func deleteSubcategory(context: ModelContext, subcategory: Subcategory) {
        let useCase = CategoryUseCase(modelContext: context)
        useCase.deleteSubcategory(subcategory)
    }
}
