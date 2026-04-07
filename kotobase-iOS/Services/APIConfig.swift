import Foundation

/// API 環境設定
/// - Note: 集中管理所有 API 端點與相關常數
enum APIConfig {
    /// Cloud Run API 基礎 URL
    /// - Note: 正式環境請替換為實際的 Cloud Run URL
    static let baseURL = "https://your-cloud-run-url.run.app"

    /// TTS API 服務實例
    static let ttsService = TTSAPIService(baseURL: baseURL)

    /// 平假名標注 API 服務實例
    static let furiganaService = FuriganaAPIService(baseURL: baseURL)

    /// TTS UseCase 實例
    static let ttsUseCase = TTSUseCase(ttsService: ttsService)
}
