import SwiftUI
import SwiftData

/// 子分類管理畫面（畫面 B）
/// - Note: 主分類的顏色變更、子分類的新增與刪除
struct SubcategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SubcategoryViewModel()

    /// 對象主分類
    let category: Category

    var body: some View {
        List {
            // 新增子分類區塊
            Section {
                HStack {
                    TextField(String(localized: "subcategory_name_placeholder"), text: $viewModel.newSubcategoryName)
                    Button(String(localized: "add_button")) {
                        viewModel.addSubcategory(context: modelContext, category: category)
                    }
                    .disabled(viewModel.newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // 子分類一覽
            Section {
                ForEach(category.subcategories) { subcategory in
                    Text(subcategory.label)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let subcategory = category.subcategories[index]
                        viewModel.deleteSubcategory(context: modelContext, subcategory: subcategory)
                    }
                }
            }
        }
        .navigationTitle(category.label)
    }
}
