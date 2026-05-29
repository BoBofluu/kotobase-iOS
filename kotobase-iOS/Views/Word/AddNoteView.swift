import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 新增筆記畫面
struct AddNoteView: View {

    // MARK: - Environment / Query

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]

    // MARK: - Form State

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var note: String = ""
    @State private var selectedCategoryId: String?
    @State private var selectedSubcategoryIds: Set<String> = []

    // MARK: - Photo / OCR State

    @State private var attachedPhotos: [AttachedPhoto] = []
    @State private var showPhotoSourceDialog = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var previewPhoto: AttachedPhoto?

    // MARK: - Popups

    @State private var showCategoryPicker = false
    @State private var showNewCategorySheet = false
    @State private var showCategoryManager = false

    // MARK: - Error / Success

    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedCategory: Category? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleField
                        categorySection
                        contentField
                        noteField
                        photoSection
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.immediately)
                .background(Color(.systemGroupedBackground))

                floatingCameraButton

                if showCategoryPicker {
                    CenteredOverlay(onDismiss: { showCategoryPicker = false }) {
                        CategoryPickerCard(
                            categories: categories,
                            selectedCategoryId: $selectedCategoryId,
                            selectedSubcategoryIds: $selectedSubcategoryIds,
                            onDone: { showCategoryPicker = false }
                        )
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showCategoryPicker)
            .navigationTitle("新增筆記")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("選擇照片來源", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            Button("拍照") {
                // 防呆：模擬器 / 無相機裝置不可開相機
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    errorMessage = "此裝置無法使用相機"
                }
            }
            Button("從相簿選擇") { showPhotoLibrary = true }
            Button("取消", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            Task { await handlePickerItem(newItem) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $previewPhoto) { photo in
            PhotoEditorView(image: photo.image) { text in
                appendToContent(text)
            }
        }
        .sheet(isPresented: $showCategoryManager) {
            NavigationStack {
                CategoryListView()
            }
        }
        .sheet(isPresented: $showNewCategorySheet) {
            NewCategoryCard(
                onClose: { showNewCategorySheet = false },
                onCreate: { name, color, subs in
                    addCategory(name, color: color, subcategoryNames: subs)
                }
            )
        }
        .alert("錯誤", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("完成", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("確定", role: .cancel) { successMessage = nil }
        } message: {
            Text(successMessage ?? "")
        }
    }

    // MARK: - Sections

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("筆記標題", text: $title)
                .font(.body)
                .padding(.vertical, 10)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Text("分類").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showCategoryManager = true
                } label: {
                    Label("管理", systemImage: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandCyan)
                }
                Button {
                    showNewCategorySheet = true
                } label: {
                    Label("新增分類", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandCyan)
                }
            }

            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    if let cat = selectedCategory {
                        Circle()
                            .fill(Color(hex: cat.customColor) ?? .gray)
                            .frame(width: 12, height: 12)
                    }
                    Text(selectedCategoryDisplay)
                        .foregroundStyle(selectedCategory == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var selectedCategoryDisplay: String {
        guard let cat = selectedCategory else { return "選擇分類" }
        let subs = cat.subcategories.filter { selectedSubcategoryIds.contains($0.id) }
        if subs.isEmpty {
            return cat.label
        }
        return cat.label + " / " + subs.map(\.label).joined(separator: ", ")
    }

    private var contentField: some View {
        FieldSection(title: "內容") {
            BorderedTextEditor(text: $content, minHeight: 200)
        }
    }

    private var noteField: some View {
        FieldSection(title: "備註") {
            BorderedTextEditor(text: $note, minHeight: 120)
        }
    }

    private var photoSection: some View {
        Group {
            if !attachedPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("照片").font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(attachedPhotos) { photo in
                                PhotoThumbnail(
                                    photo: photo,
                                    onTap: { previewPhoto = photo },
                                    onDelete: { deletePhoto(photo) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("儲存到清單")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.black, in: RoundedRectangle(cornerRadius: 28))
        }
        .padding(.top, 8)
        .padding(.bottom, 60) // 給 FAB 留位
    }

    // MARK: - Floating FAB

    private var floatingCameraButton: some View {
        Button {
            showPhotoSourceDialog = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.brandCyan, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func appendToContent(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if content.isEmpty {
            content = trimmed
        } else {
            content += "\n" + trimmed
        }
    }

    private func deletePhoto(_ photo: AttachedPhoto) {
        // 設計決定：刪除照片不會刪除已插入內容欄位的 OCR 文字
        // （使用者可能已編輯，文字視為筆記內容一部分）
        attachedPhotos.removeAll { $0.id == photo.id }
    }

    private func handlePickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                handleCapturedImage(image)
            } else {
                errorMessage = "無法讀取所選照片"
            }
        } catch {
            errorMessage = "讀取照片失敗：\(error.localizedDescription)"
        }
        photoPickerItem = nil
    }

    private func handleCapturedImage(_ image: UIImage) {
        // 拍照/選圖後只先存進圖片區，OCR 留到圖片編輯頁按需執行
        attachedPhotos.append(AttachedPhoto(image: image))
    }

    private func save() {
        // 防呆：標題必填
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "請輸入筆記標題"
            return
        }

        // 照片壓成 JPEG（外部儲存）
        let imageDatas = attachedPhotos.compactMap { $0.image.jpegData(compressionQuality: 0.7) }

        let useCase = APIConfig.makeWordUseCase(context: modelContext)
        let word = useCase.addWord(
            title: trimmedTitle,
            jpContent: content.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: selectedCategory?.id,
            subcategoryIds: Array(selectedSubcategoryIds),
            imageDatas: imageDatas
        )

        do {
            try modelContext.save()
        } catch {
            // 儲存失敗，回滾未提交的插入，保留表單內容讓使用者重試
            useCase.deleteWord(word)
            errorMessage = "儲存失敗：\(error.localizedDescription)"
            return
        }

        // 重置表單（停留在同一頁）
        title = ""
        content = ""
        note = ""
        selectedCategoryId = nil
        selectedSubcategoryIds = []
        attachedPhotos = []

        // 成功提示
        successMessage = "已儲存到清單"
    }

    private func addCategory(_ name: String, color: String, subcategoryNames: [String]) {
        let useCase = APIConfig.makeCategoryUseCase(context: modelContext)
        let category = useCase.addCategory(label: name, customColor: color)
        for subName in subcategoryNames {
            useCase.addSubcategory(label: subName, to: category)
        }
        // 自訂色登錄到獨立色盤（預設色 / 重複會自動略過）
        APIConfig.makePaletteUseCase(context: modelContext).addColor(hex: color)

        do {
            try modelContext.save()
        } catch {
            // 回滾：主分類 cascade 刪除會連帶移除剛建立的子分類
            useCase.deleteCategory(category)
            errorMessage = "新增分類失敗：\(error.localizedDescription)"
            return
        }

        // 自動選取剛建立的分類
        selectedCategoryId = category.id
        selectedSubcategoryIds = []
        showNewCategorySheet = false
    }
}

// MARK: - Reusable Field Section

private struct FieldSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            content
        }
    }
}

// MARK: - Bordered TextEditor

private struct BorderedTextEditor: View {
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
    }
}

// MARK: - Subcategory Chips（flow 自動換行）

private struct SubcategoryChips: View {
    let subcategories: [Subcategory]
    @Binding var selectedIds: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(subcategories) { sub in
                let isSelected = selectedIds.contains(sub.id)
                Button {
                    if isSelected {
                        selectedIds.remove(sub.id)
                    } else {
                        selectedIds.insert(sub.id)
                    }
                } label: {
                    Text(sub.label)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.brandCyan : Color(.systemGray6))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .overlay(
                            Capsule().stroke(isSelected ? .clear : Color(.systemGray4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Centered Overlay（淡入淡出置中彈窗）

private struct CenteredOverlay<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            content
                .padding(24)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                )
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
    }
}

// MARK: - Category Picker Card

private struct CategoryPickerCard: View {
    let categories: [Category]
    @Binding var selectedCategoryId: String?
    @Binding var selectedSubcategoryIds: Set<String>
    let onDone: () -> Void

    private var currentCategory: Category? {
        if let id = selectedCategoryId {
            return categories.first { $0.id == id }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("選擇分類")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            if categories.isEmpty {
                Text("尚無分類，請先新增分類")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(categories) { cat in
                            CategoryRow(
                                category: cat,
                                isSelected: cat.id == selectedCategoryId
                            ) {
                                if selectedCategoryId == cat.id {
                                    selectedCategoryId = nil
                                    selectedSubcategoryIds = []
                                } else {
                                    selectedCategoryId = cat.id
                                    selectedSubcategoryIds = []
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)

                if let cat = currentCategory, !cat.subcategories.isEmpty {
                    Divider()
                    Text("子分類")
                        .font(.subheadline.weight(.semibold))
                    SubcategoryChips(
                        subcategories: cat.subcategories,
                        selectedIds: $selectedSubcategoryIds
                    )
                }
            }

            Button(action: onDone) {
                Text("完成")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brandCyan, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct CategoryRow: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color(hex: category.customColor) ?? .gray)
                    .frame(width: 12, height: 12)
                Text(category.label)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandCyan)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.brandCyan.opacity(0.1) : Color(.systemGray6))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Category Card（最簡功能版，樣式待定）

/// 子分類輸入草稿
private struct SubcategoryDraft: Identifiable {
    let id = UUID()
    var name: String = ""
}

private struct NewCategoryCard: View {
    let onClose: () -> Void
    let onCreate: (String, String, [String]) -> Void

    @Query(sort: \PaletteColor.createdAt, order: .reverse) private var customColors: [PaletteColor]

    @State private var name: String = ""
    @State private var selectedColor: String = "#818cf8"
    @State private var subDrafts: [SubcategoryDraft] = []

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分類名稱").font(.subheadline.weight(.semibold))
                        TextField("分類名稱", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    colorSection

                    subcategorySection
                }
                .padding(20)
            }
            .navigationTitle("新增分類")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增", action: create)
                        .bold()
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("顏色").font(.subheadline.weight(.semibold))

            // 預設顏色
            swatchRow(hexes: CategoryPalette.presets)

            // 我的顏色（自訂、獨立儲存）
            if !customColors.isEmpty {
                Text("我的顏色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                swatchRow(hexes: customColors.map(\.hex))
            }

            ColorPicker("自訂顏色", selection: Binding(
                get: { Color(hex: selectedColor) ?? .gray },
                set: { newColor in
                    guard let hex = newColor.toHex() else { return }
                    selectedColor = hex
                }
            ), supportsOpacity: false)
        }
    }

    private func swatchRow(hexes: [String]) -> some View {
        FlowLayout(spacing: 12) {
            ForEach(hexes, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                    )
                    .onTapGesture { selectedColor = hex }
            }
        }
    }

    private var subcategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("子分類（可選）").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    subDrafts.append(SubcategoryDraft())
                } label: {
                    Label("新增子分類", systemImage: "plus")
                        .font(.footnote)
                        .foregroundStyle(Color.brandCyan)
                }
            }

            ForEach($subDrafts) { $draft in
                HStack(spacing: 8) {
                    TextField("子分類名稱", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        subDrafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        let subs = subDrafts
            .map { $0.name.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        onCreate(trimmedName, selectedColor, subs)
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnail: View {
    let photo: AttachedPhoto
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
    }
}

// MARK: - Models

struct AttachedPhoto: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
}
