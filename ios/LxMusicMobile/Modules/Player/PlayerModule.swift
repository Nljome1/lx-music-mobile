//
//  PlayerModule.swift
//  LXMusic
//
//  React Native 原生模块桥接层
//  替代 react-native-track-player fork
//  实现 plugins/player/ 层定义的接口契约
//

import Foundation
import AVFoundation
import MediaPlayer

@objc(PlayerModule)
class PlayerModule: RCTEventEmitter {

    // MARK: - 事件支持
    private static var hasListener = false
    private var eventQueue: [(String, Any?)] = []

    override static func requiresMainQueueSetup() -> Bool {
        return false
    }

    override func supportedEvents() -> [String]! {
        // 与 react-native-track-player 事件名对齐
        return [
            "playback-error",
            "playback-state",
            "playback-track-changed",
            "playback-queue-ended",
            "remote-play",
            "remote-pause",
            "remote-next",
            "remote-previous",
            "remote-stop",
            "remote-seek",
            "remote-duck",
        ]
    }

    // MARK: - 生命周期
    override func startObserving() {
        PlayerModule.hasListener = true
        // 发送队列中积压的事件
        for (event, payload) in eventQueue {
            sendEvent(withName: event, body: payload)
        }
        eventQueue.removeAll()
    }

    override func stopObserving() {
        PlayerModule.hasListener = false
    }

    // MARK: - 事件发送
    private func emitEvent(_ name: String, body: Any? = nil) {
        if PlayerModule.hasListener {
            sendEvent(withName: name, body: body)
        } else {
            eventQueue.append((name, body))
        }
    }

    // MARK: - 播放器初始化与回调绑定
    private func bindPlayerCallbacks() {
        let service = PlayerService.shared

        // 状态变化
        service.onStateChange = { [weak self] state in
            let stateData: [String: Any] = ["state": state.rawValue]
            self?.emitEvent("playback-state", body: stateData)
        }

        // 轨道变化
        service.onTrackChanged = { [weak self] oldId, newId in
            let data: [String: Any] = [
                "track": oldId as Any,
                "nextTrack": newId as Any,
                "position": nil,
            ]
            self?.emitEvent("playback-track-changed", body: data)
        }

        // 播放错误
        service.onError = { [weak self] error in
            self?.emitEvent("playback-error", body: ["error": error])
        }

        // 远程命令（通知栏 / 控制中心 / CarPlay）
        let nowPlaying = NowPlayingManager.shared
        nowPlaying.onRemotePlay = { [weak self] in
            self?.emitEvent("remote-play")
        }
        nowPlaying.onRemotePause = { [weak self] in
            self?.emitEvent("remote-pause")
        }
        nowPlaying.onRemoteNext = { [weak self] in
            self?.emitEvent("remote-next")
        }
        nowPlaying.onRemotePrev = { [weak self] in
            self?.emitEvent("remote-previous")
        }
        nowPlaying.onRemoteStop = { [weak self] in
            self?.emitEvent("remote-stop")
        }
        nowPlaying.onRemoteSeek = { [weak self] position in
            self?.emitEvent("remote-seek", body: ["position": position])
        }
    }

    // MARK: - 初始化播放器
    // 对应 TrackPlayer.setupPlayer
    @objc(setupPlayer:resolver:rejecter:)
    func setupPlayer(
        options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let maxCacheSize = options["maxCacheSize"] as? Int64 ?? 100 * 1024 * 1024
        let maxBuffer = options["maxBuffer"] as? Double ?? 1000
        let waitForBuffer = options["waitForBuffer"] as? Bool ?? true
        let handleAudioFocus = options["handleAudioFocus"] as? Bool ?? true
        let audioOffload = options["audioOffload"] as? Bool ?? false
        // autoUpdateMetadata: iOS 上由 NowPlayingManager 手动管理
        // audioOffload: iOS 无此概念，忽略

        bindPlayerCallbacks()

        PlayerService.shared.setupPlayer(
            maxCacheSize: maxCacheSize,
            maxBuffer: maxBuffer,
            waitForBuffer: waitForBuffer,
            handleAudioFocus: handleAudioFocus,
            audioOffload: audioOffload,
            autoUpdateMetadata: false
        )

        resolve(nil)
    }

    // MARK: - 更新选项
    // 对应 TrackPlayer.updateOptions
    @objc(updateOptions:resolver:rejecter:)
    func updateOptions(
        options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 上通知栏能力由 MPRemoteCommandCenter 自动管理
        // 这里仅做兼容处理
        resolve(nil)
    }

    // MARK: - 队列操作

    // 对应 TrackPlayer.add
    @objc(add:resolver:rejecter:)
    func add(
        tracks: NSArray,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        var playerTracks: [PlayerTrack] = []
        for item in tracks {
            guard let dict = item as? NSDictionary else { continue }
            let track = PlayerTrack(
                id: dict["id"] as? String ?? "",
                url: dict["url"] as? String ?? "",
                title: dict["title"] as? String ?? "Unknown",
                artist: dict["artist"] as? String ?? "Unknown",
                album: dict["album"] as? String,
                artwork: dict["artwork"] as? String,
                userAgent: dict["userAgent"] as? String,
                musicId: dict["musicId"] as? String ?? "",
                lyric: dict["lyric"] as? String,
                duration: dict["duration"] as? Double ?? 0
            )
            playerTracks.append(track)
        }
        PlayerService.shared.addTracks(playerTracks) {
            resolve(nil)
        }
    }

    // 对应 TrackPlayer.skip
    @objc(skip:resolver:rejecter:)
    func skip(
        toIndex: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.skip(toIndex: toIndex.intValue)
        resolve(nil)
    }

    // 对应 TrackPlayer.skipToNext
    @objc(skipToNext:rejecter:)
    func skipToNext(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.skipToNext()
        resolve(nil)
    }

    // 对应 TrackPlayer.remove
    @objc(remove:resolver:rejecter:)
    func remove(
        indexes: NSArray,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let intIndexes = indexes.compactMap { ($0 as? NSNumber)?.intValue }
        PlayerService.shared.removeTracks(at: intIndexes)
        resolve(nil)
    }

    // 对应 TrackPlayer.getQueue
    @objc(getQueue:rejecter:)
    func getQueue(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let queue = PlayerService.shared.getQueue().map { track -> [String: Any] in
            return [
                "id": track.id,
                "url": track.url,
                "title": track.title,
                "artist": track.artist,
                "album": track.album ?? NSNull(),
                "artwork": track.artwork ?? NSNull(),
                "userAgent": track.userAgent ?? NSNull(),
                "musicId": track.musicId,
                "lyric": track.lyric ?? NSNull(),
                "duration": track.duration,
            ]
        }
        resolve(queue)
    }

    // 对应 TrackPlayer.getCurrentTrack
    @objc(getCurrentTrack:rejecter:)
    func getCurrentTrack(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let index = PlayerService.shared.getCurrentTrackIndex()
        resolve(index != nil ? NSNumber(value: index!) : NSNull())
    }

    // MARK: - 播放控制

    // 对应 TrackPlayer.play
    @objc(play:rejecter:)
    func play(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.play()
        resolve(nil)
    }

    // 对应 TrackPlayer.pause
    @objc(pause:rejecter:)
    func pause(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.pause()
        resolve(nil)
    }

    // 对应 TrackPlayer.stop
    @objc(stop:rejecter:)
    func stop(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.stop()
        resolve(nil)
    }

    // 对应 TrackPlayer.seekTo
    @objc(seekTo:resolver:rejecter:)
    func seekTo(
        time: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.seek(to: time.doubleValue)
        resolve(nil)
    }

    // 对应 TrackPlayer.setVolume
    @objc(setVolume:resolver:rejecter:)
    func setVolume(
        volume: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.setVolume(volume.floatValue)
        resolve(nil)
    }

    // 对应 TrackPlayer.setRate
    @objc(setRate:resolver:rejecter:)
    func setRate(
        rate: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.setRate(rate.floatValue)
        resolve(nil)
    }

    // 对应 TrackPlayer.setRepeatMode
    @objc(setRepeatMode:resolver:rejecter:)
    func setRepeatMode(
        repeatMode: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // repeatMode: 0=Off, 1=Track
        let isTrackLoop = repeatMode.intValue == 1
        PlayerService.shared.setLoop(isTrackLoop)
        resolve(nil)
    }

    // MARK: - 状态查询

    // 对应 TrackPlayer.getState
    @objc(getState:rejecter:)
    func getState(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.currentState.rawValue)
    }

    // 对应 TrackPlayer.getPosition
    @objc(getPosition:rejecter:)
    func getPosition(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.getPosition())
    }

    // 对应 TrackPlayer.getDuration
    @objc(getDuration:rejecter:)
    func getDuration(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.getDuration())
    }

    // 对应 TrackPlayer.getBufferedPosition
    @objc(getBufferedPosition:rejecter:)
    func getBufferedPosition(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.getBufferedPosition())
    }

    // MARK: - 元数据更新

    // 对应 TrackPlayer.updateNowPlayingMetadata
    @objc(updateNowPlayingMetadata:isPlaying:resolver:rejecter:)
    func updateNowPlayingMetadata(
        metadata: NSDictionary,
        isPlaying: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let title = metadata["title"] as? String ?? "Unknown"
        let artist = metadata["artist"] as? String ?? "Unknown"
        let album = metadata["album"] as? String
        let artwork = metadata["artwork"] as? String
        let duration = metadata["duration"] as? Double ?? 0
        let lyric = metadata["lyric"] as? String

        PlayerService.shared.updateNowPlayingMetadata(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            duration: duration,
            lyric: lyric,
            isPlaying: isPlaying
        )
        resolve(nil)
    }

    // 对应 TrackPlayer.updateNowPlayingTitles
    @objc(updateNowPlayingTitles:resolver:rejecter:)
    func updateNowPlayingTitles(
        titles: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let title = titles["title"] as? String
        let artist = titles["artist"] as? String
        let album = titles["album"] as? String
        let lyric = titles["lyric"] as? String

        PlayerService.shared.updateNowPlayingTitles(
            title: title,
            artist: artist,
            album: album,
            lyric: lyric
        )
        resolve(nil)
    }

    // MARK: - 缓存管理

    @objc(isCached:resolver:rejecter:)
    func isCached(
        url: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.isCached(url: url))
    }

    @objc(getCacheSize:rejecter:)
    func getCacheSize(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(PlayerService.shared.getCacheSize())
    }

    @objc(clearCache:rejecter:)
    func clearCache(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.clearCache()
        resolve(nil)
    }

    // MARK: - 销毁
    @objc(destroy:rejecter:)
    func destroy(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        PlayerService.shared.destroy()
        NowPlayingManager.shared.clearNowPlayingInfo()
        resolve(nil)
    }

    // MARK: - 注册播放服务（对应 registerPlaybackService）
    @objc(registerPlaybackService:resolver:rejecter:)
    func registerPlaybackService(
        callback: RCTResponseSenderBlock,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 上远程命令已通过 NowPlayingManager 配置
        // 这里仅做兼容，不执行额外操作
        resolve(nil)
    }
}
