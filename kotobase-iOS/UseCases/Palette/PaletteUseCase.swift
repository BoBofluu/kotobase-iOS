import Foundation
import SwiftData

/// 自訂分類顏色的操作
/// - Note: 管理獨立於分類的 ``PaletteColor`` 清單
struct PaletteUseCase {

    /// 自訂顏色數量上限（達上限後停止收集）
    static let maxCount = 100

    private let modelContext: ModelContext

    /// - Parameter modelContext: SwiftData 的 ModelContext
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 新增自訂顏色
    /// - Parameter hex: 顏色 Hex（`#RRGGBB`）
    /// - Returns: 新建的顏色；若為預設色、已存在或已達上限則回傳 nil
    @discardableResult
    func addColor(hex: String) -> PaletteColor? {
        guard !CategoryPalette.presets.contains(hex) else { return nil }

        let descriptor = FetchDescriptor<PaletteColor>(
            predicate: #Predicate { $0.hex == hex }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return nil
        }

        // 已達上限則停止收集，需使用者先刪除才能再新增
        let currentCount = (try? modelContext.fetchCount(FetchDescriptor<PaletteColor>())) ?? 0
        guard currentCount < Self.maxCount else { return nil }

        let color = PaletteColor(hex: hex)
        modelContext.insert(color)
        return color
    }

    /// 刪除自訂顏色
    /// - Parameter color: 要刪除的顏色
    func deleteColor(_ color: PaletteColor) {
        modelContext.delete(color)
    }
}
