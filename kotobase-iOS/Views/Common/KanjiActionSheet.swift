import SwiftUI
import SwiftData

/// 漢字操作 sheet（半屏）
/// - Note: 由 `FuriganaText` 在使用者點擊漢字 token 時 present
///   功能：顯示漢字 / 當前讀音 / 朗讀（依平假名）/ 修正讀音（候選 picker + 自訂輸入）
///   使用者選擇的讀音寫入 `UserFuriganaOverride`（SwiftData），透過 @Query 自動廣播到所有 FuriganaText
struct KanjiActionSheet: View {

    // MARK: - Input

    /// 來源文字的 hash（修正僅在同段文字內生效）
    let contextHash: String

    /// 漢字表面形式
    let surface: String

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    /// 目前選擇的讀音（修正後即時更新，朗讀依此值）
    @State private var selectedReading: String
    @State private var candidates: [String] = []
    @State private var showCorrectionPicker: Bool = false
    @State private var customReading: String = ""
    @State private var errorMessage: String?
    @State private var savedHint: Bool = false
    /// 正在向 server 取得 TTS 音檔（與播放狀態 audioPlayer.isPlaying 是不同階段）
    @State private var isPreparing: Bool = false
    @State private var audioPlayer = AudioPlayerEngine()

    // MARK: - Init

    /// - Parameters:
    ///   - contextHash: 來源文字 hash
    ///   - surface: 漢字表面形式
    ///   - currentReading: 進入 sheet 時的讀音（作為 selectedReading 初值）
    init(contextHash: String, surface: String, currentReading: String) {
        self.contextHash = contextHash
        self.surface = surface
        _selectedReading = State(initialValue: currentReading)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                kanjiHeader
                Divider().padding(.vertical, 16)
                if showCorrectionPicker {
                    correctionPicker
                } else {
                    mainActions
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .navigationTitle(showCorrectionPicker ? "修正讀音" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showCorrectionPicker {
                        Button("返回") { showCorrectionPicker = false }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .task {
            candidates = await APIConfig.furiganaUseCase.candidates(for: surface)
        }
    }

    // MARK: - Sections

    /// 漢字 + 平假名 + 朗讀 header
    private var kanjiHeader: some View {
        VStack(spacing: 8) {
            Text(selectedReading)
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.506, green: 0.549, blue: 0.965))
            Text(surface)
                .font(.system(size: 56, weight: .medium))
                .lineLimit(1)
            playButton
                .padding(.top, 8)
            if savedHint {
                Text("已更新讀音")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 朗讀按鈕（朗讀平假名）
    private var playButton: some View {
        Button {
            Task { await play() }
        } label: {
            playButtonLabel
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
        }
        .disabled(isPreparing || audioPlayer.isPlaying)
    }

    /// 朗讀按鈕內容：取檔中顯示轉圈、播放中實心、其餘空心
    @ViewBuilder
    private var playButtonLabel: some View {
        if isPreparing {
            ProgressView()
                .tint(.white)
        } else {
            Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 22))
        }
    }

    /// 主選單（修正讀音 / 加入詞庫等）
    private var mainActions: some View {
        VStack(spacing: 12) {
            actionRow(
                icon: "pencil",
                title: "修正讀音",
                subtitle: "從候選清單或自訂輸入"
            ) {
                showCorrectionPicker = true
            }
            // 未來 Phase B-2 在這邊加「加入詞庫」按鈕
        }
    }

    /// 候選讀音 picker
    private var correctionPicker: some View {
        List {
            candidatesSection
            customSection
            errorSection
        }
        .listStyle(.insetGrouped)
    }

    /// 字典候選 section
    @ViewBuilder
    private var candidatesSection: some View {
        if !candidates.isEmpty {
            Section("字典候選") {
                ForEach(candidates, id: \.self) { reading in
                    candidateRow(reading: reading)
                }
            }
        }
    }

    /// 候選 row
    private func candidateRow(reading: String) -> some View {
        Button {
            save(reading: reading)
        } label: {
            HStack {
                Text(reading)
                    .foregroundStyle(.primary)
                Spacer()
                if reading == selectedReading {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// 自訂輸入 section
    private var customSection: some View {
        Section("自訂") {
            HStack {
                TextField("輸入平假名", text: $customReading)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("儲存") {
                    save(reading: customReading.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(customReading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    /// 錯誤訊息 section
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Section { Text(errorMessage).foregroundStyle(.red) }
        }
    }

    /// 主選單列（icon + 文字 + 副標）
    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    /// 朗讀當前選擇的平假名讀音
    /// - Note: 以 `selectedReading` 為準，修正後即唸新讀音
    ///   播放狀態交由 `audioPlayer`（@Observable）管理，本 method 只負責取檔→載入→播放
    private func play() async {
        let textToSpeak = selectedReading
        guard !textToSpeak.isEmpty, !isPreparing, !audioPlayer.isPlaying else { return }
        isPreparing = true
        defer { isPreparing = false }
        do {
            let base64 = try await APIConfig.ttsUseCase.synthesizeWord(text: textToSpeak)
            guard let data = Data(base64Encoded: base64) else { return }
            try audioPlayer.load(data: data)
            audioPlayer.play()
        } catch {
            errorMessage = "朗讀失敗：\(error.localizedDescription)"
        }
    }

    /// 儲存使用者選擇的讀音
    /// - Note: 修正僅在此段文字（contextHash）內生效；不會影響其他筆記
    /// - Parameter reading: 使用者選擇/輸入的讀音
    private func save(reading: String) {
        guard !reading.isEmpty else { return }
        let context = contextHash
        let surf = surface
        let descriptor = FetchDescriptor<UserFuriganaOverride>(
            predicate: #Predicate { $0.contextHash == context && $0.surface == surf }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            if let entry = existing.first {
                entry.reading = reading
                entry.updatedAt = .now
            } else {
                modelContext.insert(
                    UserFuriganaOverride(
                        contextHash: contextHash,
                        surface: surface,
                        reading: reading
                    )
                )
            }
            try modelContext.save()
            // 不關閉 sheet：更新讀音、回主畫面，使用者可立即朗讀新讀音
            selectedReading = reading
            customReading = ""
            errorMessage = nil
            showCorrectionPicker = false
            showSavedHint()
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    /// 顯示「已更新讀音」短暫提示
    private func showSavedHint() {
        withAnimation { savedHint = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { savedHint = false }
        }
    }
}

// MARK: - Preview

#Preview {
    KanjiActionSheet(
        contextHash: "preview",
        surface: "海馬",
        currentReading: "とど"
    )
    .modelContainer(for: UserFuriganaOverride.self, inMemory: true)
}
