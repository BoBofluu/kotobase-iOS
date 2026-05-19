import FirebaseAuth
import SwiftUI

/// API 測試畫面（Furigana + TTS + 下載 + 播放器）
/// - Note: 不講究排版，所有功能直接縱向堆疊在 ScrollView 內方便逐一測試
struct APITestView: View {

    // MARK: - State

    @State private var inputText: String = "今日は良い天気ですね。"
    @State private var currentEmail: String?
    @State private var furiganaReadings: [FuriganaReading] = []
    @State private var ttsStatus: String = ""
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var player = AudioPlayerEngine()

    // Gemini TTS 設定
    @State private var selectedGeminiVoice: GeminiVoice = geminiVoices.first { $0.name == "Achernar" } ?? geminiVoices[0]
    @State private var selectedPresetID: String = promptPresets[0].id
    @State private var geminiPrompt: String = defaultGeminiPrompt

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    accountSection
                    inputSection
                    furiganaSection
                    geminiTTSSection
                    standardTTSSection
                    playerSection
                    downloadSection
                    statusSection
                }
                .padding()
            }
            .navigationTitle("API 測試")
            .onAppear {
                refreshAuthState()
            }
            .sheet(item: $shareItem) { item in
                ActivityShareSheet(items: [item.url])
            }
        }
    }

    /// `.sheet(item:)` 用的 Identifiable 包裝
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    // MARK: - Sections

    private var accountSection: some View {
        section(title: "帳號") {
            if let email = currentEmail {
                Text("已登入：\(email)")
                Button("登出", role: .destructive) {
                    signOut()
                }
            } else {
                Text("尚未登入（TTS 需要登入）")
                    .foregroundStyle(.secondary)
                Button("使用 Apple 登入") {
                    Task { await signInWithApple() }
                }
                Button("使用 Google 登入") {
                    Task { await signInWithGoogle() }
                }
            }
        }
    }

    private var inputSection: some View {
        section(title: "輸入文字") {
            TextEditor(text: $inputText)
                .frame(minHeight: 80, maxHeight: 200)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private var furiganaSection: some View {
        section(title: "Furigana 顯示") {
            Button("產生 Furigana") {
                Task { await loadFurigana() }
            }
            .disabled(isLoading || inputText.isEmpty)

            if !furiganaReadings.isEmpty {
                FuriganaTextView(readings: furiganaReadings, baseFont: .title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    private var geminiTTSSection: some View {
        section(title: "Gemini TTS（風格指令，需要登入）") {
            HStack {
                Text("語音")
                Spacer()
                Picker("語音", selection: $selectedGeminiVoice) {
                    ForEach(geminiVoices) { voice in
                        Text("\(voice.name)（\(voice.gender.label)）")
                            .tag(voice)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("風格預設")
                Spacer()
                Picker("風格預設", selection: $selectedPresetID) {
                    ForEach(promptPresets) { preset in
                        Text(preset.label).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPresetID) { _, newID in
                    if let preset = promptPresets.first(where: { $0.id == newID }) {
                        geminiPrompt = preset.value
                    }
                }
            }

            Text("指令內容")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $geminiPrompt)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            Button("產生 Gemini TTS") {
                Task { await loadGeminiTTS() }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)

            if !ttsStatus.isEmpty {
                Text(ttsStatus)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var standardTTSSection: some View {
        section(title: "Standard TTS（Wavenet，需要登入）") {
            Button("產生標準女聲") {
                Task { await loadStandardTTS(voice: standardFemaleVoice) }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)

            Button("產生標準男聲") {
                Task { await loadStandardTTS(voice: standardMaleVoice) }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)
        }
    }

    private var playerSection: some View {
        section(title: "音檔播放器") {
            AudioPlayerView(engine: player)
        }
    }

    private var downloadSection: some View {
        section(title: "下載音檔（按下後選擇儲存位置）") {
            Button("下載 Gemini TTS") {
                Task { await downloadGeminiTTS() }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)

            Button("下載標準女聲") {
                Task { await downloadStandardTTS(voice: standardFemaleVoice, label: "標準_女") }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)

            Button("下載標準男聲") {
                Task { await downloadStandardTTS(voice: standardMaleVoice, label: "標準_男") }
            }
            .disabled(isLoading || inputText.isEmpty || currentEmail == nil)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if !errorMessage.isEmpty {
            section(title: "錯誤") {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.system(.body, design: .monospaced))
            }
        }
        if isLoading {
            HStack {
                ProgressView()
                Text("執行中…")
            }
        }
    }

    // MARK: - Section Wrapper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
            Divider()
        }
    }

    // MARK: - Auth

    private func refreshAuthState() {
        currentEmail = FirebaseAuthService.shared.currentEmail
    }

    private func signInWithGoogle() async {
        resetMessages()
        do {
            let user = try await FirebaseAuthService.shared.signInWithGoogle()
            currentEmail = user.email
        } catch {
            errorMessage = "Google 登入失敗：\(error)"
        }
    }

    private func signInWithApple() async {
        resetMessages()
        do {
            let user = try await FirebaseAuthService.shared.signInWithApple()
            currentEmail = user.email
        } catch {
            errorMessage = "Apple 登入失敗：\(error)"
        }
    }

    private func signOut() {
        do {
            try FirebaseAuthService.shared.signOut()
            currentEmail = nil
        } catch {
            errorMessage = "登出失敗：\(error)"
        }
    }

    // MARK: - API Tests

    private func loadFurigana() async {
        resetMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            furiganaReadings = try await APIConfig.furiganaUseCase.annotate(text: inputText)
        } catch {
            errorMessage = "Furigana 失敗：\(error)"
        }
    }

    private func loadGeminiTTS() async {
        resetMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            var options = TTSOptions()
            options.voiceName = selectedGeminiVoice.name
            options.prompt = geminiPrompt.isEmpty ? nil : geminiPrompt
            let audioBase64 = try await APIConfig.ttsUseCase.synthesize(
                text: inputText,
                options: options
            )
            try playAudio(base64: audioBase64, sourceLabel: "Gemini")
        } catch {
            errorMessage = "Gemini TTS 失敗：\(error)"
        }
    }

    private func loadStandardTTS(voice: String) async {
        resetMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            var options = StandardTTSOptions()
            options.voiceName = voice
            let audioBase64 = try await APIConfig.ttsUseCase.synthesizeWord(
                text: inputText,
                options: options
            )
            try playAudio(base64: audioBase64, sourceLabel: "標準")
        } catch {
            errorMessage = "標準 TTS 失敗：\(error)"
        }
    }

    private func playAudio(base64: String, sourceLabel: String) throws {
        guard let data = Data(base64Encoded: base64) else {
            errorMessage = "\(sourceLabel) 失敗：base64 解碼失敗"
            return
        }
        ttsStatus = "音檔大小：\(data.count) bytes，已載入播放器"
        try player.load(data: data)
        player.play()
    }

    private func downloadGeminiTTS() async {
        resetMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            var options = TTSOptions()
            options.voiceName = selectedGeminiVoice.name
            options.prompt = geminiPrompt.isEmpty ? nil : geminiPrompt
            let audioBase64 = try await APIConfig.ttsUseCase.synthesize(
                text: inputText,
                options: options
            )
            guard let data = Data(base64Encoded: audioBase64) else {
                errorMessage = "下載失敗：base64 解碼失敗"
                return
            }
            let url = try writeTempAudio(data: data, label: "Gemini_\(selectedGeminiVoice.name)")
            shareItem = ShareItem(url: url)
        } catch {
            errorMessage = "下載失敗：\(error)"
        }
    }

    private func downloadStandardTTS(voice: String, label: String) async {
        resetMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            var options = StandardTTSOptions()
            options.voiceName = voice
            let audioBase64 = try await APIConfig.ttsUseCase.synthesizeWord(
                text: inputText,
                options: options
            )
            guard let data = Data(base64Encoded: audioBase64) else {
                errorMessage = "下載失敗：base64 解碼失敗"
                return
            }
            let url = try writeTempAudio(data: data, label: label)
            shareItem = ShareItem(url: url)
        } catch {
            errorMessage = "下載失敗：\(error)"
        }
    }

    /// 把音檔寫入暫存目錄，產生可分享的 URL
    /// - Parameters:
    ///   - data: WAV 音檔資料
    ///   - label: 人聲類別（如「標準_女」），用於檔名後綴
    /// - Returns: 暫存檔 URL
    private func writeTempAudio(data: Data, label: String) throws -> URL {
        let safeText = inputText
            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:"))
            .joined(separator: "_")
        let trimmed = String(safeText.prefix(20))
        let timestamp = Self.timestampFormatter.string(from: Date())
        let filename = "\(trimmed)_\(label)_\(timestamp).wav"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 檔名用日期格式（yyyy-MM-dd_HH-mm-ss）
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private func resetMessages() {
        errorMessage = ""
        ttsStatus = ""
    }
}

#Preview {
    APITestView()
}
