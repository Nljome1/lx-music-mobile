//
//  NowPlayingManager.swift
//  LXMusic
//
//  MPNowPlayingInfoCenter + MPRemoteCommandCenter 封装
//  替代 Android 端 MediaSession（通知栏控件、控制中心、锁屏）
//  CarPlay 的 CPNowPlayingTemplate 自动与此联动
//

import Foundation
import MediaPlayer
import AVFoundation

class NowPlayingManager {

    static let shared = NowPlayingManager()

    // MARK: - 远程命令回调
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNext: (() -> Void)?
    var onRemotePrev: (() -> Void)?
    var onRemoteStop: (() -> Void)?
    var onRemoteSeek: ((Double) -> Void)?

    // MARK: - 状态
    private var isPlaying: Bool = false
    private var currentArtwork: MPMediaItemArtwork?

    private init() {
        setupRemoteCommands()
    }

    // MARK: - 配置远程命令
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // 播放
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.onRemotePlay?()
            return .success
        }

        // 暂停
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onRemotePause?()
            return .success
        }

        // 停止
        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in
            self?.onRemoteStop?()
            return .success
        }

        // 下一首
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onRemoteNext?()
            return .success
        }

        // 上一首
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePrev?()
            return .success
        }

        // 进度跳转（锁屏进度条拖动）
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.onRemoteSeek?(event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    // MARK: - 更新 Now Playing 信息
    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        artwork: String?,
        duration: Double,
        position: Double,
        lyric: String?,
        isPlaying: Bool
    ) {
        self.isPlaying = isPlaying

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        if let album = album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // 蓝牙歌词（通过 MPMediaItemPropertyLyrics，iOS 9+）
        if let lyric = lyric, !lyric.isEmpty {
            info[MPMediaItemPropertyLyrics] = lyric
        }

        // 封面图（异步加载）
        if let artworkUrl = artwork, let url = URL(string: artworkUrl) {
            loadArtwork(from: url) { [weak self] artwork in
                guard let artwork = artwork else { return }
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 仅更新标题（对应 updateNowPlayingTitles）
    func updateTitles(title: String?, artist: String?, album: String?, lyric: String?) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if let title = title {
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let lyric = lyric, !lyric.isEmpty {
            info[MPMediaItemPropertyLyrics] = lyric
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 更新播放进度
    func updatePlaybackPosition(_ position: Double, duration: Double, isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 清除 Now Playing 信息
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - 异步加载封面图
    private func loadArtwork(from url: URL, completionHandler: @escaping (MPMediaItemArtwork?) -> Void) {
        // 缓存已加载的封面
        if let current = currentArtwork {
            completionHandler(current)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                completionHandler(nil)
                return
            }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async {
                completionHandler(artwork)
            }
        }
    }
}
