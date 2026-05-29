import SwiftUI
import SwiftData

/// 分類管理主頁（畫面 A）
/// - Note: 主分類的一覽、新增、刪除。點擊可進入子分類管理畫面。
struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @State private var viewModel = CategoryListViewModel()

    // MARK: - Rename State

    @State private var renameTarget: Category?
    @State private var renameText: String = ""

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
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: category.customColor) ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(category.label)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteCategory(context: modelContext, category: category)
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                        Button {
                            startRename(category)
                        } label: {
                            Label("編輯", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "category_management_title"))
        .alert("重新命名分類", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        ), presenting: renameTarget) { category in
            TextField("分類名稱", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("儲存") {
                viewModel.updateCategoryLabel(context: modelContext, category: category, label: renameText)
                renameTarget = nil
            }
        }
    }

    private func startRename(_ category: Category) {
        renameText = category.label
        renameTarget = category
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
    }
    .modelContainer(for: [Category.self, Subcategory.self, Word.self, NoteImage.self, PaletteColor.self], inMemory: true)
}
