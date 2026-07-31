# MyAnime!!!!! 文档（概念）

**MyAnime!!!!!**（每个面向用户的名称中都有五个感叹号——应用标题、安装包元数据、macOS bundle 名称、iOS 显示名称和窗口标题）是一款隐私优先的动画追番应用。它结合了感知 JST 的日历、季度管理、统计、多源动画搜索、观看进度跟踪、每日提醒、分享/导出流程、WebDAV 同步、本地备份、桌面本地 API 服务器、托盘行为、开机自启，以及假名速查模块。

- **作者 / 包 id：** `yuanzhe`、`com.yuanzhe.my_anime`
- **许可证：** GPL-3.0
- **平台：** Windows、Android、iOS、macOS（Linux 项目文件存在，部分桌面服务有 Linux 分支，但 Linux 不是主要发布目标；不面向 Web）
- **框架：** Flutter，Dart SDK `^3.11.3`；CI 使用 Flutter `3.44.2`

本树保存**概念**文档——架构、数据格式、算法和实例演练——为需要理解应用*为什么*这样行为的用户和代理而写。逐函数的 API 文档单独位于 [`functions/`](functions/)（不在此索引范围内），翻译说明在 [`translation-guide.md`](translation-guide.md) 中。

**这些文档是代码的权威描述。** 仓库的 `AGENTS.md` 刻意只保留给代理的指令——工作流、编写规则、行为契约和发布流程——并在这里指向其余一切。代码变更时，这些页面先行更新；当文档与代码不一致时，以代码核实后修正页面。

共享的 WebDAV 同步、备份和 ZIP 引擎不在此仓库。它们位于嵌入在 `packages/myapps_data` 的 `myapps_data` 包中，文档在 `packages/myapps_data/doc/en-us/`。

## 目录

### 核心概念

- [`architecture.md`](architecture.md) — 应用外壳、状态管理、导航、l10n、仓库布局，以及整个代码库遵循的核心架构规则。
- [`data-formats.md`](data-formats.md) — `Anime` 模型的字段、磁盘 JSON 格式，以及完整持久化数据清单（哪些同步、哪些仅设备本地）。
- [`sync.md`](sync.md) — 端到端的 WebDAV 同步算法：加锁、下载、三方合并、冲突处理、重试、心跳、图像同步和自动同步触发。
- [`backup-restore.md`](backup-restore.md) — 本地备份格式 v2（内容寻址图像 blob、GC、保留）、恢复安全规则，以及 ZIP/Markdown 导入导出。
- [`platform-notes.md`](platform-notes.md) — Windows/macOS/iOS/Android 平台注意事项，以及桌面本地 API 服务器、托盘和开机自启行为。
- [`ci-cd.md`](ci-cd.md) — CI 任务和工作流注意事项、构建/校验命令集、`tool/` 脚本和全新克隆（子模块）步骤。
- [`version-history.md`](version-history.md) — 逐版本摘要。在改动一个看起来奇怪的行为前值得先查；多条记录是刻意的安全修复。

### 功能区域

- [`features/anime-tracking.md`](features/anime-tracking.md) — `Anime` 模型和季度归属/跟踪逻辑。
- [`features/home-management-statistics.md`](features/home-management-statistics.md) — 主页、管理和统计三个标签。
- [`features/kana-reference.md`](features/kana-reference.md) — 纯 UI 的假名速查模块。
- [`features/multi-source-search.md`](features/multi-source-search.md) — 多源动画搜索、去重、模糊匹配和风味门控。
- [`features/share-and-import.md`](features/share-and-import.md) — 分享/导出流程和 `.myanimeitem` 文件导入/导出。
- [`features/duplicate-detection.md`](features/duplicate-detection.md) — 重复分组和合并逻辑。
- [`features/reminders.md`](features/reminders.md) — 移动/桌面提醒通知调度。

### 算法

- [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md) — 深入探讨支撑 WebDAV 同步的泛型 `mergeRecords<T>` 引擎。

### 实例演练

- [`examples/sync-walkthrough.md`](examples/sync-walkthrough.md) — 一个具体的双设备同步场景，从自动解决到手动冲突解决。
- [`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md) — 一个具体的备份/损坏/恢复场景，包括 WebDAV 自动同步交互。

## 不在此处覆盖

- `doc/en-us/functions/` — 逐源文件的函数索引页（Tier A/B 声明表）。单独维护。
- `doc/zh-cn/` — 计划中的未来翻译工作；不在本批次文档范围内。
