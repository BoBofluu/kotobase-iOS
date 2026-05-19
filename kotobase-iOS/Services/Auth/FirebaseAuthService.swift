import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import GoogleSignIn
import UIKit

/// 提供 Firebase ID Token 的能力（給 UseCase 注入用）
protocol IDTokenProviding {
    func getIDToken(forceRefresh: Bool) async throws -> String
}

/// 認證狀態查詢能力（給 UseCase 注入用）
protocol AuthSessionProviding {
    /// 目前登入的 UID，未登入為 nil
    var currentUID: String? { get }
    /// 目前登入的 email，未登入或匿名為 nil
    var currentEmail: String? { get }
    /// 是否已登入
    var isSignedIn: Bool { get }
}

/// 認證服務總介面（登入、登出、Token、Session）
protocol AuthServicing: IDTokenProviding, AuthSessionProviding {
    @discardableResult
    func signInWithGoogle() async throws -> AuthUserInfo
    @discardableResult
    func signInWithApple() async throws -> AuthUserInfo
    func signOut() throws
}

/// 抽象過後的登入使用者資訊（避免 UseCase 依賴 FirebaseAuth.User）
struct AuthUserInfo {
    let uid: String
    let email: String?
    let displayName: String?
}

/// Firebase 認證服務
/// - Note: 管理 Google / Apple 登入、登出與 ID Token 取得
final class FirebaseAuthService: NSObject, AuthServicing {

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Singleton

    static let shared = FirebaseAuthService()
    private override init() { super.init() }

    // MARK: - Properties

    var currentUser: User? { Auth.auth().currentUser }
    var currentUID: String? { currentUser?.uid }
    var currentEmail: String? { currentUser?.email }

    /// Sign in with Apple 用的暫存 nonce
    private var currentNonce: String?
    /// Apple 登入回呼 continuation
    private var appleSignInContinuation: CheckedContinuation<User, Error>?

    // MARK: - Google

    @discardableResult
    func signInWithGoogle() async throws -> AuthUserInfo {
        let rootVC = await MainActor.run { Self.topViewController() }
        guard let rootVC else { throw AuthError.noRootViewController }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return Self.mapUser(authResult.user)
    }

    // MARK: - Apple

    @discardableResult
    func signInWithApple() async throws -> AuthUserInfo {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        let user: User = try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            controller.performRequests()
        }
        return Self.mapUser(user)
    }

    /// 將 FirebaseAuth.User 映射為抽象 AuthUserInfo
    private static func mapUser(_ user: User) -> AuthUserInfo {
        AuthUserInfo(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName
        )
    }

    // MARK: - Sign Out / Token

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func getIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    // MARK: - Helpers

    @MainActor
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(base: presented) }
        return root
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("SecRandomCopyBytes failed: \(status)") }
            for r in randoms where remaining > 0 {
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension FirebaseAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            appleSignInContinuation?.resume(throwing: AuthError.missingIDToken)
            appleSignInContinuation = nil
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let continuation = appleSignInContinuation
        appleSignInContinuation = nil
        currentNonce = nil

        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                continuation?.resume(returning: result.user)
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
        currentNonce = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension FirebaseAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.compactMap(\.keyWindow).first {
            return keyWindow
        }
        guard let scene = scenes.first else {
            preconditionFailure("No active UIWindowScene for Apple Sign-In presentation anchor")
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}

// MARK: - Error

enum AuthError: Error {
    case noRootViewController
    case missingIDToken
    case notSignedIn
}
