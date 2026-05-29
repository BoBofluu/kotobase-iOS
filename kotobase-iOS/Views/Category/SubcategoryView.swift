import SwiftUI
import SwiftData

/// 子分類管理畫面（畫面 B）
/// - Note: 主分類的顏色變更、子分類的新增、改名與刪除
struct SubcategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PaletteColor.createdAt, order: .reverse) private var customColors: [PaletteColor]
    @State private var viewModel = SubcategoryViewModel()

    /// 對象主分類
    let category: Category

    // MARK: - Rename State

    @State private var renameTarget: Subcategory?
    @State private var renameText: String = ""

    var body: some View {
        List {
            colorSection

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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteSubcategory(context: modelContext, subcategory: subcategory)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                            Button {
                                startRename(subcategory)
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle(category.label)
        .onDisappear {
            // 離開時把目前的自訂色登錄到獨立色盤（預設色 / 重複自動略過）
            viewModel.registerCustomColor(context: modelContext, hex: category.customColor)
        }
        .alert("重新命名子分類", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        ), presenting: renameTarget) { subcategory in
            TextField("子分類名稱", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("儲存") {
                viewModel.updateSubcategoryLabel(context: modelContext, subcategory: subcategory, label: renameText)
                renameTarget = nil
            }
        }
    }

    private var colorSection: some View {
        Section("顏色") {
            // 預設顏色
            swatchRow(hexes: CategoryPalette.presets)

            // 我的顏色（自訂、獨立儲存，長按可刪除）
            if !customColors.isEmpty {
                Text("我的顏色（最多 \(PaletteUseCase.maxCount) 個，長按可刪除）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                swatchRow(hexes: customColors.map(\.hex)) { hex in
                    if let color = customColors.first(where: { $0.hex == hex }) {
                        viewModel.deletePaletteColor(context: modelContext, color: color)
                    }
                }
            }

            ColorPicker("自訂顏色", selection: Binding(
                get: { Color(hex: category.customColor) ?? .gray },
                set: { newColor in
                    guard let hex = newColor.toHex() else { return }
                    viewModel.updateCategoryColor(context: modelContext, category: category, color: hex)
                }
            ), supportsOpacity: false)
        }
    }

    private func swatchRow(hexes: [String], onDelete: ((String) -> Void)? = nil) -> some View {
        FlowLayout(spacing: 14) {
            ForEach(hexes, id: \.self) { hex in
                let swatch = Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: category.customColor == hex ? 2 : 0)
                    )
                    .onTapGesture {
                        viewModel.updateCategoryColor(context: modelContext, category: category, color: hex)
                    }

                if let onDelete {
                    swatch.contextMenu {
                        Button(role: .destructive) {
                            onDelete(hex)
                        } label: {
                            Label("刪除顏色", systemImage: "trash")
                        }
                    }
                } else {
                    swatch
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startRename(_ subcategory: Subcategory) {
        renameText = subcategory.label
        renameTarget = subcategory
    }
}
