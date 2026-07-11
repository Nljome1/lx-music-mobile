# ADR-0002: iOS 原生播放器模块设计

## 状态

已采纳 (2026-07-11)

## 背景

当前 Android 端播放器核心通过自定义 fork 的 `react-native-track-player` 实现，底层使用 Android Media3 ExoPlayer。iOS 端没有对应实现，需要选择一个播放器方案，且必须保持与现有 `plugins/player/` 层接口契约兼容。

## 决策

**新建一个自定义 iOS 原生播放器模块，底层使用 `AVQueuePlayer` + `MPNowPlayingInfoCenter`，直接实现 `plugins/player/` 定义的接口契约。**

### 技术映射

| Android 当前实现 | iOS 对应方案 |
|------------------|-------------|
| Media3 ExoPlayer | `AVQueuePlayer`（原生支持队列管理、预缓冲） |
| MediaSession（通知栏控件） | `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`（控制中心 + 锁屏） |
| MediaSession 蓝牙歌词 | `MPNowPlayingInfoCenter.nowPlayingInfo[MPMediaItemPropertyLyrics]` |
| 预加载下一首 URL | `AVQueuePlayer` 自动队列 + `AVPlayerItem` 预缓冲 |
| 音频卸载（Audio Offload） | iOS 无此概念，直接移除该能力 |
| 后台播放服务 | `AVAudioSession` + Background Modes capability |
| 定时关闭播放 | 播放器模块内建 Swift `Timer`，替代 `react-native-background-timer` |

### 接口契约

新模块必须实现 `plugins/player/` 层定义的以下能力：

| 文件 | 需实现的能力 |
|------|------------|
| `plugins/player/service.ts` | 后台播放服务启动/停止、播放队列管理、播放控制（播放/暂停/切歌/seek） |
| `plugins/player/playList.ts` | 当前播放列表、临时播放列表、已播放列表的增删改查 |
| `plugins/player/hook.ts` | React Hook 接口：播放状态、进度、当前歌曲信息的实时订阅 |
| `plugins/player/utils.ts` | 播放器工具函数 |

### 为什么不用现成的 RN 播放器库

官方 `react-native-track-player` 的 API 契约和队列模型与当前仓库中自定义 fork 的版本完全不同。`core/player/player.ts`（21KB）中大量逻辑依赖 fork 版本的特有 API 和事件模型。硬套一个现成库等于在 `core/` 层做大量适配，风险远高于自建原生模块。

## 后果

### 优势

- `core/player/` 层零改动，接口契约完全兼容
- `AVQueuePlayer` 原生支持队列和预加载，与 Android 端行为对齐
- `MPNowPlayingInfoCenter` 天然对接 CarPlay 的 `CPNowPlayingTemplate`，无需额外桥接
- 定时关闭功能内建，移除 `react-native-background-timer` 依赖

### 代价

- 需编写约 1000-1500 行 Swift 代码（播放器服务 + Bridge + 事件系统）
- `AVQueuePlayer` 的错误处理模型与 Media3 不同，需在 Bridge 层做适配
- 音频卸载功能在 iOS 上不可用，需在设置 UI 中隐藏该选项

## 备选方案

### Fork 官方 `react-native-track-player`

- 优势：减少原生代码编写量
- 劣势：API 不兼容，`core/player/` 层需大量改动；官方版本不支持 Media3 的一些高级特性；Fork 维护成本不亚于自建