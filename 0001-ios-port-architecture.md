# ADR-0001: iOS 移植路线与整体架构策略

## 状态

已修订 (2026-07-11) — 纯 iOS 版本，不再保留双平台支持

## 背景

lx-music-mobile 原项目仅支持 Android 5+ 平台。本项目将其移植为**纯 iOS 版本**，并支持 CarPlay 车载模式。项目基于 React Native 0.73.11，使用 TypeScript，核心代码在 `src/` 下与平台无关。移植过程中移除所有 Android 原生代码和 Android 专属依赖，仅保留 iOS 原生实现。

## 决策

**选择路线 A：保持 React Native 框架，移除所有 Android 代码，新建 iOS 原生模块。**

### 架构约束

```
src/                          # TypeScript 代码（移植适配）
├── core/                     # 纯业务逻辑，零改动
├── store/                    # 状态管理，零改动
├── components/               # UI 组件，移除 Android 平台分支
├── screens/                  # 页面，移除 Android 平台分支
├── plugins/player/           # 插件接口层，零改动（底层替换为 iOS 原生模块）
├── plugins/sync/             # 同步插件，零改动
├── plugins/storage.ts        # 存储插件，零改动
├── plugins/lyric.ts          # 歌词插件，零改动
├── utils/request.js          # 网络层，移除 BackgroundTimer，使用原生 setTimeout
├── utils/fs.ts               # 文件系统，适配 iOS 路径常量
└── utils/musicSdk/           # 音乐 SDK，零改动

ios/                          # iOS 原生代码
├── LxMusicMobile/Modules/Player/   # 播放器原生模块
├── LxMusicMobile/Modules/FileSystem/# 文件系统原生模块
├── LxMusicMobile/Modules/MediaMetadata/ # 元数据原生模块
└── LxMusicMobile/CarPlay/          # CarPlay 独立入口
```

### 核心原则

1. **`core/` 层零改动**：所有业务逻辑（播放器、搜索、歌单、同步、排行榜）通过 `plugins/` 接口层隔离原生差异。
2. **`plugins/` 接口契约不变**：JS 侧接口签名保持一致，底层由 iOS 原生模块实现。
3. **UI 层移除 Android 分支**：移除所有 `Platform.OS === 'android'` 条件分支，仅保留 iOS 行为。
4. **CarPlay 独立入口**：通过 `CarPlaySceneDelegate` 原生实现，不嵌入 React Native 视图。
5. **移除所有 Android 代码**：删除 `android/` 目录及 Android 专属依赖。

## 后果

### 优势

- **最大化代码复用**：`src/` 下约 90% 的 TypeScript 代码无需修改
- **维护成本最低**：单一平台，无需兼顾 Android 行为差异
- **CarPlay 天然衔接**：原生播放器模块的 `MPNowPlayingInfoCenter` 和 `MPRemoteCommandCenter` 与 CarPlay 的 `CPNowPlayingTemplate` 共享底层协议
- **代码库精简**：移除 Android 代码后，减少约 30% 的平台分支代码

### 代价

- 需要新建 3 个 iOS 原生模块（播放器、文件系统、元数据），每个约 500-1500 行 Swift 代码
- 构建和测试需在真实 macOS 环境中进行（不使用 CI 自动构建）
- CarPlay 模板 UI 与手机端 React Native UI 是两套独立代码，UI 变更需双端同步
- 移除 4 个 Android 专属 fork 依赖（`react-native-track-player`、`react-native-background-timer`、`react-native-file-system`、`react-native-local-media-metadata`）

### 不做的事

- **不重写为 SwiftUI 纯原生**：放弃 React Native 的代码复用优势，代价过高
- **不使用 CI 自动构建**：由开发者在真实 macOS 环境中手动构建和测试
- **不全局关闭 ATS**：`AVPlayer` 播放 HTTP 音频流不受 ATS 限制，仅对网络请求层按需配置 `NSExceptionDomains`

---

## 备选方案

### 路线 B：纯原生 SwiftUI 重写

- 优势：最佳 iOS 原生体验，CarPlay 天然支持
- 劣势：需重写全部 UI 和业务逻辑（约 200+ 文件），无法复用现有 TypeScript 代码

### 路线 C：混合方案（核心 TS 共享 + 原生 UI）

- 优势：核心逻辑复用，UI 原生
- 劣势：TS 和 Swift 之间的桥接层复杂，状态同步成本高，与路线 A 相比增加大量额外工作
