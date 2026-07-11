# ADR-0004: 项目结构与仓库组织

## 状态

已采纳 (2026-07-11)

## 背景

iOS 移植需要在现有仓库中加入 iOS 原代码。需要决定是在同一仓库中扩建还是创建独立仓库，以及 iOS 项目的目录结构如何组织。

## 决策

**在同一仓库中新建 `ios/` 目录，与现有 `android/` 并列，共享 `src/` TypeScript 代码。iOS 原生代码按模块化组织，3 个新建原生模块（播放器、文件系统、元数据）各自独立目录。**

### 目录结构

```
lx-music-mobile/
├── src/                              # 共享 TypeScript 代码
├── android/                          # 现有 Android 原生代码
├── ios/                              # 新建 iOS 原生代码
│   ├── Podfile                       # CocoaPods 依赖管理
│   ├── LXMusic.xcworkspace/
│   ├── LXMusic.xcodeproj/
│   ├── LXMusic/                      # 主 App Target
│   │   ├── AppDelegate.swift         # 应用入口
│   │   ├── SceneDelegate.swift       # CarPlay Scene 入口
│   │   ├── Info.plist
│   │   ├── Modules/                  # RN 原生模块
│   │   │   ├── Player/
│   │   │   │   ├── PlayerModule.swift        # RCTBridgeModule
│   │   │   │   ├── PlayerModule.m            # ObjC Bridge Header
│   │   │   │   ├── PlayerService.swift       # AVQueuePlayer 封装
│   │   │   │   └── NowPlayingManager.swift   # MPNowPlayingInfoCenter
│   │   │   ├── FileSystem/
│   │   │   │   ├── FileSystemModule.swift
│   │   │   │   └── FileSystemModule.m
│   │   │   └── MediaMetadata/
│   │   │       ├── MediaMetadataModule.swift
│   │   │       └── MediaMetadataModule.m
│   │   └── CarPlay/                  # CarPlay 独立入口
│   │       ├── CarPlaySceneDelegate.swift
│   │       ├── Templates/
│   │       │   ├── NowPlayingController.swift
│   │       │   ├── ListController.swift
│   │       │   ├── SearchController.swift
│   │       │   └── TabBarController.swift
│   │       └── Bridge/
│   │           └── CarPlayDataBridge.swift
│   └── LXMusicTests/                 # 单元测试
├── package.json
├── tsconfig.json
└── metro.config.js
```

### 依赖替换全景

| 原 Android 依赖 | iOS 方案 | 类型 |
|----------------|---------|------|
| `react-native-track-player` (自定义 fork) | 新建 `ios/LXMusic/Modules/Player/` | 原生模块替换 |
| `react-native-background-timer` (自定义 fork) | 移除，播放器模块内建 Swift Timer | 移除 |
| `react-native-file-system` (自定义 fork) | 新建 `ios/LXMusic/Modules/FileSystem/` | 原生模块替换 |
| `react-native-local-media-metadata` (自定义 fork) | 新建 `ios/LXMusic/Modules/MediaMetadata/` | 原生模块替换 |
| `react-native-fs` | 保留（官方支持 iOS） | 保留 |
| 其余 10 个 JS 依赖 | 全部保留（纯 JS 或官方支持 iOS） | 保留 |

### 共享代码改动量预估

| 文件 | 改动类型 | 改动量 |
|------|---------|--------|
| `src/utils/request.js` | `BackgroundTimer` → `setTimeout`（3 处） | ~5 行 |
| `src/utils/fs.ts` | 路径常量适配 iOS（`SDCardDir` → `DocumentDir`）、Android 专属函数返回空 | ~15 行 |
| `src/components/` 中的 UI 组件 | `Platform.OS` 条件分支（SafeArea、字体、返回手势） | ~30 行 |
| `src/screens/` | `Platform.OS` 条件分支 | ~10 行 |
| 其余所有 `src/` 代码 | **零改动** | 0 行 |

## 后果

### 优势

- 版本一致性：`core/` 层一次修改，双端生效
- 工具链兼容：React Native 原生支持 `android/` + `ios/` 并行结构，Metro bundler 自动识别
- CI 可共享：Lint、TypeScript 检查、单元测试在单次 CI 运行中覆盖双端

### 代价

- GitHub Actions 需添加 `macos-latest` runner（成本约 10x Linux runner），但免费额度对个人项目通常够用
- iOS 原生代码维护者需掌握 Swift + React Native Bridge 双重技能

### 不做的事

- **不拆分独立仓库**：`react-native init` 标准项目结构就是 `android/` + `ios/` + `src/`，拆分违反生态约定
- **不使用 Git Submodule**：增加检出和同步成本，对单人维护项目无实际收益