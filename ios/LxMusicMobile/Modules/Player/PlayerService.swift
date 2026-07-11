//
//  PlayerService.swift
//  LXMusic
//
//  AVQueuePlayer 封装，提供队列管理、播放控制、预缓冲能力
//  替代 Android 端 Media3 ExoPlayer + react-native-track-player fork
//

import Foundation
import AVFoundation

// MARK: - 播放器状态枚举
// 与 react-native-track-player 的 State 枚举对齐
enum PlayerState: String {
    case none = "none"
    case ready = "ready"
    case playing = "playing"
    case paused = "paused"
    case stopped = "stopped"
    case buffering = "buffering"
    case connecting = "connecting"
}

// MARK: - Track 数据结构
// 对应 JS 侧 LX.Player.Track
struct PlayerTrack {
    var id: String           // `${musicId}__//${random}__//${url}`
    var url: String
    var title: String
    var artist: String
    var album: String?
    var artwork: String?
    var userAgent: String?
    var musicId: String
    var lyric: String?
    var duration: Double
}

// MARK: - PlayerService
class PlayerService: NSObject {

    // MARK: 单例
    static let shared = PlayerService()

    // MARK: 播放器核心
    private var player: AVQueuePlayer?
    private var currentItems: [AVPlayerItem] = []
    private var tracks: [PlayerTrack] = []   // 与 JS 侧 list 对应

    // MARK: 状态
    private(set) var currentState: PlayerState = .none
    private(set) var isInitialized: Bool = false
    private(set) var currentIndex: Int = -1

    // MARK: 音频会话
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }

    // MARK: 时间观察器
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?

    // MARK: 回调闭包
    var onStateChange: ((PlayerState) -> Void)?
    var onTrackChanged: ((_ oldTrackId: String?, _ newTrackId: String?) -> Void)?
    var onError: ((String) -> Void)?
    var onProgressUpdate: ((Double, Double, Double) -> Void)?  // position, duration, buffered

    // MARK: 缓存管理
    private var maxCacheSize: Int64 = 100 * 1024 * 1024  // 默认 100MB

    // MARK: - 初始化播放器
    func setupPlayer(
        maxCacheSize: Int64,
        maxBuffer: Double = 1000,
        waitForBuffer: Bool = true,
        handleAudioFocus: Bool = true,
        audioOffload: Bool = false,
        autoUpdateMetadata: Bool = false
    ) {
        if isInitialized { return }

        self.maxCacheSize = maxCacheSize

        // 配置 AVAudioSession（后台播放）
        configureAudioSession(handleAudioFocus: handleAudioFocus)

        // 创建播放器
        let player = AVQueuePlayer()
        player.automaticallyWaitsToMinimizeStalling = waitForBuffer
        player.actionAtItemEnd = .advance  // 队列自动播放下一首
        self.player = player

        // 观察播放速率变化（判断播放/暂停状态）
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            if player.rate == 0 {
                self.updateState(.paused)
            } else {
                self.updateState(.playing)
            }
        }

        // 时间观察器（进度更新）
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let item = player.currentItem else { return }
            let position = time.seconds
            let duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
            let buffered = item.loadedTimeRanges.last?.timeRangeValue.end.seconds ?? 0
            self.onProgressUpdate?(position, duration, buffered)
        }

        isInitialized = true
    }

    // MARK: - 配置音频会话
    private func configureAudioSession(handleAudioFocus: Bool) {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: handleAudioFocus ? [] : [.mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("PlayerService: AVAudioSession 配置失败 - \(error)")
        }
    }

    // MARK: - 状态更新
    private func updateState(_ state: PlayerState) {
        guard currentState != state else { return }
        currentState = state
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }

    // MARK: - 队列管理

    /// 添加轨道到队列末尾（对应 TrackPlayer.add）
    func addTracks(_ newTracks: [PlayerTrack], completionHandler: (() -> Void)? = nil) {
        guard let player = player else {
            completionHandler?()
            return
        }

        for track in newTracks {
            guard let url = URL(string: track.url) else { continue }
            let item = createPlayerItem(url: url, track: track)
            currentItems.append(item)
            tracks.append(track)
            player.insert(item, after: nil)
        }

        completionHandler?()
    }

    /// 创建 AVPlayerItem 并观察状态
    private func createPlayerItem(url: URL, track: PlayerTrack) -> AVPlayerItem {
        // 配置 HTTP 请求头（User-Agent）
        let headers: [String: String]
        if let userAgent = track.userAgent {
            headers = ["User-Agent": userAgent]
        } else {
            headers = [:]
        }

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetHTTPCookiesKey: HTTPCookieStorage.shared.cookies ?? [],
            AVURLAssetHTTPHeaderFieldsKey: headers,
        ])

        let item = AVPlayerItem(asset: asset)

        // 观察缓冲状态
        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: [.new], context: nil)
        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidPlayToEndTime(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        // 监听播放失败
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemFailedToPlayToEndTime(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )

        return item
    }

    // MARK: - KVO 观察
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }

        if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges) {
            // 缓冲进度变化
            if let item = object as? AVPlayerItem, item == player?.currentItem {
                if item.loadedTimeRanges.isEmpty {
                    updateState(.buffering)
                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.status) {
            if let item = object as? AVPlayerItem {
                switch item.status {
                case .readyToPlay:
                    updateState(.ready)
                case .failed:
                    onError?(item.error?.localizedDescription ?? "播放失败")
                    updateState(.none)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - 播放结束
    @objc private func itemDidPlayToEndTime(_ notification: Notification) {
        // 队列自动播放下一首，由 actionAtItemEnd = .advance 处理
        // 这里触发 trackChanged 事件
        let oldTrackId = tracks.indices.contains(currentIndex) ? tracks[currentIndex].id : nil
        currentIndex += 1
        let newTrackId = currentIndex < tracks.count ? tracks[currentIndex].id : nil
        onTrackChanged?(oldTrackId, newTrackId)
    }

    // MARK: - 播放失败
    @objc private func itemFailedToPlayToEndTime(_ notification: Notification) {
        let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "播放错误"
        onError?(error)
    }

    // MARK: - 播放控制

    /// 播放（对应 TrackPlayer.play）
    func play() {
        guard let player = player else { return }
        configureAudioSession(handleAudioFocus: true)
        player.play()
    }

    /// 暂停（对应 TrackPlayer.pause）
    func pause() {
        player?.pause()
        updateState(.paused)
    }

    /// 停止（对应 TrackPlayer.stop）
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        updateState(.stopped)
    }

    /// 跳转到指定位置（对应 TrackPlayer.seekTo）
    func seek(to time: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// 获取当前位置（对应 TrackPlayer.getPosition）
    func getPosition() -> Double {
        return player?.currentTime().seconds ?? 0
    }

    /// 获取时长（对应 TrackPlayer.getDuration）
    func getDuration() -> Double {
        guard let item = player?.currentItem else { return 0 }
        return item.duration.seconds.isFinite ? item.duration.seconds : 0
    }

    /// 获取缓冲位置（对应 TrackPlayer.getBufferedPosition）
    func getBufferedPosition() -> Double {
        guard let item = player?.currentItem else { return 0 }
        return item.loadedTimeRanges.last?.timeRangeValue.end.seconds ?? 0
    }

    /// 设置音量（对应 TrackPlayer.setVolume）
    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    /// 设置播放速率（对应 TrackPlayer.setRate）
    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    // MARK: - 队列跳转

    /// 获取当前轨道索引（对应 TrackPlayer.getCurrentTrack）
    func getCurrentTrackIndex() -> Int? {
        guard let player = player else { return nil }
        guard let currentItem = player.currentItem else { return nil }
        return currentItems.firstIndex(of: currentItem)
    }

    /// 获取当前轨道 ID
    func getCurrentTrackId() -> String? {
        guard let index = getCurrentTrackIndex(), index < tracks.count else { return nil }
        return tracks[index].id
    }

    /// 跳转到指定索引（对应 TrackPlayer.skip）
    func skip(toIndex index: Int) {
        guard let player = player, index >= 0 && index < currentItems.count else { return }
        let oldTrackId = getCurrentTrackId()
        player.removeAllItems()
        for (i, item) in currentItems.enumerated() {
            if i >= index {
                player.insert(item, after: nil)
            }
        }
        currentIndex = index
        let newTrackId = tracks[index].id
        onTrackChanged?(oldTrackId, newTrackId)
    }

    /// 跳到下一首（对应 TrackPlayer.skipToNext）
    func skipToNext() {
        guard let index = getCurrentTrackIndex(), index + 1 < currentItems.count else { return }
        skip(toIndex: index + 1)
    }

    /// 移除轨道（对应 TrackPlayer.remove）
    func removeTracks(at indexes: [Int]) {
        guard let player = player else { return }
        let sortedIndexes = indexes.sorted(by: >)
        for index in sortedIndexes {
            guard index < currentItems.count else { continue }
            let item = currentItems[index]
            // 移除 KVO 观察者和通知监听，防止内存泄漏
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
            player.remove(item)
            currentItems.remove(at: index)
            tracks.remove(at: index)
        }
    }

    /// 获取队列（对应 TrackPlayer.getQueue）
    func getQueue() -> [PlayerTrack] {
        return tracks
    }

    /// 清空队列
    func clearQueue() {
        guard let player = player else { return }
        // 移除所有 KVO 观察者和通知监听
        for item in currentItems {
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
        }
        player.removeAllItems()
        currentItems.removeAll()
        tracks.removeAll()
        currentIndex = -1
    }

    // MARK: - 缓存管理

    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheDir = cacheDir else { return 0 }
        return directorySize(at: cacheDir)
    }

    /// 清除缓存
    func clearCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheDir = cacheDir else { return }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// URL 是否已缓存
    func isCached(url: String) -> Bool {
        // AVURLAsset 不直接暴露缓存状态，使用简单的文件检查
        guard let url = URL(string: url) else { return false }
        let cacheKey = url.lastPathComponent
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheDir = cacheDir else { return false }
        let cacheFile = cacheDir.appendingPathComponent(cacheKey)
        return FileManager.default.fileExists(atPath: cacheFile.path)
    }

    private func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }

    // MARK: - 销毁
    func destroy() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        rateObservation?.invalidate()
        bufferObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player?.removeAllItems()
        currentItems.removeAll()
        tracks.removeAll()
        player = nil
        isInitialized = false
        currentIndex = -1
        currentState = .none
    }

    // MARK: - 更新元数据
    /// 更新当前播放项的元数据（对应 TrackPlayer.updateNowPlayingMetadata）
    func updateNowPlayingMetadata(
        title: String,
        artist: String,
        album: String?,
        artwork: String?,
        duration: Double,
        lyric: String?,
        isPlaying: Bool
    ) {
        NowPlayingManager.shared.updateNowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            duration: duration,
            position: getPosition(),
            lyric: lyric,
            isPlaying: isPlaying
        )
    }

    /// 更新标题（对应 TrackPlayer.updateNowPlayingTitles）
    func updateNowPlayingTitles(title: String?, artist: String?, album: String?, lyric: String?) {
        NowPlayingManager.shared.updateTitles(title: title, artist: artist, album: album, lyric: lyric)
    }
}
