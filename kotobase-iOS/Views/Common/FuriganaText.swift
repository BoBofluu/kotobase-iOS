import SwiftData
import SwiftUI

/// 自動抓取平假名標注的文字 view
/// - Note: 傳入日文純文字，view 內部呼叫 `FuriganaUseCase` 取得標注後渲染為 `FuriganaTextView`
///   - 使用者讀音修正僅在「同段文字內」生效（透過 contextHash 隔離）
///   - 漢字 token 點擊會 present `KanjiActionSheet`，提供朗讀 / 修正讀音
struct FuriganaText: View {

    // MARK: - Properties

    /// 要標注的日文文字
    let text: String

    /// 漢字主字體
    var baseFont: Font = .body

    /// 平假名字體大小（pt）
    var rubyFontSize: CGFloat = 11

    /// 平假名顏色
    var rubyColor: Color = Color(red: 0.506, green: 0.549, blue: 0.965)

    /// Furigana 操作（預設使用 `APIConfig` 內的單例）
    var useCase: FuriganaUseCase = APIConfig.furiganaUseCase

    /// 漢字點擊功能是否啟用（某些場景如預覽純展示時可關閉）
    var enableKanjiTap: Bool = true

    // MARK: - SwiftData

    /// 文字 hash（用於過濾僅屬於這段文字的修正）
    private let contextHash: String

    /// 屬於這段文字的使用者修正（@Query 自動觀察變化）
    @Query private var overrides: [UserFuriganaOverride]

    // MARK: - State

    @State private var rawReadings: [FuriganaReading] = []
    @State private var readings: [FuriganaReading] = []
    @State private var isLoading: Bool = false
    @State private var tappedKanji: TappedKanji?

    // MARK: - Init

    /// - Parameters:
    ///   - text: 要標注的日文文字
    ///   - baseFont: 漢字主字體
    ///   - rubyFontSize: 平假名字體大小（pt）
    ///   - rubyColor: 平假名顏色
    ///   - useCase: Furigana 操作
    ///   - enableKanjiTap: 漢字點擊功能是否啟用
    init(
        text: String,
        baseFont: Font = .body,
        rubyFontSize: CGFloat = 11,
        rubyColor: Color = Color(red: 0.506, green: 0.549, blue: 0.965),
        useCase: FuriganaUseCase = APIConfig.furiganaUseCase,
        enableKanjiTap: Bool = true
    ) {
        self.text = text
        self.baseFont = baseFont
        self.rubyFontSize = rubyFontSize
        self.rubyColor = rubyColor
        self.useCase = useCase
        self.enableKanjiTap = enableKanjiTap

        let hash = text.sha256Hex
        self.contextHash = hash
        _overrides = Query(filter: #Predicate<UserFuriganaOverride> { $0.contextHash == hash })
    }

    // MARK: - Derived

    /// 當前文字的 override 字典（給 UseCase 用）
    private var overrideMap: [String: String] {
        Dictionary(
            overrides.map { ($0.surface, $0.reading) },
            uniquingKeysWith: { _, new in new }
        )
    }

    /// 觀察用簽名:override 內容變動時觸發 reapply
    private var overrideSignature: String {
        overrides
            .map { "\($0.surface)=\($0.reading)" }
            .sorted()
            .joined(separator: ",")
    }

    /// 漢字 tap handler(關閉時為 nil)
    /// - Note: 拆出明確型別避免 Swift type-checker 在三元運算內 timeout
    private var tapHandler: ((FuriganaReading) -> Void)? {
        guard enableKanjiTap else { return nil }
        return handleKanjiTap
    }

    // MARK: - Body

    var body: some View {
        contentView
            .task(id: text) { await loadRaw() }
            .onChange(of: overrideSignature) { _, _ in
                Task { await reapply() }
            }
            .sheet(item: $tappedKanji) { tap in
                KanjiActionSheet(
                    contextHash: contextHash,
                    surface: tap.surface,
                    currentReading: tap.currentReading
                )
                .presentationDetents([.medium, .large])
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
        } else if readings.isEmpty {
            Text(text).font(baseFont)
        } else {
            FuriganaTextView(
                readings: readings,
                baseFont: baseFont,
                rubyFontSize: rubyFontSize,
                rubyColor: rubyColor,
                onKanjiTap: tapHandler
            )
        }
    }

    // MARK: - Actions

    /// 從 API 抓取原始標注並套用 override
    private func loadRaw() async {
        guard !text.isEmpty else {
            rawReadings = []
            readings = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let raw = try await useCase.fetchRawReadings(text: text)
            rawReadings = raw
            readings = await useCase.applyOverrides(to: raw, userOverrides: overrideMap)
        } catch {
            let fallback = [FuriganaReading(surface: text, reading: nil)]
            rawReadings = fallback
            readings = fallback
        }
    }

    /// 對既有 raw readings 重新套用 override（使用者修正讀音時觸發）
    private func reapply() async {
        guard !rawReadings.isEmpty else { return }
        readings = await useCase.applyOverrides(to: rawReadings, userOverrides: overrideMap)
    }

    /// 漢字 token 被點擊：包成 sheet item 觸發 present
    private func handleKanjiTap(_ token: FuriganaReading) {
        guard let reading = token.reading else { return }
        tappedKanji = TappedKanji(surface: token.surface, currentReading: reading)
    }
}

// MARK: - Sheet Item

/// `sheet(item:)` 用的點擊資訊
/// - Note: 不直接擴展 `FuriganaReading` 為 Identifiable，避免 DTO 沾染 UI 邊界
private struct TappedKanji: Identifiable {
    let id = UUID()
    let surface: String
    let currentReading: String
}

// MARK: - Preview

#Preview {
    FuriganaText(text: "今日は良い天気ですね。", baseFont: .title2)
        .padding()
        .modelContainer(for: UserFuriganaOverride.self, inMemory: true)
}
