import Foundation
import FirebaseAuth
import GoogleSignIn

/// Firebase 認證服務
/// - Note: 管理 Google OAuth 登入 / 登出及使用者狀態
final class FirebaseAuthService {

    // MARK: - Singleton

    static let shared = FirebaseAuthService()
    private init() {}

    // MARK: - Properties

    /// 目前登入中的使用者
    var currentUser: User? {
        Auth.auth().currentUser
    }

    /// 目前使用者的 UID
    var currentUID: String? {
        currentUser?.uid
    }

    // MARK: - Actions

    /// 使用 Google 帳號登入
    /// - Parameter presentingViewController: 呈現登入畫面的 ViewController
    /// - Returns: 登入後的 Firebase User
    @discardableResult
    func signInWithGoogle(presentingViewController: Any) async throws -> User {
        // 取得 Google 登入憑證
        guard let windowScene = await MainActor.run(body: {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }),
        let rootViewController = await MainActor.run(body: {
            windowScene.windows.first?.rootViewController
        }) else {
            throw AuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }

    /// 登出
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// 取得目前使用者的 ID Token（用於 API 認證）
    /// - Returns: Firebase ID Token 字串
    func getIDToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthError.notSignedIn
        }
        return try await user.getIDToken()
    }
}

// MARK: - Error

/// 認證相關錯誤
enum AuthError: Error {
    /// 找不到根 ViewController
    case noRootViewController
    /// Google 登入缺少 ID Token
    case missingIDToken
    /// 使用者未登入
    case notSignedIn
}
