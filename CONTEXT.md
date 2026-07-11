# LX Music Mobile — 领域术语表

## 有界上下文

本项目为单一下文（Monolith），`CONTEXT.md` 位于仓库根目录。

---

## 核心术语

| 术语 | 英文 | 定义 |
|------|------|------|
| **音源** | Music Source / API Source | 提供音乐数据（搜索、歌单、排行榜、歌词、音频流）的外部平台接口。当前支持 `kw`（酷我）、`kg`（酷狗）、`mg`（咪咕）、`tx`（腾讯）、`wy`（网易）等别名。 |
| **自定义源** | Custom Source | 用户自行编写的 JavaScript 脚本，遵循特定接口规范，可替代内置音源提供音乐数据。通过 `user_api` 前缀标识。 |
| **音源切换** | API Source Switching | 在多个音源之间动态切换的能力，切换后搜索、播放等操作将使用新音源。由 `core/apiSource.ts` 管理。 |
| **我的列表** | My List | 用户本地创建和管理的歌单集合，存储在本地设备，可通过同步服务多端同步。 |
| **试听列表** | Trial List | 系统默认列表，从在线列表播放歌曲时自动将歌曲添加到此列表后再播放。 |
| **稍后播放** | Play Later | 一个优先级最高的临时播放队列，点击"下一曲"时优先消耗此队列中的歌曲。 |
| **临时播放列表** | Temp Play List | 用于临时播放整个歌单/排行榜的队列，不持久化，切换列表时可能被清空。 |
| **已播放列表** | Played List | 记录已播放歌曲的队列，用于"上一曲"功能和随机播放去重。 |
| **歌曲换源** | Song Source Replacement | 将列表中某首歌曲替换为另一音源的同名歌曲。v1.7.1 起改为物理替换（删除原歌曲 + 插入新歌曲），而非软链接。 |
| **不喜欢歌曲** | Dislike List | 用户标记的不喜欢歌曲规则列表，切歌时自动跳过匹配的歌曲。支持同步。 |
| **同步服务** | Sync Service | 独立部署的 WebSocket 服务，用于多端（PC 端 + 移动端）列表数据实时同步。支持私人部署。 |
| **深链接** | Deep Link | 通过 `lxmusic://` URL Scheme 从外部调用 App 的特定功能（播放歌曲、打开歌单、导入文件等）。 |
| **音频卸载** | Audio Offload | Android 特有功能，将音频解码任务卸载到专用 DSP 硬件以降低功耗。iOS 无此概念。 |
| **桌面歌词** | Desktop Lyric | 以悬浮窗形式在其他 App 上方显示的歌词，Android 需要悬浮窗权限。 |
| **蓝牙歌词** | Bluetooth Lyric | 通过蓝牙协议（AVRCP）将歌词信息发送到车载/蓝牙设备显示。iOS 通过 `MPNowPlayingInfoCenter` 实现。 |
| **Any Listen** | — | 作者的新项目，面向自建服务器播放本地/WebDAV 音乐，与 LX Music 独立发展。LX Music 支持读取 Any Listen 歌词标签。 |

---

## 插件术语

| 术语 | 定义 |
|------|------|
| **播放器插件** (`plugins/player/`) | 封装原生播放器能力的插件层，提供播放列表管理、播放服务、React Hook 接口。iOS 移植时此层为替换目标。 |
| **同步插件** (`plugins/sync/`) | 封装 WebSocket 同步能力的插件层，包含客户端、认证、模块化同步处理。 |
| **歌词插件** (`plugins/lyric.ts`) | 歌词解析插件，处理 LRC 歌词解析、偏移调整、翻译、罗马音转换。 |
| **存储插件** (`plugins/storage.ts`) | 键值持久化插件，封装 `AsyncStorage`，支持超过 500KB 的数据自动分片存储。 |

---

## 平台术语

| 术语 | 定义 |
|------|------|
| **Android 原生模块** | 在 `android/` 目录下，用 Java/Kotlin 编写的 React Native 原生桥接代码。 |
| **iOS 原生模块** | 在 `ios/` 目录下，用 Swift 编写的 React Native 原生桥接代码。iOS 移植的核心产出物。 |
| **CarPlay Scene** | iOS 车载模式的独立 UI 入口，通过 `CPTemplate` 系列模板渲染，不依赖 React Native 视图层。 |
| **Scoped Storage** | Android 分区存储 API，通过 `AndroidScoped` 封装的 SAF 权限模型。iOS 无对应概念。 |

---

## 状态模块

所有 `store/` 与 `core/` 子模块一一对应，命名一致：

`common` · `dislikeList` · `hotSearch` · `leaderboard` · `list` · `player` · `search` · `setting` · `songlist` · `sync` · `theme` · `userApi` · `version`

---

*最后更新：2026-07-11*