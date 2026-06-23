import Foundation

/// 平假名標注操作
/// - Note: 包裝 FuriganaAPIService，並套用 user override + JMdict 字典覆蓋層
///   覆蓋優先序（高 → 低）：
///   1. UserFuriganaOverride：使用者明確選擇的讀音
///   2. JMdict 單義詞：字典僅一個候選
///   3. Yahoo 原值：多義詞或字典未命中
struct FuriganaUseCase {

    // MARK: - Properties

    private let furiganaService: FuriganaAPIServicing
    private let overrideDictionary: FuriganaOverrideDictionarying

    // MARK: - Init

    /// - Parameters:
    ///   - furiganaService: Furigana API 服務（Yahoo / Cloud Functions）
    ///   - overrideDictionary: JMdict 字典覆蓋服務
    init(
        furiganaService: FuriganaAPIServicing,
        overrideDictionary: FuriganaOverrideDictionarying
    ) {
        self.furiganaService = furiganaService
        self.overrideDictionary = overrideDictionary
    }

    // MARK: - Actions

    /// 取得日文文字的原始平假名標注（未套用任何 override）
    /// - Parameter text: 要標注的日文文字
    /// - Returns: Yahoo 原始標注結果
    func fetchRawReadings(text: String) async throws -> [FuriganaReading] {
        try await furiganaService.fetchFurigana(text: text)
    }

    /// 對既有標注結果套用 user override + JMdict 覆蓋
    /// - Parameters:
    ///   - readings: 原始（Yahoo）標注結果
    ///   - userOverrides: 使用者自訂讀音表（surface → reading），可由 @Query 觀察 SwiftData 取得
    /// - Returns: 套用 override 後的標注結果
    func applyOverrides(
        to readings: [FuriganaReading],
        userOverrides: [String: String] = [:]
    ) async -> [FuriganaReading] {
        var result: [FuriganaReading] = []
        result.reserveCapacity(readings.count)

        for reading in readings {
            // 沒讀音的 token（純假名/標點）不處理
            guard let originalReading = reading.reading else {
                result.append(reading)
                continue
            }

            // 1. User override 最高優先
            if let userReading = userOverrides[reading.surface] {
                if userReading != originalReading {
                    #if DEBUG
                    print("[Furigana user] \(reading.surface)：Yahoo=\(originalReading) → User=\(userReading)")
                    #endif
                }
                result.append(FuriganaReading(surface: reading.surface, reading: userReading))
                continue
            }

            // 2. JMdict 字典查候選
            let candidates = await overrideDictionary.candidates(for: reading.surface)

            switch candidates.count {
            case 0:
                // 未命中，保留 Yahoo
                result.append(reading)

            case 1:
                // 單義詞：字典確定，安全覆蓋
                let override = candidates[0]
                guard override != originalReading else {
                    result.append(reading)
                    continue
                }
                #if DEBUG
                print("[Furigana jmdict] \(reading.surface)：Yahoo=\(originalReading) → JMdict=\(override)")
                #endif
                result.append(FuriganaReading(surface: reading.surface, reading: override))

            default:
                // 多義詞：保留 Yahoo，等使用者點擊選擇
                #if DEBUG
                if !candidates.contains(originalReading) {
                    print("[Furigana ambiguous] \(reading.surface)：Yahoo=\(originalReading) 不在候選中，候選=\(candidates)")
                }
                #endif
                result.append(reading)
            }
        }

        return result
    }

    /// 取得日文文字的平假名標注（已套用 user override + JMdict 覆蓋）
    /// - Parameters:
    ///   - text: 要標注的日文文字
    ///   - userOverrides: 使用者自訂讀音表
    /// - Returns: 標注結果陣列
    func annotate(
        text: String,
        userOverrides: [String: String] = [:]
    ) async throws -> [FuriganaReading] {
        let raw = try await fetchRawReadings(text: text)
        return await applyOverrides(to: raw, userOverrides: userOverrides)
    }

    /// 查詢指定漢字的所有候選讀音（給 sheet 用）
    /// - Parameter surface: 漢字表面形式
    /// - Returns: JMdict 提供的候選讀音陣列
    func candidates(for surface: String) async -> [String] {
        await overrideDictionary.candidates(for: surface)
    }
}
