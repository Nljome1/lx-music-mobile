# ADR-0001: iOS 移植路线与整体架构策略

## 状态

已采纳 (2026-07-11)

## 背景

lx-music-mobile 当前仅支持 Android 5+ 平台。用户希望将项目移植到 iOS 平台，并支持 CarPlay 车载模式。项目基于 React Native 0.73.11，使用 TypeScript，核心代码在 `src/` 下与平台无关，但 `android/` 目录下的原生代码和多个自定义 fork 的原生依赖与 Android 深度绑定。

## 决策

**选择路线 A：保持 React Native 框架，替换所有 Android 原生模块为 iOS 等价实现。**

### 架构约束

```
src/                          # 共享 TypeScript 代码（最大化不动）
├── core/                     # 纯业务逻辑，零改动
├── store/                    # 状态管理，零改动
├── components/               # UI 组件，Platform.OS 最小适配
├── screens/                  # 页面，Platform.OS 最小适配
├── plugins/player/           # 插件接口层，零改动（底层替换）
├── plugins/sync/             # 同步插件，零改动
├── plugins/storage.ts        # 存储插件，零改动
├── plugins/lyric.ts          # 歌词插件，零改动
├── utils/request.js          # 网络层，一处改动（BackgroundTimer → setTimeout）
├── utils/fs.ts               # 文件系统，适配 iOS 路径常量
└── utils/musicSdk/           # 音乐 SDK，零改动

android/                      # 现有 Android 原生代码（不动）

ios/                          # 新建 iOS 原生代码
├── LXMusic/Modules/Player/   # 新建：播放器原生模块
├── LXMusic/Modules/FileSystem/# 新建：文件系统原生模块
├── LXMusic/Modules/MediaMetadata/ # 新建：元数据原生模块
└── LXMusic/CarPlay/          # 新建：CarPlay 独立入口
```

### 核心原则

1. **`core/` 层零改动**：所有业务逻辑（播放器、搜索、歌单、同步、排行榜）通过 `plugins/` 接口层隔离原生差异。
2. **`plugins/` 接口契约不变**：只替换底层原生实现，JS 侧接口签名保持一致。
3. **UI 层最小适配**：仅用 `Platform.OS === 'ios'` 处理安全区域、字体、返回手势等平台差异，不重写整个 UI 层。
4. **CarPlay 独立入口**：通过 `CarPlaySceneDelegate` 原生实现，不嵌入 React Native 视图。

## 后果

### 优势

- **最大化代码复用**：`src/` 下约 90% 的 TypeScript 代码无需修改
- **维护成本低**：同一仓库、同一代码库，Android 和 iOS 共享所有业务逻辑更新
- **渐进式迁移**：可以逐个替换原生模块，每个模块独立开发、测试、集成
- **CarPlay 天然衔接**：原生播放器模块的 `MPNowPlayingInfoCenter` 和 `MPRemoteCommandCenter` 与 CarPlay 的 `CPNowPlayingTemplate` 共享底层协议

### 代价

- 需要新建 3 个 iOS 原生模块（播放器、文件系统、元数据），每个约 500-1500 行 Swift 代码
- CI 需要添加 macOS runner（成本约 10 倍于 Linux runner）
- CarPlay 模板 UI 与手机端 React Native UI 是两套独立代码，UI 变更需双端同步
- 需要更换 2 个 Android 专属依赖（`react-native-background-timer`、`react-native-file-system`）

### 不做的事

- **不重写为 SwiftUI 纯原生**：放弃 React Native 的代码复用优势，代价过高
- **不拆分独立仓库**：增加版本同步和发布协调的复杂度
- **不全局关闭 ATS**：`AVPlayer` 播放 HTTP 音频流不受 ATS 限制，仅对网络请求层按需配置 `NSExceptionDomains`

---

## 备选方案

### 路线 B：纯原生 SwiftUI 重写

- 优势：最佳 iOS 原生体验，CarPlay 天然支持
- 劣势：需重写全部 UI 和业务逻辑（约 200+ 文件），无法与 Android 版共享代码，维护两套独立代码库

### 路线 C：混合方案（核心 TS 共享 + 原生 UI）

- 优势：核心逻辑共享，UI 原生
- 劣势：TS 和 Swift 之间的桥接层复杂，状态同步成本高，与路线 A 相比增加大量额外工作