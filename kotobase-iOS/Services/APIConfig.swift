import Foundation
import SwiftData

/// API 環境設定 / 依賴注入入口
/// - Note: 集中管理 API 端點、Service 單例、UseCase 工廠。測試時可替換為 Mock Protocol 實作。
enum APIConfig {

    // MARK: - Endpoints

    /// Cloud Functions API 基礎 URL
    /// - Note: Firebase Cloud Functions（asia-east1，project: japanese-study-speaker）
    static let baseURL = "https://asia-east1-japanese-study-speaker.cloudfunctions.net/api"

    // MARK: - Services（Protocol 型別，方便替換）

    /// TTS API 服務
    static let ttsService: TTSAPIServicing = TTSAPIService(baseURL: baseURL)

    /// 平假名標注 API 服務
    static let furiganaService: FuriganaAPIServicing = FuriganaAPIService(baseURL: baseURL)

    /// 平假名標注字典覆蓋服務（JMdict）
    /// - Note: 修正 Yahoo 偶爾的錯誤讀音（資料來源：JmdictFurigana.txt）
    static let furiganaOverrideDictionary: FuriganaOverrideDictionarying = FuriganaOverrideDictionary()

    /// 認證服務
    static let authService: AuthServicing = FirebaseAuthService.shared

    /// Firestore 服務
    static let firestoreService: FirestoreServicing = FirestoreService.shared

    /// 音訊快取服務
    static let audioCache: AudioCaching = AudioCacheService.shared

    // MARK: - UseCases（Stateless，可直接共用）

    /// TTS UseCase（含快取與認證）
    static let ttsUseCase = TTSUseCase(
        ttsService: ttsService,
        audioCache: audioCache,
        tokenProvider: authService
    )

    /// Furigana UseCase（含 JMdict 覆蓋層）
    static let furiganaUseCase = FuriganaUseCase(
        furiganaService: furiganaService,
        overrideDictionary: furiganaOverrideDictionary
    )

    // MARK: - UseCase Factories（需注入 ModelContext）

    /// 建立 WordUseCase（需要當前 ModelContext）
    static func makeWordUseCase(context: ModelContext) -> WordUseCase {
        WordUseCase(modelContext: context)
    }

    /// 建立 CategoryUseCase（需要當前 ModelContext）
    static func makeCategoryUseCase(context: ModelContext) -> CategoryUseCase {
        CategoryUseCase(modelContext: context)
    }

    /// 建立 PaletteUseCase（需要當前 ModelContext）
    static func makePaletteUseCase(context: ModelContext) -> PaletteUseCase {
        PaletteUseCase(modelContext: context)
    }

    /// 建立 CloudSyncUseCase（需要當前 ModelContext）
    static func makeCloudSyncUseCase(context: ModelContext) -> CloudSyncUseCase {
        CloudSyncUseCase(
            modelContext: context,
            firestoreService: firestoreService,
            authSession: authService
        )
    }
}
