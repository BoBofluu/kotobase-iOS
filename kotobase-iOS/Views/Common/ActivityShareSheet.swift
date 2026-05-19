import SwiftUI
import UIKit

/// 系統分享 sheet 的 SwiftUI 包裝
/// - Note: 任何畫面要程式化彈出 share sheet（含「儲存到檔案」）都可用 `.sheet(item:)` 配合本 view
struct ActivityShareSheet: UIViewControllerRepresentable {

    /// 要分享的項目（URL、字串、圖片皆可）
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
