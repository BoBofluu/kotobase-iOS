import CryptoKit
import Foundation

/// 字串雜湊輔助
extension String {

    /// 回傳 UTF-8 內容的 SHA256 hex 字串
    /// - Note: 用於 `UserFuriganaOverride.contextHash`，將任意長度的原文轉成固定長度 key
    var sha256Hex: String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
