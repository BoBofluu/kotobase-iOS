import SwiftUI

/// 自動抓取平假名標注的文字 view
/// - Note: 傳入日文純文字，view 內部呼叫 `FuriganaUseCase` 取得標注後渲染為 `FuriganaTextView`
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

    @State private var readings: [FuriganaReading] = []
    @State private var isLoading: Bool = false

    // MARK: - Body

    var body: some View {
        contentView
            .task(id: text) { await load() }
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
                rubyColor: rubyColor
            )
        }
    }

    // MARK: - Actions

    /// 抓取平假名標注；失敗時 fallback 為純文字
    private func load() async {
        guard !text.isEmpty else {
            readings = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            readings = try await useCase.annotate(text: text)
        } catch {
            readings = [FuriganaReading(surface: text, reading: nil)]
        }
    }
}

// MARK: - Preview

#Preview {
    FuriganaText(text: "今日は良い天気ですね。", baseFont: .title2)
        .padding()
}
