import AVFoundation
import Foundation

/// 音檔播放引擎
/// - Note: 包裝 `AVAudioPlayer`，將播放狀態以 `@Observable` 暴露給 view，使 UI 可被任何畫面重用
@MainActor
@Observable
final class AudioPlayerEngine: NSObject {

    // MARK: - Observable State

    /// 是否正在播放
    private(set) var isPlaying: Bool = false

    /// 目前播放秒數
    private(set) var currentTime: TimeInterval = 0

    /// 音檔總長度（秒）
    private(set) var duration: TimeInterval = 0

    /// 是否已載入音檔
    private(set) var isLoaded: Bool = false

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    // MARK: - Load

    /// 從記憶體 `Data` 載入音檔
    /// - Parameter data: 音檔資料（如 base64 解碼後的 WAV）
    func load(data: Data) throws {
        try setupSession()
        let player = try AVAudioPlayer(data: data)
        adopt(player: player)
    }

    /// 從檔案 URL 載入音檔
    /// - Parameter url: 音檔位置
    func load(url: URL) throws {
        try setupSession()
        let player = try AVAudioPlayer(contentsOf: url)
        adopt(player: player)
    }

    // MARK: - Transport

    /// 開始播放（若已暫停則繼續）
    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    /// 暫停播放（保留當前位置）
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    /// 停止播放並回到起點
    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopProgressTimer()
    }

    /// 跳到指定秒數
    /// - Parameter time: 目標秒數
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    // MARK: - Private

    private func adopt(player: AVAudioPlayer) {
        stop()
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        duration = player.duration
        currentTime = 0
        isPlaying = false
        isLoaded = true
    }

    private func setupSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerEngine: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.currentTime = 0
            self.isPlaying = false
            self.stopProgressTimer()
        }
    }
}
