import SwiftUI
import UIKit
import VisionKit

// MARK: - Live Text 圖片視圖（可縮放 + 原生長按選字）

/// 包裝 `ImageAnalysisInteraction`，提供原生 Live Text 文字選取，並支援捏合縮放
struct LiveTextImageView: UIViewRepresentable {

    let image: UIImage
    /// 文字分析完成後回呼，交出 interaction 供外部取選取/全文
    let onReady: (ImageAnalysisInteraction) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        let interaction = ImageAnalysisInteraction()
        imageView.addInteraction(interaction)

        context.coordinator.imageView = imageView
        context.coordinator.analyze(image: image, interaction: interaction, onReady: onReady)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        private let analyzer = ImageAnalyzer()

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        /// 對圖片做文字分析，完成後設定到 interaction 並回呼
        func analyze(
            image: UIImage,
            interaction: ImageAnalysisInteraction,
            onReady: @escaping (ImageAnalysisInteraction) -> Void
        ) {
            Task { @MainActor in
                let configuration = ImageAnalyzer.Configuration([.text])
                guard let analysis = try? await analyzer.analyze(image, configuration: configuration) else {
                    onReady(interaction)
                    return
                }
                interaction.analysis = analysis
                interaction.preferredInteractionTypes = .textSelection
                onReady(interaction)
            }
        }
    }
}

// MARK: - 圖片編輯頁

/// 圖片放大編輯頁：縮放、長按選字、匯入文字到內容
struct PhotoEditorView: View {

    let image: UIImage
    /// 匯入文字回呼（傳回要併入內容的文字）
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var interaction: ImageAnalysisInteraction?
    @State private var hasRecognizedText = false
    @State private var isAnalyzing = true
    @State private var hintMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                LiveTextImageView(image: image) { interaction in
                    self.interaction = interaction
                    self.isAnalyzing = false
                    self.hasRecognizedText = !(interaction.analysis?.transcript.isEmpty ?? true)
                }

                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else if !hasRecognizedText {
                    Text("未偵測到文字")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(.black.opacity(0.5), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("圖片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("匯入選取的文字", action: importSelected)
                        Button("全部匯入", action: importAll)
                    } label: {
                        Text("匯入文字")
                    }
                    .disabled(!hasRecognizedText)
                }
            }
            .alert("提示", isPresented: Binding(
                get: { hintMessage != nil },
                set: { if !$0 { hintMessage = nil } }
            )) {
                Button("確定", role: .cancel) { hintMessage = nil }
            } message: {
                Text(hintMessage ?? "")
            }
        }
    }

    private func importSelected() {
        let selected = interaction?.selectedText ?? ""
        guard !selected.isEmpty else {
            hintMessage = "請先長按圖片選取文字"
            return
        }
        // 先關閉再回傳，避免關閉瞬間父層 content 變動導致 sheet 重建與 VisionKit 拆除衝突
        dismiss()
        DispatchQueue.main.async {
            onImport(selected)
        }
    }

    private func importAll() {
        let all = interaction?.analysis?.transcript ?? ""
        guard !all.isEmpty else {
            hintMessage = "未偵測到文字"
            return
        }
        dismiss()
        DispatchQueue.main.async {
            onImport(all)
        }
    }
}
