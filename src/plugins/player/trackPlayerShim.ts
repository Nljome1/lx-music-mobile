import { NativeModules, NativeEventEmitter, type EmitterSubscription } from 'react-native'

// 原生播放器模块
const { PlayerModule } = NativeModules
const playerEmitter = new NativeEventEmitter(PlayerModule)

// 播放状态枚举（与 react-native-track-player 对齐）
export enum State {
  None = 'none',
  Ready = 'ready',
  Playing = 'playing',
  Paused = 'paused',
  Stopped = 'stopped',
  Buffering = 'buffering',
  Error = 'error',
  Loading = 'loading',
  End = 'ended',
}

// 事件枚举（与 react-native-track-player 对齐）
export enum Event {
  PlaybackState = 'playback-state',
  PlaybackError = 'playback-error',
  PlaybackTrackChanged = 'playback-track-changed',
  PlaybackQueueEnded = 'playback-queue-ended',
  PlaybackProgressReceived = 'playback-progress-received',
  PlaybackMetadataReceived = 'playback-metadata-received',
  RemotePlay = 'remote-play',
  RemotePause = 'remote-pause',
  RemoteStop = 'remote-stop',
  RemoteNext = 'remote-next',
  RemotePrevious = 'remote-previous',
  RemoteSeek = 'remote-seek',
  RemoteDuck = 'remote-duck',
  RemoteJumpForward = 'remote-jump-forward',
  RemoteJumpBackward = 'remote-jump-backward',
}

// 能力枚举
export enum Capability {
  Play = 'play',
  Pause = 'pause',
  Stop = 'stop',
  SkipToNext = 'next',
  SkipToPrevious = 'previous',
  JumpForward = 'jumpForward',
  JumpBackward = 'jumpBackward',
  Seek = 'seek',
  SetRating = 'setRating',
  Like = 'like',
  Dislike = 'dislike',
  Bookmark = 'bookmark',
}

// 重复模式枚举
export enum RepeatMode {
  Off = 0,
  Track = 1,
  Queue = 2,
}

// Track 类型定义
export interface Track {
  id: string
  url: string
  title: string
  artist: string
  album?: string
  artwork?: string
  duration?: number
  [key: string]: any
}

// 事件订阅句柄
interface EventSubscription {
  remove: () => void
}

// TrackPlayer 适配对象
export const TrackPlayer = {
  // 播放控制
  play: (): Promise<void> => PlayerModule.play(),
  pause: (): Promise<void> => PlayerModule.pause(),
  stop: (): Promise<void> => PlayerModule.stop(),
  seekTo: (position: number): Promise<void> => PlayerModule.seekTo(position),
  skip: (index: number): Promise<void> => PlayerModule.skip(index),
  skipToNext: (): Promise<void> => PlayerModule.skipToNext(),
  skipToPrevious: (): Promise<void> => PlayerModule.skipToNext(), // 由原生层处理方向

  // 队列管理
  add: (tracks: Track | Track[], insertBeforeIndex?: number): Promise<void> => {
    const trackArray = Array.isArray(tracks) ? tracks : [tracks]
    return PlayerModule.add(trackArray, insertBeforeIndex ?? -1)
  },
  remove: (indexes: number | number[]): Promise<void> => {
    const indexArray = Array.isArray(indexes) ? indexes : [indexes]
    return PlayerModule.remove(indexArray)
  },
  getQueue: (): Promise<Track[]> => PlayerModule.getQueue(),
  getCurrentTrack: (): Promise<number> => PlayerModule.getCurrentTrack(),

  // 状态查询
  getState: (): Promise<State> => PlayerModule.getState(),
  getPosition: (): Promise<number> => PlayerModule.getPosition(),
  getDuration: (): Promise<number> => PlayerModule.getDuration(),
  getBufferedPosition: (): Promise<number> => PlayerModule.getBufferedPosition(),

  // 音量与速率
  setVolume: (volume: number): Promise<void> => PlayerModule.setVolume(volume),
  setRate: (rate: number): Promise<void> => PlayerModule.setRate(rate),
  setRepeatMode: (mode: RepeatMode): Promise<void> => PlayerModule.setRepeatMode(mode),

  // 初始化与销毁
  setupPlayer: (options?: Record<string, any>): Promise<void> => PlayerModule.setupPlayer(options ?? {}),
  destroy: (): Promise<void> => PlayerModule.destroy(),
  updateOptions: (options: Record<string, any>): Promise<void> => PlayerModule.updateOptions(options),

  // Now Playing
  updateNowPlayingMetadata: (metadata: Record<string, any>): Promise<void> =>
    PlayerModule.updateNowPlayingMetadata(metadata, true),
  updateNowPlayingTitles: (titles: string[]): Promise<void> =>
    PlayerModule.updateNowPlayingTitles(titles),

  // 缓存
  isCached: (url: string): Promise<boolean> => PlayerModule.isCached(url),
  getCacheSize: (): Promise<number> => PlayerModule.getCacheSize(),
  clearCache: (): Promise<void> => PlayerModule.clearCache(),

  // 事件监听
  addEventListener: (event: Event | string, callback: (payload: any) => void): EventSubscription => {
    const subscription: EmitterSubscription = playerEmitter.addListener(
      typeof event === 'string' ? event : event,
      callback
    )
    return { remove: () => subscription.remove() }
  },

  // 注册播放服务
  registerPlaybackService: (): Promise<void> => PlayerModule.registerPlaybackService(),
}

export default TrackPlayer
