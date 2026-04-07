import Foundation

/// 平假名標注 API 服務
/// - Note: 對應 Web 版 ttsApi.js 中的 fetchFurigana，呼叫 Cloud Run 的 /furigana 端點
struct FuriganaAPIService {

    // MARK: - Constants

    private let baseURL: String

    // MARK: - Init

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    // MARK: - Actions

    /// 取得日文文字的平假名標注
    /// - Parameter text: 要標注的日文文字（最長 20,000 字元）
    /// - Returns: 標注結果陣列
    func fetchFurigana(text: String) async throws -> [FuriganaReading] {
        guard let url = URL(string: baseURL + "/furigana") else {
            throw FuriganaError.invalidURL
        }

        let sanitized = sanitizeForFurigana(text)
        guard !sanitized.isEmpty else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": String(sanitized.prefix(TTSAPIService.maxTextLength))
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FuriganaError.requestFailed
        }

        let decoded = try JSONDecoder().decode(FuriganaResponse.self, from: data)
        return decoded.readings
    }

    // MARK: - Private

    /// 移除會導致 Yahoo API 失敗的特殊字元
    /// - Parameter text: 原始文字
    /// - Returns: 清理後的文字
    private func sanitizeForFurigana(_ text: String) -> String {
        // 移除各種破折號
        var result = text
        let dashPattern = "[—–―─\u{2015}\u{2500}\u{2012}\u{2013}\u{2014}]"
        if let regex = try? NSRegularExpression(pattern: dashPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // 移除控制字元
        let controlPattern = "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]"
        if let regex = try? NSRegularExpression(pattern: controlPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Response

/// 平假名標注 API 回應
struct FuriganaResponse: Decodable {
    let readings: [FuriganaReading]
}

/// 單一標注結果
struct FuriganaReading: Decodable {
    /// 原文表面形式
    let surface: String
    /// 平假名讀音（漢字以外為 nil）
    let reading: String?
}

// MARK: - Error

/// 平假名標注相關錯誤
enum FuriganaError: Error {
    /// URL 格式錯誤
    case invalidURL
    /// 請求失敗
    case requestFailed
}
