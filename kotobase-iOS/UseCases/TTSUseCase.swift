import Foundation

/// TTS 語音合成操作（含快取）
/// - Note: 整合 TTSAPIService 與 AudioCacheService，提供帶快取的語音合成功能
final class TTSUseCase {

    // MARK: - Properties

    private let ttsService: TTSAPIService
    private let audioCache: AudioCacheService
    private let authService: FirebaseAuthService

    // MARK: - Init

    /// - Parameters:
    ///   - ttsService: TTS API 服務
    ///   - audioCache: 音訊快取服務
    ///   - authService: 認證服務
    init(
        ttsService: TTSAPIService,
        audioCache: AudioCacheService = .shared,
        authService: FirebaseAuthService = .shared
    ) {
        self.ttsService = ttsService
        self.audioCache = audioCache
        self.authService = authService
    }

    // MARK: - Gemini TTS

    /// 使用 Gemini TTS 合成語音（帶快取）
    /// - Parameters:
    ///   - text: 要合成的文字
    ///   - languageCode: 語言代碼
    ///   - options: 語音選項
    /// - Returns: Base64 編碼的音訊資料
    func synthesize(
        text: String,
        languageCode: String = "ja-JP",
        options: TTSOptions = TTSOptions()
    ) async throws -> String {
        // 檢查快取
        let cacheKey = audioCache.makeKey(
            text: text,
            languageCode: languageCode,
            voiceName: options.voiceName,
            prompt: options.prompt ?? ""
        )

        if let cached = audioCache.get(key: cacheKey) {
            return cached
        }

        // 呼叫 API
        let idToken = try await authService.getIDToken()
        let response = try await ttsService.synthesizeSpeech(
            text: text,
            languageCode: languageCode,
            idToken: idToken,
            options: options
        )

        // 存入快取
        audioCache.set(key: cacheKey, base64Audio: response.audioContent)

        return response.audioContent
    }

    // MARK: - Standard TTS (Wavenet)

    /// 使用 Wavenet 合成單字發音（帶快取）
    /// - Parameters:
    ///   - text: 要合成的文字（通常為單字）
    ///   - languageCode: 語言代碼
    ///   - options: 語音選項
    /// - Returns: Base64 編碼的音訊資料
    func synthesizeWord(
        text: String,
        languageCode: String = "ja-JP",
        options: StandardTTSOptions = StandardTTSOptions()
    ) async throws -> String {
        // 檢查快取
        let cacheKey = audioCache.makeKey(
            text: text,
            languageCode: languageCode,
            voiceName: options.voiceName
        )

        if let cached = audioCache.get(key: cacheKey) {
            return cached
        }

        // 呼叫 API
        let idToken = try await authService.getIDToken()
        let response = try await ttsService.synthesizeStandardSpeech(
            text: text,
            languageCode: languageCode,
            idToken: idToken,
            options: options
        )

        // 存入快取
        audioCache.set(key: cacheKey, base64Audio: response.audioContent)

        return response.audioContent
    }
}
