import SwiftUI
import UIKit

extension Color {
    /// 品牌主色（青色），用於強調操作（FAB、連結、tint 等）
    static let brandCyan = Color(red: 0.31, green: 0.78, blue: 0.91)

    /// 從 Hex 字串建立 Color（支援 #RRGGBB / RRGGBB）
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// 轉成 `#RRGGBB` Hex 字串
    /// - Returns: 無法取得 RGB 分量時回傳 nil
    func toHex() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

/// 分類顏色色票
enum CategoryPalette {
    /// 預設色票（Hex），固定不變
    static let presets = [
        "#818cf8", "#f87171", "#fbbf24", "#34d399",
        "#60a5fa", "#f472b6", "#a78bfa", "#9ca3af"
    ]
}
