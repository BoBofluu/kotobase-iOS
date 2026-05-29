import SwiftUI
import UIKit

extension View {
    /// 點擊輸入框以外任何位置時平順收起鍵盤（仿 IQKeyboardManager 的 touch-outside 行為）
    /// - Note: 在 window 掛上 tap recognizer，不攔截原本點擊（按鈕、下拉等照常作用），
    ///   點在 `UITextField` / `UITextView` 上則不收，讓其正常聚焦。
    func dismissKeyboardOnTapOutside() -> some View {
        background(KeyboardDismissInstaller())
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.onAttachToWindow = { [weak coordinator = context.coordinator] window in
            coordinator?.install(on: window)
        }
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 真正掛上 window 時才回呼安裝手勢（比 makeUIView 內取 window 可靠）
    final class InstallerView: UIView {
        var onAttachToWindow: ((UIWindow) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window {
                onAttachToWindow?(window)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var tap: UITapGestureRecognizer?

        /// 在 window 安裝收鍵盤的 tap recognizer（只裝一次）
        func install(on window: UIWindow) {
            guard tap == nil else { return }
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.window = window
            self.tap = recognizer
        }

        @objc private func handleTap() {
            window?.endEditing(true)
        }

        // 與其他手勢（scroll、按鈕點擊等）並存，不互斥
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // 點在輸入元件上時不觸發收鍵盤，讓它正常聚焦
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UITextField || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }
    }
}
