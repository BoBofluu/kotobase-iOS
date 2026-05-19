import Foundation
import SwiftData

/// 分類 CRUD 操作
/// - Note: 封裝 SwiftData 的分類相關增刪改查邏輯
final class CategoryUseCase {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Init

    /// - Parameter modelContext: SwiftData 的 ModelContext
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// 新增主分類
    /// - Parameters:
    ///   - label: 分類名稱
    ///   - customColor: 顯示色 Hex 碼
    /// - Returns: 新建的分類
    @discardableResult
    func addCategory(label: String, customColor: String = "#818cf8") -> Category {
        let category = Category(label: label, customColor: customColor)
        modelContext.insert(category)
        return category
    }

    /// 新增子分類至指定主分類
    /// - Parameters:
    ///   - label: 子分類名稱
    ///   - category: 父主分類
    /// - Returns: 新建的子分類
    @discardableResult
    func addSubcategory(label: String, to category: Category) -> Subcategory {
        let subcategory = Subcategory(label: label)
        subcategory.category = category
        category.subcategories.append(subcategory)
        modelContext.insert(subcategory)
        return subcategory
    }

    // MARK: - Read

    /// 取得所有主分類（依建立時間排序）
    /// - Returns: 主分類陣列
    func fetchAllCategories() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 依 ID 取得主分類
    /// - Parameter id: 分類 ID
    /// - Returns: 對應的分類，找不到則回傳 nil
    func fetchCategory(by id: String) throws -> Category? {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// 依 ID 取得子分類
    /// - Parameter id: 子分類 ID
    /// - Returns: 對應的子分類，找不到則回傳 nil
    func fetchSubcategory(by id: String) throws -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Update

    /// 更新主分類的顏色
    /// - Parameters:
    ///   - category: 要更新的分類
    ///   - color: 新的 Hex 顏色碼
    func updateCategoryColor(_ category: Category, color: String) {
        category.customColor = color
    }

    /// 更新主分類的名稱
    /// - Parameters:
    ///   - category: 要更新的分類
    ///   - label: 新的名稱
    func updateCategoryLabel(_ category: Category, label: String) {
        category.label = label
    }

    // MARK: - Delete

    /// 刪除主分類（連帶刪除所有子分類）
    /// - Parameter category: 要刪除的分類
    func deleteCategory(_ category: Category) {
        modelContext.delete(category)
    }

    /// 刪除子分類
    /// - Parameter subcategory: 要刪除的子分類
    func deleteSubcategory(_ subcategory: Subcategory) {
        if let category = subcategory.category {
            category.subcategories.removeAll { $0.id == subcategory.id }
        }
        modelContext.delete(subcategory)
    }

    // MARK: - Sync Helpers

    /// 將本機分類轉換為 DTO 字典（供 Firestore 上傳使用）
    /// - Returns: [分類ID: CategoryDTO]
    func exportAsDTO() throws -> [String: CategoryDTO] {
        let categories = try fetchAllCategories()
        var result: [String: CategoryDTO] = [:]

        for category in categories {
            let subcatDTOs = category.subcategories.map {
                SubcategoryDTO(id: $0.id, label: $0.label)
            }
            result[category.id] = CategoryDTO(
                label: category.label,
                customColor: category.customColor,
                subcats: subcatDTOs
            )
        }

        return result
    }

    /// 從 Firestore 的分類資料匯入至本機
    /// - Parameter categoriesRaw: Firestore 回傳的原始分類字典
    func importFromCloud(_ categoriesRaw: [String: Any]) throws {
        // 清除現有分類
        let existing = try fetchAllCategories()
        for category in existing {
            modelContext.delete(category)
        }

        // 匯入雲端分類
        for (catId, value) in categoriesRaw {
            guard let catDict = value as? [String: Any],
                  let label = catDict["label"] as? String else {
                continue
            }
            let color = catDict["customColor"] as? String ?? "#818cf8"
            let category = Category(id: catId, label: label, customColor: color)
            modelContext.insert(category)

            // 匯入子分類
            if let subcats = catDict["subcats"] as? [[String: Any]] {
                for subDict in subcats {
                    guard let subId = subDict["id"] as? String,
                          let subLabel = subDict["label"] as? String else {
                        continue
                    }
                    let subcategory = Subcategory(id: subId, label: subLabel)
                    subcategory.category = category
                    category.subcategories.append(subcategory)
                    modelContext.insert(subcategory)
                }
            }
        }
    }
}
