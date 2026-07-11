# ADR-0004: 项目结构与仓库组织

## 状态

已修订 (2026-07-11) — 纯 iOS 版本，移除 Android 代码

## 背景

本项目将原 Android 版 lx-music-mobile 移植为纯 iOS 版本。需要决定 iOS 项目的目录结构如何组织，以及如何处理原 Android 代码和依赖。

## 决策

**移除 `android/` 目录及所有 Android 专属依赖，仅保留 `ios/` 目录和 `src/` TypeScript 代码。iOS 原生代码按模块化组织，3 个原生模块（播放器、文件系统、元数据）各自独立目录。**

### 目录结构

```
lx-music-mobile/
├── src/                              # TypeScript 代码
├── ios/                              # iOS 原生代码（唯一原生平台）
│   ├── Podfile                       # CocoaPods 依赖管理
│   ├── LxMusicMobile.xcworkspace/
│   ├── LxMusicMobile.xcodeproj/
│   ├── LxMusicMobile/                # 主 App Target
│   │   ├── AppDelegate.mm            # 应用入口（ObjC++，RNN 集成）
│   │   ├── Info.plist
│   │   ├── LxMusicMobile-Bridging-Header.h  # Swift/ObjC 桥接
│   │   ├── Modules/                  # RN 原生模块
│   │   │   ├── Player/
│   │   │   │   ├── PlayerModule.swift        # RCTBridgeModule
│   │   │   │   ├── LXMusicPlayerModule.m     # ObjC Bridge
│   │   │   │   ├── PlayerService.swift       # AVQueuePlayer 封装
│   │   │   │   └── NowPlayingManager.swift   # MPNowPlayingInfoCenter
│   │   │   ├── FileSystem/
│   │   │   │   ├── FileSystemModule.swift
│   │   │   │   └── LXMusicFileSystemModule.m
│   │   │   └── MediaMetadata/
│   │   │       ├── MediaMetadataModule.swift
│   │   │       └── LXMusicMediaMetadataModule.m
│   │   └── CarPlay/                  # CarPlay 独立入口
│   │       ├── CarPlaySceneDelegate.swift
│   │       ├── Templates/
│   │       │   ├── NowPlayingController.swift
│   │       │   ├── ListController.swift
│   │       │   ├── SearchController.swift
│   │       │   └── TabBarController.swift
│   │       └── Bridge/
│   │           └── CarPlayDataBridge.swift
│   └── LxMusicMobileTests/           # 单元测试
├── package.json
├── tsconfig.json
└── metro.config.js
```

### 依赖处理全景

| 原 Android 依赖 | iOS 方案 | 处理方式 |
|----------------|---------|---------|
| `react-native-track-player` (自定义 fork) | 新建 `ios/LxMusicMobile/Modules/Player/` | 移除依赖，原生模块替代 |
| `react-native-background-timer` (自定义 fork) | 播放器模块内建 Swift Timer + 原生 setTimeout | 移除依赖 |
| `react-native-file-system` (自定义 fork) | 新建 `ios/LxMusicMobile/Modules/FileSystem/` | 移除依赖，原生模块替代 |
| `react-native-local-media-metadata` (自定义 fork) | 新建 `ios/LxMusicMobile/Modules/MediaMetadata/` | 移除依赖，原生模块替代 |
| `react-native-fs` | 保留（官方支持 iOS） | 保留 |
| 其余 JS 依赖 | 全部保留（纯 JS 或官方支持 iOS） | 保留 |

### 代码改动量预估

| 文件 | 改动类型 | 改动量 |
|------|---------|--------|
| `src/utils/request.js` | 移除 `BackgroundTimer`，使用原生 `setTimeout` | ~5 行 |
| `src/utils/fs.ts` | 适配 iOS 路径常量，移除 Android 专属函数 | ~15 行 |
| `src/plugins/player/utils.ts` | 移除 `BackgroundTimer`，使用原生 `setTimeout` | ~10 行 |
| `src/plugins/player/playList.ts` | 移除 `BackgroundTimer`，使用原生 `setTimeout` | ~5 行 |
| `src/components/` 中的 UI 组件 | 移除 `Platform.OS === 'android'` 分支 | ~30 行 |
| `src/screens/` | 移除 `Platform.OS === 'android'` 分支 | ~10 行 |
| 其余所有 `src/` 代码 | **零改动** | 0 行 |

## 后果

### 优势

- 代码库精简：移除 `android/` 目录和 Android 专属依赖，减少维护负担
- 单一平台：无需兼顾 Android 行为差异，代码更简洁
- 构建简单：仅需 macOS + Xcode 环境，无需 CI

### 代价

- 构建和测试需在真实 macOS 环境中手动进行（不使用 CI 自动构建）
- iOS 原生代码维护者需掌握 Swift + React Native Bridge 双重技能

### 不做的事

- **不保留 `android/` 目录**：纯 iOS 版本，无需维护 Android 代码
- **不使用 CI 自动构建**：由开发者在真实 macOS 环境中手动构建和测试
- **不使用 Git Submodule**：增加检出和同步成本，对单人维护项目无实际收益
