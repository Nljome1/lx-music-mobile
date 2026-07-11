# ADR-0003: CarPlay 集成策略

## 状态

已修订 (2026-07-11) — 纯 iOS 版本

## 背景

iOS 版本支持 CarPlay 车载模式。CarPlay 的 UI 由 CarPlay 系统渲染，只能使用 Apple 提供的有限模板（`CPListTemplate`、`CPNowPlayingTemplate`、`CPSearchTemplate` 等），不能嵌入 React Native 自定义视图。这意味着 CarPlay 端的 UI 必须用原生 Swift 实现。

## 决策

**CarPlay 作为独立原生入口，通过 `CarPlaySceneDelegate` 实现，纯 Swift 代码渲染 CarPlay 模板，通过共享的 Bridge 调用 `core/` 层获取数据。**

### 架构设计

```
ios/LxMusicMobile/CarPlay/
├── CarPlaySceneDelegate.swift       # CarPlay Scene 入口，注册模板
├── Templates/
│   ├── NowPlayingController.swift   # CPNowPlayingTemplate（播放界面）
│   ├── ListController.swift         # CPListTemplate（歌单列表、排行榜）
│   ├── SearchController.swift       # CPSearchTemplate（搜索）
│   └── TabBarController.swift       # CPTabBarTemplate（底部导航）
└── Bridge/
    └── CarPlayDataBridge.swift      # 与 JS 层 core/ 的数据桥接
```

### 数据流

```
CarPlay 用户操作（点击歌曲/搜索/切换列表）
        ↓
CarPlayDataBridge.swift  → 通过 RN EventEmitter 发送事件到 JS
        ↓
core/ 层处理业务逻辑（搜索、获取歌单、播放控制）
        ↓
结果通过 RN EventEmitter 回调 → CarPlayDataBridge.swift
        ↓
CarPlay 模板更新 UI
```

### 可用模板分配

| CarPlay 模板 | 映射功能 |
|-------------|---------|
| `CPTabBarTemplate`（最多 4 个 Tab） | 首页 / 排行榜 / 搜索 / 我的列表 |
| `CPNowPlayingTemplate` | 正在播放（封面、标题、进度、歌词、上下曲） |
| `CPListTemplate` | 歌单详情、排行榜列表、我的列表 |
| `CPSearchTemplate` | 音乐搜索 |
| `CPGridTemplate` | 歌单封面网格展示 |

### 关键约束

- CarPlay 不允许自定义 UI 控件，所有交互必须通过标准模板
- `CPNowPlayingTemplate` 的播放控制（播放/暂停/上下曲）自动映射到 `MPRemoteCommandCenter`，与手机端播放器原生模块共享同一套命令处理
- CarPlay 模板的 section 数量限制为 **最多 12 个**，每个 section 的 item 限制为 **最多 20 个**（iOS 14+），需在数据层做分页适配

## 后果

### 优势

- 手机端和 CarPlay 端共享同一套播放器引擎和业务逻辑
- `MPNowPlayingTemplate` 与 `MPNowPlayingInfoCenter` 自动联动，播放/暂停/切歌无需额外代码
- 独立入口设计，不影响手机端 React Native UI 层的稳定性

### 代价

- CarPlay UI 代码与手机端 React Native UI 完全独立，功能变更需双端同步
- `CPListTemplate` 的分页限制（20 条/页）与手机端无限滚动体验不同，需在 Bridge 层做适配
- CarPlay 开发和调试需要 MFI 认证或 CarPlay 模拟器（Xcode 内置支持有限）

### 不做的事

- **不尝试在 CarPlay 中嵌入 React Native 视图**：Apple 不允许
- **不通过 RN 原生模块命令式控制 CarPlay 模板**：增加不必要的 Bridge 层复杂度，且 CarPlay 的模板生命周期由系统管理，命令式控制违反 Apple 设计规范
