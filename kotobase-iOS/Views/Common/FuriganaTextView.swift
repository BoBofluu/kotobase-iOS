import SwiftUI

/// 平假名標注顯示 view
/// - Note: 將 `[FuriganaReading]` 排版成「平假名置於漢字上方」的樣式，並支援自動換行
///   有讀音的 token（漢字）可選擇接收點擊回呼以開啟漢字操作 sheet
struct FuriganaTextView: View {

    // MARK: - Properties

    /// 標注 token 序列
    let readings: [FuriganaReading]

    /// 漢字主字體
    var baseFont: Font = .body

    /// 平假名字體大小（單位 pt）
    var rubyFontSize: CGFloat = 11

    /// 平假名顏色
    var rubyColor: Color = Color(red: 0.506, green: 0.549, blue: 0.965)

    /// token 之間的水平間距
    var tokenSpacing: CGFloat = 1

    /// 換行時的行距
    var lineSpacing: CGFloat = 6

    /// 平假名與漢字之間的垂直間距
    var rubyGap: CGFloat = 2

    /// 漢字 token 被點擊時的回呼（nil 時不啟用點擊）
    var onKanjiTap: ((FuriganaReading) -> Void)? = nil

    // MARK: - Body

    var body: some View {
        FuriganaFlowLayout(spacing: tokenSpacing, lineSpacing: lineSpacing) {
            ForEach(Array(readings.enumerated()), id: \.offset) { _, token in
                FuriganaTokenView(
                    token: token,
                    baseFont: baseFont,
                    rubyFontSize: rubyFontSize,
                    rubyColor: rubyColor,
                    rubyGap: rubyGap,
                    onTap: onKanjiTap
                )
            }
        }
    }
}

// MARK: - Token

/// 單一 token 的顯示（平假名 + 原文垂直堆疊）
private struct FuriganaTokenView: View {

    let token: FuriganaReading
    let baseFont: Font
    let rubyFontSize: CGFloat
    let rubyColor: Color
    let rubyGap: CGFloat
    let onTap: ((FuriganaReading) -> Void)?

    /// 是否可點擊：有讀音（漢字 token）且有 callback 才啟用
    private var isTappable: Bool {
        token.reading != nil && onTap != nil
    }

    var body: some View {
        VStack(spacing: rubyGap) {
            Text(token.reading ?? " ")
                .font(.system(size: rubyFontSize))
                .foregroundStyle(token.reading == nil ? .clear : rubyColor)
                .lineLimit(1)
                .fixedSize()
            Text(token.surface)
                .font(baseFont)
                .lineLimit(1)
                .fixedSize()
        }
        .contentShape(.rect)
        .onTapGesture {
            guard isTappable, let onTap else { return }
            onTap(token)
        }
    }
}

// MARK: - Layout

/// 將 subviews 由左至右排列，超出寬度時換行
private struct FuriganaFlowLayout: Layout {

    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        return arrangement(of: subviews, maxWidth: maxWidth).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let layout = arrangement(of: subviews, maxWidth: bounds.width)
        for (index, point) in layout.positions.enumerated() {
            let origin = CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y)
            subviews[index].place(at: origin, proposal: .unspecified)
        }
    }

    /// 計算所有 subview 的位置與整體尺寸
    /// - Parameters:
    ///   - subviews: 子 view 集合
    ///   - maxWidth: 最大可用寬度
    /// - Returns: 整體尺寸與每個子 view 左上角座標
    private func arrangement(
        of subviews: Subviews,
        maxWidth: CGFloat
    ) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsWrap = cursorX > 0 && cursorX + size.width > maxWidth
            if needsWrap {
                cursorX = 0
                cursorY += currentLineHeight + lineSpacing
                currentLineHeight = 0
            }
            positions.append(CGPoint(x: cursorX, y: cursorY))
            cursorX += size.width + spacing
            currentLineHeight = max(currentLineHeight, size.height)
            maxRowWidth = max(maxRowWidth, cursorX - spacing)
        }

        return (CGSize(width: maxRowWidth, height: cursorY + currentLineHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    FuriganaTextView(
        readings: [
            FuriganaReading(surface: "今日", reading: "きょう"),
            FuriganaReading(surface: "は", reading: nil),
            FuriganaReading(surface: "良", reading: "よ"),
            FuriganaReading(surface: "い", reading: nil),
            FuriganaReading(surface: "天気", reading: "てんき"),
            FuriganaReading(surface: "ですね。", reading: nil)
        ],
        baseFont: .title2
    )
    .padding()
}
