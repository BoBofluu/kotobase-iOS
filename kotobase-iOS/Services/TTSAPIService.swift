import Foundation

/// TTS 語音合成 API 服務
/// - Note: 對應 Web 版 ttsApi.js，呼叫 Cloud Run 上的 /tts 與 /tts-standard 端點
struct TTSAPIService {

    // MARK: - Constants

    /// API 基礎 URL（從環境設定讀取，或使用預設值）
    private let baseURL: String

    /// 文字最大長度
    static let maxTextLength = 20_000

    // MARK: - Init

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    // MARK: - Gemini TTS

    /// 使用 Gemini 2.5 Flash 合成語音
    /// - Parameters:
    ///   - text: 要合成的文字（最長 20,000 字元）
    ///   - languageCode: 語言代碼（例：ja-JP）
    ///   - idToken: Firebase ID Token
    ///   - options: 語音選項
    /// - Returns: Base64 編碼的音訊資料
    func synthesizeSpeech(
        text: String,
        languageCode: String,
        idToken: String,
        options: TTSOptions = TTSOptions()
    ) async throws -> TTSResponse {
        let url = try buildURL(path: "/tts")

        var body: [String: Any] = [
            "text": String(text.prefix(Self.maxTextLength)),
            "languageCode": languageCode,
            "voiceName": options.voiceName,
            "speakingRate": options.speakingRate,
            "pitch": options.pitch
        ]
        if let prompt = options.prompt {
            body["prompt"] = String(prompt.prefix(500))
        }

        let data = try await postRequest(url: url, body: body, idToken: idToken)
        return try JSONDecoder().decode(TTSResponse.self, from: data)
    }

    // MARK: - Standard TTS (Wavenet)

    /// 使用 Google Cloud Wavenet 合成語音（用於單字發音）
    /// - Parameters:
    ///   - text: 要合成的文字
    ///   - languageCode: 語言代碼
    ///   - idToken: Firebase ID Token
    ///   - options: 語音選項
    /// - Returns: Base64 編碼的音訊資料
    func synthesizeStandardSpeech(
        text: String,
        languageCode: String,
        idToken: String,
        options: StandardTTSOptions = StandardTTSOptions()
    ) async throws -> TTSResponse {
        let url = try buildURL(path: "/tts-standard")

        let body: [String: Any] = [
            "text": String(text.prefix(Self.maxTextLength)),
            "languageCode": languageCode,
            "voiceName": options.voiceName,
            "speakingRate": options.speakingRate,
            "pitch": options.pitch
        ]

        let data = try await postRequest(url: url, body: body, idToken: idToken)
        return try JSONDecoder().decode(TTSResponse.self, from: data)
    }

    // MARK: - Voices

    /// 取得可用語音列表
    /// - Returns: 語音與語言列表
    func getVoices() async throws -> VoicesResponse {
        let url = try buildURL(path: "/voices")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(VoicesResponse.self, from: data)
    }

    // MARK: - Private

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw TTSError.invalidURL
        }
        return url
    }

    private func postRequest(url: URL, body: [String: Any], idToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TTSError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Options

/// Gemini TTS 語音選項
struct TTSOptions {
    /// 語音名稱（預設：Achernar）
    var voiceName: String = "Achernar"
    /// 語速（0.25 ~ 4.0）
    var speakingRate: Double = 1.0
    /// 音高（-20 ~ 20）
    var pitch: Double = 0
    /// 語音提示詞（選填，最長 500 字元）
    var prompt: String?
}

/// Wavenet 標準 TTS 語音選項
struct StandardTTSOptions {
    /// 語音名稱（預設：ja-JP-Wavenet-A，女聲）
    var voiceName: String = "ja-JP-Wavenet-A"
    /// 語速
    var speakingRate: Double = 1.0
    /// 音高
    var pitch: Double = 0
}

// MARK: - Response

/// TTS API 回應
struct TTSResponse: Decodable {
    /// Base64 編碼的音訊內容
    let audioContent: String
    /// 剩餘配額（僅 Gemini TTS）
    let remaining: Int?
    /// 配額上限（僅 Gemini TTS）
    let limit: Int?
}

/// 語音列表回應
struct VoicesResponse: Decodable {
    let voices: [VoiceInfo]
    let languages: [LanguageInfo]
}

/// 語音資訊
struct VoiceInfo: Decodable {
    let name: String
    let languageCodes: [String]?
    let ssmlGender: String?
}

/// 語言資訊
struct LanguageInfo: Decodable {
    let code: String
    let name: String?
}

// MARK: - Error

/// TTS 相關錯誤
enum TTSError: Error {
    /// URL 格式錯誤
    case invalidURL
    /// 回應格式錯誤
    case invalidResponse
    /// HTTP 錯誤
    case httpError(statusCode: Int)
    /// 文字超過長度限制
    case textTooLong
}
