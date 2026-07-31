# 数据格式

本页描述 `Anime` 数据模型（`lib/features/anime/models/anime.dart`）、所有遇到未知 JSON 处使用的向前兼容模式，以及应用持久化到磁盘的完整文件清单。这些记录如何跨设备合并见 [`sync.md`](sync.md) 和 [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md)。构建在这些字段之上的季度归属逻辑见 [`features/anime-tracking.md`](features/anime-tracking.md)。

## `Anime` 模型

### 身份

- `id` — UUID，在编辑、同步和合并中保持稳定。
- `title` — 主显示标题（中文/英文）。为 null 时改用 `titleJa`。
- `titleJa` — 可选的日文标题。`title`/`titleJa` 至少设置一个。
- `season` — 季标识字符串，如 `"Season 1"`。

### URL

- `infoUrl` — 来源/参考页面（也是搜索结果保存其来源 URL 的地方）。
- `watchUrl` — 流媒体/观看页面。

### 播出日程

- `airDayOfWeek` — 动画播出的星期几，日本时间，编码为 **周一 = 1 .. 周日 = 7**。当 `effectiveType` 为 `allAtOnce` 时为 null。
- `airTime` — 日本时间的播出时刻字符串，如 `"21:00"`。深夜档使用超过午夜的值，如 `"25:00"`（指下一个日历日的 01:00）——这是日本电视排播的真实惯例，模型的 `getEpisodeAirDate()` 显式支持通过把小时值 ≥ 24 的时长加到计划播出日期的午夜上来解析。
- `firstAirDate` — 可选的首集日期。

当 `airDayOfWeek` 与 `firstAirDate` 的星期几不一致时，剧集日期向前吸附到播出日的下一次出现，因此第 1 集绝不会早于 `firstAirDate`。`getEpisodeAirDate()`（JST 时间戳，应用深夜回卷）和 `getEpisodeCalendarDate()`（JST 日历日期，不回卷——即使对 `24:00`/`25:00` 时刻也留在计划播出日期上）都实现同样的前向吸附。

### 剧集

- `startEpisode` — 首集编号，默认 1。
- `endEpisode` — 末集编号；`null` 表示长期连载/未知终点。`totalEpisodes` 在 `endEpisode` 已设置时派生为 `endEpisode! - startEpisode + 1`，否则为 `null`。
- `episodeStatuses` — 逐剧集状态映射（键 = 剧集编号），值为 `EpisodeStatus`（`unwatched`、`watched`、`skippedThisWeek`）。
- `episodeWeekOffsets` — 为一次性放送、延期和日程修正做的累计周调整。`weekOffsetFor(episodeNumber)` 对每个键 `<=` 请求剧集编号的偏移条目求和，该累计偏移直接进入两个剧集日期 getter 和季度归属（见 [`features/anime-tracking.md`](features/anime-tracking.md)）。

### 状态派生

观看状态（`AnimeViewingStatus`：`completed`、`watching`、`dropped`、`notStarted`）**由 `episodeStatuses` 派生**，不作为单独字段存储。没有持久化的"状态"值会与剧集数据失同步。

### `AnimeType`

```dart
enum AnimeType {
  singleCour,   // ≤13 episodes
  halfYear,     // 14–26 episodes
  fullYear,     // 27–52 episodes
  longRunning,  // no end episode set, ongoing
  allAtOnce,    // all episodes released at once (Netflix style)
}
```

- `autoType` 纯粹按上面阈值从集数推断类型。
- `manualType` 是可选的覆盖，设置后**总是优先**：`effectiveType` 在 `manualType` 存在时返回它，否则回退到 `autoType`。

### `AnimeRating`

可选的逐动画评分，带一个手动总分和五个子分，全部在 0–10 量表上：

- `overall` — 手动总分。
- `visual`、`story`、`character`、`music`、`enjoyment` — 子分（画面/导演、剧情、角色、音乐/音效、观感/推荐）。

`effectiveOverall` 在 `overall` 已设置时返回它；否则对非 null 的子分求平均（`scores.fold(...) / scores.length`），只在每个子分也都是 null 时返回 `null`。简言之：**手动总分优先；为空时，有效总分为已填子分的平均。**

### 兼容性：未知 JSON 字段保留（`extraJson`）

`Anime`、`AnimeRating` 和 `AnimeData`（顶层 `{animes: [...]}` 容器）各携带一个 `extraJson` 映射，保存当前应用版本不认识的任何 JSON 键。模式：

- `fromJson()` 把 `extraJson` 计算为"原始 JSON 中每个键减去该类型的已知键"（经由内部 `_unknownJson` 辅助），并且把任何无法按预期类型解析的值（如不是 `num` 的评分子分）也路由回 `extraJson`，而不是丢弃。
- `toJson()` 从 `extraJson` 的副本开始，再把已知字段覆盖在上层，因此未知键原样随行。
- `withPreservedUnknownJson(sources)` 合并来自多个候选来源的 `extraJson`（如同步合并中同一条记录的本地和远程副本），使*本*版本应用不认识的、但任一侧存在的字段在合并中存活。

这正让旧版应用在常规保存、导入或同步合并中不会静默删除新版引入的字段——`extraJson` 如何具体参与逐记录同步合并见 [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md) 中的合并引擎。

### 时间戳

`modifiedAt` 是 `DateTime`，总是以 **UTC** 存储和比较（`DateTime.now().toUtc()`）。本地时间的 `modifiedAt` 值会破坏同步冲突检测，因为三方合并算法要比较可能处于不同时区的设备的时间戳——见 [`sync.md`](sync.md)。

### JSON 美化打印

所有写入磁盘的 JSON——数据文件、同步上传、备份——都使用 `JsonEncoder.withIndent('  ')`。这不只是外观问题：同步以与本地 `AnimeStorage` 保存相同的格式写入合并 JSON，因此未变化的文件在下一次同步时命中原始字符串相等快速路径，而不是触发虚假的重新上传。

## 持久化数据清单

桌面端默认应用数据目录是 `Documents/MyAnime`，移动端是平台应用文档目录。自定义存储路径存储在 `storage_config.json` 中；更改路径会迁移数据文件、备份和图像。

| 数据 | 文件 | 同步 | 备注 |
| --- | --- | --- | --- |
| 动画记录 | `anime_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录；未知字段保留 |
| 封面图像 | `images/` | 是 | 按文件名仅引用添加式同步 |
| 主题模式 | `storage_config.json` | 否 | 设备特有偏好 |
| 语言区域 | `storage_config.json` | 否 | 设备特有偏好 |
| 日历周起始日 | `storage_config.json` | 否 | 设备特有偏好，默认周日，日式主页日历布局激活时忽略 |
| 主页日历布局 | `storage_config.json` | 否 | 设备特有的本地 vs 日式日历标签偏好 |
| 主页日历时间基准 | `storage_config.json` | 否 | 设备特有的 JST vs 本地日期网格偏好；动画日程时间戳仍基于 JST |
| 存储路径覆盖 | `storage_config.json` | 否 | 设备特有路径 |
| 自动备份启用 | `storage_config.json` | 否 | 设备特有配置 |
| 备份保留天数 | `storage_config.json` | 否 | 设备特有配置 |
| 提醒启用/时间/上次提醒日期 | `storage_config.json` | 否 | 设备特有的本地时间提醒配置和内部状态 |
| API 服务器启用/监听地址/端口/凭据 | `storage_config.json` | 否 | 本地桌面配置；凭据不得被提交 |
| 托盘和开机自启偏好 | `storage_config.json` | 否 | 本地桌面配置 |
| WebDAV 配置 | `webdav_config.json` | 否 | 仅本地秘密/配置 |
| 同步基线快照 | `.sync_base/anime_data.json` | 否 | 本地合并跟踪 |
| 本地备份 | `backups/backup_*.json` | 否 | 本地恢复；v2 捆绑引用去重后的图像 blob |
| 备份图像 blob | `backups/blobs/` | 否 | 内容寻址（`sha256`）、跨备份共享、引用计数 GC |

### `storage_config.json`

保存上表中除 WebDAV 配置外的每个设备本地偏好：主题模式、语言区域、日历周起始/布局/时间基准偏好、存储路径覆盖、自动备份启用 + 保留天数（`backupRetentionDays`）、提醒设置、API 服务器启用/监听地址/端口/凭据，以及托盘/开机自启偏好。此文件的任何内容都不被同步——它刻意设备特有。

### `webdav_config.json`

WebDAV 连接详情和同步偏好（服务器 URL、凭据、自动同步开关）。它本身绝不参与同步——它是驱动同步的配置，不是同步会触碰的数据。见 [`sync.md`](sync.md)。

### `.sync_base/`

保存 `.sync_base/anime_data.json`（用作下一次同步三方合并基线的最近已知合并快照）和 `.sync_base/upload_lock.json`（让下一次启动检测到中途被中断的上传）。两者如何被使用见 [`sync.md`](sync.md)。

### `backups/`

- `backups/backup_*.json` — 备份捆绑（v2 格式见 [`backup-restore.md`](backup-restore.md)）。
- `backups/blobs/<sha256><ext>` — 被捆绑经由 `_imageRefs` 映射引用的内容寻址图像 blob。

### `.myanimeitem`（分享/文件导入格式）

用于导出/导入单个或多个动画的 JSON 文件（周边 UI 流程见 [`features/share-and-import.md`](features/share-and-import.md)）。

- **版本 1**（单个动画）：`{"version": 1, "anime": {...}, "coverImage": "<base64>", "coverImageExt": ".jpg"}` — `coverImage`/`coverImageExt` 可选。
- **版本 2**（多动画捆绑）：`{"version": 2, "items": [{"anime": {...}, "coverImage": "<base64>", "coverImageExt": ".jpg"}, ...]}` — 每个条目与 v1 有相同的可选封面字段。

导出在写入前从每个 `anime` 负载中剥离个人观看数据（`episodeStatuses`、`episodeWeekOffsets`）。导入总是分配新 UUID，绝不覆盖既有的本地记录；多动画捆绑导入运行与 [`features/duplicate-detection.md`](features/duplicate-detection.md) 相同的冲突检测来判断传入记录是否与本地记录冲突，并为每个冲突提供保留本地/使用导入/合并选项。
