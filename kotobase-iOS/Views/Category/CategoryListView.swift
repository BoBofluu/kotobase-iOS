import SwiftUI
import SwiftData

/// 分類管理主頁（畫面 A）
/// - Note: 主分類的一覽、新增、刪除。點擊可進入子分類管理畫面。
struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @State private var viewModel = CategoryListViewModel()

    var body: some View {
        List {
            // 新增分類區塊
            Section {
                HStack {
                    TextField(String(localized: "category_name_placeholder"), text: $viewModel.newCategoryName)
                    Button(String(localized: "add_button")) {
                        viewModel.addCategory(context: modelContext)
                    }
                    .disabled(viewModel.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // 分類一覽
            Section {
                ForEach(categories) { category in
                    NavigationLink(destination: SubcategoryView(category: category)) {
                        Text(category.label)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteCategory(context: modelContext, category: categories[index])
                    }
                }
            }
        }
        .navigationTitle(String(localized: "category_management_title"))
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
    }
    .modelContainer(for: Category.self, inMemory: true)
}
