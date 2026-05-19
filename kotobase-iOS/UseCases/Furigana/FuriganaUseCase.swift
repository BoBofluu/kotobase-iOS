import Foundation

/// 平假名標注操作
/// - Note: 包裝 FuriganaAPIService，預留快取與限流的擴充點
struct FuriganaUseCase {

    // MARK: - Properties

    private let furiganaService: FuriganaAPIServicing

    // MARK: - Init

    /// - Parameter furiganaService: Furigana API 服務
    init(furiganaService: FuriganaAPIServicing) {
        self.furiganaService = furiganaService
    }

    // MARK: - Actions

    /// 取得日文文字的平假名標注
    /// - Parameter text: 要標注的日文文字
    /// - Returns: 標注結果陣列
    func annotate(text: String) async throws -> [FuriganaReading] {
        try await furiganaService.fetchFurigana(text: text)
    }
}
