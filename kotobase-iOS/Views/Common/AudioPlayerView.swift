import SwiftUI

/// 通用音檔播放器 UI
/// - Note: 由外部注入 `AudioPlayerEngine`，提供可點擊跳轉的進度條、播放/暫停、停止
struct AudioPlayerView: View {

    // MARK: - Properties

    /// 共享的播放引擎
    @Bindable var engine: AudioPlayerEngine

    /// 拖曳/點擊中的暫存秒數（手放開才 seek，避免 timer 與使用者輸入打架）
    @State private var draggingValue: TimeInterval?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            scrubber
            timeRow
            controlRow
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Subviews

    private var scrubber: some View {
        SeekSlider(
            currentValue: engine.currentTime,
            range: 0...max(engine.duration, 0.01),
            draggingValue: $draggingValue,
            onCommit: { engine.seek(to: $0) }
        )
        .disabled(!engine.isLoaded)
    }

    private var timeRow: some View {
        HStack {
            Text(format(draggingValue ?? engine.currentTime))
            Spacer()
            Text(format(engine.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var controlRow: some View {
        HStack(spacing: 32) {
            Button(action: togglePlayPause) {
                Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .disabled(!engine.isLoaded)

            Button(action: engine.stop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 44))
            }
            .disabled(!engine.isLoaded)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func togglePlayPause() {
        if engine.isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
    }

    // MARK: - Format

    /// 將秒數格式化為 `m:ss`
    /// - Parameter time: 秒數
    /// - Returns: 顯示字串
    private func format(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - SeekSlider

/// 可點擊跳轉的進度條
/// - Note: 點擊軌道任何位置即直接跳到該點；拖曳期間只更新 `draggingValue`，放手才呼叫 `onCommit`
private struct SeekSlider: View {

    let currentValue: Double
    let range: ClosedRange<Double>
    @Binding var draggingValue: Double?
    let onCommit: (Double) -> Void

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let display = draggingValue ?? currentValue
            let progress = ratio(for: display)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: progress * width, height: trackHeight)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: progress * width - knobSize / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        draggingValue = value(forX: drag.location.x, width: width)
                    }
                    .onEnded { drag in
                        let final = value(forX: drag.location.x, width: width)
                        draggingValue = nil
                        onCommit(final)
                    }
            )
        }
        .frame(height: max(knobSize, trackHeight) + 8)
    }

    /// 計算進度比例（0 ~ 1）
    /// - Parameter value: 當前數值
    /// - Returns: 對應比例
    private func ratio(for value: Double) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let raw = (value - range.lowerBound) / span
        return CGFloat(min(max(raw, 0), 1))
    }

    /// 由觸碰 x 座標反算對應數值
    /// - Parameters:
    ///   - x: 觸碰點 x 座標
    ///   - width: 軌道總寬
    /// - Returns: 對應的數值
    private func value(forX x: CGFloat, width: CGFloat) -> Double {
        let clamped = min(max(x, 0), width)
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + Double(clamped / width) * span
    }
}

#Preview {
    AudioPlayerView(engine: AudioPlayerEngine())
        .padding()
}
