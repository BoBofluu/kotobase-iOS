import Foundation

/// TTS 語音合成操作（含快取與下載）
/// - Note: 整合 TTSAPIService、AudioCacheService 與 IDTokenProviding，提供帶快取的語音合成、以及音檔下載
struct TTSUseCase {

    // MARK: - Properties

    private let ttsService: TTSAPIServicing
    private let audioCache: AudioCaching
    private let tokenProvider: IDTokenProviding

    // MARK: - Init

    init(
        ttsService: TTSAPIServicing,
        audioCache: AudioCaching = AudioCacheService.shared,
        tokenProvider: IDTokenProviding = FirebaseAuthService.shared
    ) {
        self.ttsService = ttsService
        self.audioCache = audioCache
        self.tokenProvider = tokenProvider
    }

    // MARK: - Gemini TTS

    /// 使用 Gemini TTS 合成語音（帶快取）
    /// - Returns: Base64 編碼的音訊資料
    func synthesize(
        text: String,
        languageCode: String = "ja-JP",
        options: TTSOptions = TTSOptions()
    ) async throws -> String {
        let cacheKey = audioCache.makeKey(
            text: text,
            languageCode: languageCode,
            voiceName: options.voiceName,
            prompt: options.prompt ?? ""
        )

        if let cached = audioCache.get(key: cacheKey) {
            return cached
        }

        let idToken = try await tokenProvider.getIDToken(forceRefresh: false)
        let response = try await ttsService.synthesizeSpeech(
            text: text,
            languageCode: languageCode,
            idToken: idToken,
            options: options
        )

        audioCache.set(key: cacheKey, base64Audio: response.audioContent)
        return response.audioContent
    }

    // MARK: - Standard TTS (Wavenet)

    /// 使用 Wavenet 合成單字發音（帶快取）
    /// - Returns: Base64 編碼的音訊資料
    func synthesizeWord(
        text: String,
        languageCode: String = "ja-JP",
        options: StandardTTSOptions = StandardTTSOptions()
    ) async throws -> String {
        let cacheKey = audioCache.makeKey(
            text: text,
            languageCode: languageCode,
            voiceName: options.voiceName,
            prompt: ""
        )

        if let cached = audioCache.get(key: cacheKey) {
            return cached
        }

        let idToken = try await tokenProvider.getIDToken(forceRefresh: false)
        let response = try await ttsService.synthesizeStandardSpeech(
            text: text,
            languageCode: languageCode,
            idToken: idToken,
            options: options
        )

        audioCache.set(key: cacheKey, base64Audio: response.audioContent)
        return response.audioContent
    }

}
