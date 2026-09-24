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

### `AnimeExternalMeta` 与 `AnimeExternalRating`

可选的每部番剧记录，保存**由在线搜索从外部番剧资料库拉取的公开元数据**（见
[`features/multi-source-search.md`](features/multi-source-search.md)）。存放在 `externalMeta` 键下：

```json
"externalMeta": {
  "synonyms": ["Frieren at the Funeral"],
  "titleRomaji": "Sousou no Frieren",
  "titleEn": "Frieren: Beyond Journey's End",
  "format": "TV",
  "status": "FINISHED",
  "durationMinutes": 24,
  "genres": ["Adventure", "Drama"],
  "studios": ["Madhouse"],
  "endDate": "2024-03-22T00:00:00.000Z",
  "ratings": [
    {
      "source": "AniList",
      "sourceUrl": "https://anilist.co/anime/154587",
      "score": 9.2,
      "scoreMax": 10.0,
      "votes": 300000,
      "rank": 1,
      "fetchedAt": "2026-08-26T12:00:00.000Z"
    }
  ],
  "refreshedAt": "2026-08-26T12:00:00.000Z"
}
```

- `synonyms` — 各语言的别名，按各来源的报告原样保存。
- `titleRomaji` / `titleEn` — 罗马音标题与英文标题。它们**不会**替换 `title` / `titleJa`，只是额外的
  名称，用于展示、搜索对话框的「全部名称」面板，以及两阶段搜索的跨语言补搜查询。
- `format` — 作品形式（`TV`、`MOVIE`、`OVA`、`ONA`、`SPECIAL`），按来源报告原样保存。它**不是**
  `AnimeType`：`AnimeType` 描述的是季度长度并驱动排期，而 `format` 只是描述性元数据。
- `status` — 各来源报告的播出状态（`FINISHED`、`RELEASING`、`Finished Airing` 等）。刻意不做归一化：
  观看状态仍由 `episodeStatuses` 推导，此字段绝不参与其中。
- `durationMinutes` — 单集时长。
- `genres`、`studios` — 类型标签与制作公司。
- `endDate` — 已知时的完结日期。
- `refreshedAt` — 上次刷新的 UTC 时间戳。
- `watchProgress` — 自 1.5.7 起，观看站点（anime1.me）在上次检查时为 `watchUrl` 列出的内容，是一个
  `AnimeWatchProgress` 对象：

  ```json
  "watchProgress": {
    "sourceUrl": "https://anime1.me/?cat=1935",
    "catId": 1935,
    "latestEpisode": 9,
    "episodesText": "連載中(09)",
    "ongoing": true,
    "checkedAt": "2026-09-01T12:00:00.000Z"
  }
  ```

  `sourceUrl` 是读取该记录时所用的 `watchUrl`；`Anime.validWatchProgress` 只在两者仍然一致时返回该记录，因此
  改了链接就会隐藏过期的集数。`latestEpisode` 对剧场版与特别篇为 `null`，`episodesText` 原样保留站点的单元格
  （`1-12+OVA`）。对象内的未知键与其他地方一样被保留。它放在 `externalMeta` 里，因为它是同一类数据——经
  `AnimeStorage.patchExternalMeta` 写入的公开站点信息缓存，绝不修改 `modifiedAt`。见
  [`features/watch-url-lookup.md`](features/watch-url-lookup.md)。
- `relations` —— 自 1.6.0 起，各资料库列出的关联作品，以 `AnimeExternalRelation` 条目保存：

  ```json
  "relations": [
    {
      "source": "AniList",
      "type": "sequel",
      "targetUrl": "https://anilist.co/anime/12345",
      "title": "葬送のフリーレン 第2期",
      "format": "TV"
    },
    {
      "source": "AniList",
      "type": "other",
      "targetUrl": "https://anilist.co/anime/67890",
      "title": "Crossover Short",
      "format": "ONA",
      "rawType": "CHARACTER"
    }
  ]
  ```

  `source` 是资料库的显示名，`targetUrl` 是关联作品在该资料库上的页面。`type` 归一化为 `prequel`、
  `sequel`、`parent`、`sideStory`、`summary`、`spinOff`、`alternative` 或 `other`；来源自己的关联名映射为
  `other` 时，原样保留为 `rawType`。`title` 与 `format` 取来源报告的值（Jikan 与 bangumi.tv 不提供
  format）。只保留动画目标。本版本不认识的 `type` 在写回时原样保留，而不会降级为 `other`；每个条目内的未知键
  与其他地方一样被保留。只由刷新经 `AnimeStorage.patchExternalMeta` 写入，绝不修改 `modifiedAt`；搜索结果从不
  携带关联关系。列表为空时省略该键。系列关联会读取它——见
  [`features/series-linking.md`](features/series-linking.md)。

**`ratings` 与 `AnimeRating` 刻意分离。** `AnimeRating` 保存的是*用户自己*的评分，任何抓取都不会写入它；
`externalMeta.ratings` 保存的是各外部资料库的评分，统一归一化到 10 分制（`scoreMax`，默认 `10`）。每条
记录都保留它的来源 `sourceUrl`，这正是后续刷新时重新查询的对象——刷新流程见
[`features/multi-source-search.md`](features/multi-source-search.md)。记录以 `source` 为键：刷新某个
来源只会替换该来源的记录，其余保持不变。

`AnimeExternalMeta.mergedWith(other)` 实现这一合并。标量与列表字段只在 `other` 确实提供时才取用，因此
对 AniList 刷新（部分作品它不报告制作公司）绝不会抹掉 bangumi.tv 贡献的制作公司。`relations` 与 `ratings`
一样按来源替换：提供了关联关系的来源替换它自己先前的列表，其他来源的列表保留。

**整个对象为空时会被省略**，规则与 `AnimeLocalArchive` 相同：全空记录的 `hasAnyData` 为 false，此时
`Anime.toJson()` 不写 `externalMeta` 键，`Anime.fromJson()` 也会丢弃解析出的全空记录。从未应用过搜索
结果的番剧，其序列化结果与该字段存在之前完全一致。

**它会与不会去到哪里。** 与 `AnimeLocalArchive` 不同，这是关于作品本身的公开信息而非个人基础设施信息，
因此**不会**从分享文件中剥离。它的每个部分——包括 `ratings`、`watchProgress` 和 `relations`——都以同样方式流转：

| 场景 | 是否包含？ |
|---|---|
| 磁盘上的 `anime_data.json` | **是** |
| WebDAV 同步 | **是** —— 走普通的整记录合并，无需改动同步层 |
| 备份包 | **是** |
| 本地 HTTP API | **是** |
| 分享图片卡片 | **否** —— 从不绘制 |
| `.myanimeitem` 分享文件 | **是** —— 公开元数据，不是个人数据；自 1.6.0 起导入会带过它（更早的版本导入时会丢弃） |

### `AnimeLocalArchive`

可选的逐动画**本地下载存档**记录——是否保留了本地资源、什么画质、几份、放在哪里。存放在 `localArchive` 键下：

```json
"localArchive": {
  "archived": true,
  "source": "bd",
  "resolution": "fhd1080p",
  "copies": 2,
  "location": "NAS-01, HDD-C3"
}
```

- `archived` — 是否保留了本地资源。这是"总开关"；其余都是明细。
- `source` — `ArchiveSource`：`bd`、`dvd`、`web`、`tv`、`other`。显示为 `BD`/`DVD`/`WEB`/`TV`。
- `resolution` — `ArchiveResolution`：`uhd2160p`、`fhd1080p`、`hd720p`、`sd480p`、`other`。显示为
  `2160p`/`1080p`/`720p`/`480p`。片源与分辨率是两个独立维度，因此 `BD` `1080p` 和 `WEB` `1080p` 可以区分。
- `copies` — 保留了几份存档（正整数）。
- `location` — 自由文本的资料仓库代码或物理位置。刻意用自由文本，这样多份拷贝分散在不同地方时可以在一个字段里列出多个代码。

两个枚举都按 Dart 的 `.name` 序列化，与 `AnimeType` 和 `EpisodeStatus` 一致。枚举成员名是存储标识符而非
展示字符串——落到磁盘上的是 `fhd1080p`，用户看到的是 `1080p`。

**整个对象为空时会被省略。** `AnimeLocalArchive.hasAnyData` 为
`archived || <任一明细已设置> || extraJson.isNotEmpty`；仅当其为真时 `Anime.toJson()` 才写出
`localArchive` 键，而 `Anime.fromJson()` 会丢弃全空的解析结果。因此从未使用过该功能的动画，其序列化结果
与该功能存在之前逐字节一致——这正是新增它无需改动 WebDAV 请求金样本的原因。

**它去哪里、不去哪里。** 这是个人基础设施信息，因此：

| 界面 | 是否包含？ |
|---|---|
| 磁盘上的 `anime_data.json` | **是** |
| WebDAV 同步（用户自己的设备） | **是**——无需任何同步层改动；该字段随普通的整记录合并一起传输 |
| 备份包 | **是**——备份原样携带 `anime_data.json` |
| 本地 HTTP API（`/anime/list` 等） | **是**——绑定回环地址且受 Basic Auth 保护 |
| 分享图片卡片 | **否**——永不绘制 |
| `.myanimeitem` 分享文件 | **否**——与 `episodeStatuses`/`episodeWeekOffsets` 一起被剥离 |

该表的分享一侧见 [`features/share-and-import.md`](features/share-and-import.md)。

### `AnimeSeriesLink`

可选（1.6.0）的记录，说明用户把动画放进了哪个**系列**——见 [`features/series-linking.md`](features/series-linking.md)。存放在 `seriesLink` 键下，有两种形状：

```json
"seriesLink": {
  "seriesId": "0b5d0c1e-7f59-4f3e-9d5e-2a1c1b9e8f00",
  "order": 2
}
```

```json
"seriesLink": { "standalone": true }
```

- `seriesId` — 同一手动关联的系列所有成员共享的小写 UUID v4。
- `order` — 可选正整数：用户重排系列后该成员的位置。
- `standalone` — 仅为 `true` 时写入：用户把记录移出了所有系列。手工编辑的文件同时带 `standalone` 与 `seriesId` 时，`standalone` 胜出，`seriesId` 原样保留。

归属是共享的组 id，而不是前/后指针，因此任何记录都不会引用另一条记录的 `id`：删除、合并或导入记录不会留下悬空链接。没有该键的记录是由应用自行分组的**自动**记录；自动归入的系列不存储任何内容。

**整个对象为空时省略**（`hasAnyData`），与 `AnimeLocalArchive` 相同，因此用户从未整理过的片库序列化结果与 1.5.7 逐字节相同，无需迁移。该对象有自己的 `extraJson`，由 `withPreservedUnknownJson` 深度合并；无法解析的值——数字 `seriesId`、字符串 `order`——原样保留并视为缺失。

**它会去哪里、不会去哪里。**

| 场景 | 是否包含？ |
|---|---|
| 磁盘上的 `anime_data.json` | **是** |
| WebDAV 同步 | **是**，原样——走普通的整记录合并，无需改动同步层 |
| 备份包 | **是**，原样 |
| ZIP 导出与导入 | **是**，原样 |
| 本地 HTTP API | **否**——未改动；API 自己的记录投影不包含它 |
| 分享图片卡片 | **否** |
| `.myanimeitem` 分享文件 | **否**——导出时剥离，**导入时也丢弃**。外来的 `seriesId` 在另一个片库中毫无意义，还会把导入的记录钉在自动分组之外。这与导入会带过的 `localArchive` 有意不同。 |

### `categories`

自 1.6.0 起，用户自己的分类（见
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md)）：一个由应用分类表中的分类 id 组成的 JSON 列表。

```json
"categories": ["romance", "school"]
```

| 存储值 | 含义 |
|---|---|
| 没有该键 | 自动：分类来自类型标签映射，否则来自端侧模型 |
| 非空列表 | 用户的选择；它胜出 |
| `[]` | 用户认定没有分类；同样胜出 |

**这是「为空即省略」的唯一例外。** `[]` 会被写出、同步和备份，因为丢掉它会把「无」变回自动。只有字段不存在（Dart 中为 `null`）
时才省略该键。本构建不认识的 id 会被保留并写回，但不显示；不是字符串列表的值原样保留在 `extraJson` 中并视为不存在。该字段不是个人数据：
它经普通的整条记录合并同步，包含在备份和 ZIP 导出中，保留在 `.myanimeitem` 分享文件中，导入后仍然存在。模型产生的分类**不**存放在这里——
它们在 `ai_insights.json` 中（见下文）。

### 兼容性：未知 JSON 字段保留（`extraJson`）

`Anime`、`AnimeRating`、`AnimeLocalArchive`、`AnimeExternalMeta`、`AnimeExternalRating` 和 `AnimeData`（顶层 `{animes: [...]}` 容器）各携带一个 `extraJson` 映射，保存当前应用版本不认识的任何 JSON 键。模式：

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
| 主页日历视图格式 | `storage_config.json` | 否 | 设备特有的上次使用的日历视图（`homeCalendarFormat`：`twoWeeks` 或 `week`；缺省表示默认的整月） |
| 列表列数（分模块） | `storage_config.json` | 否 | 设备特有的首页、管理与统计列表列数偏好（`homeListColumns` / `manageListColumns` / `statsListColumns`：1–4；缺省表示自动，即填满宽度所允许的列数） |
| 存储路径覆盖 | `storage_config.json` | 否 | 设备特有路径 |
| 自动备份启用 | `storage_config.json` | 否 | 设备特有配置 |
| 备份保留天数 | `storage_config.json` | 否 | 设备特有配置 |
| 提醒启用/时间/上次提醒日期 | `storage_config.json` | 否 | 设备特有的本地时间提醒配置和内部状态 |
| API 服务器启用/监听地址/端口/凭据 | `storage_config.json` | 否 | 本地桌面配置；凭据不得被提交 |
| 托盘和开机自启偏好 | `storage_config.json` | 否 | 本地桌面配置 |
| 是否显示假名标签 | `storage_config.json` | 否 | 设备特有的 `kanaTabEnabled`；缺省表示隐藏（1.6.0） |
| 端侧 AI 开关与模型尺寸偏好 | `storage_config.json` | 否 | 设备特有的 `onDeviceAiEnabled` 与 `onDeviceAiPreferFast`（Android）；缺省表示关闭（1.6.0） |
| 自动分类 | `storage_config.json` | 否 | 设备特有的 `autoCategoriesEnabled`；缺省表示关闭（1.6.0） |
| 推荐 | `storage_config.json` | 否 | 设备特有的 `recommendationsEnabled`；缺省表示关闭（1.6.0） |
| WebDAV 配置 | `webdav_config.json` | 否 | 仅本地秘密/配置 |
| 同步基线快照 | `.sync_base/anime_data.json` | 否 | 本地合并跟踪 |
| 本地备份 | `backups/backup_*.json` | 否 | 本地恢复；v2 捆绑引用去重后的图像 blob |
| 备份图像 blob | `backups/blobs/` | 否 | 内容寻址（`sha256`）、跨备份共享、引用计数 GC |
| 后台更新队列 | `metadata_updates.json` | 否 | 设备本地的尝试/退避状态，以及已下载的更新候选；可重建的缓存 |
| 预取的候选封面 | `metadata_covers/` | 否 | 仅在启用封面预下载时存在；对应建议被处理后即清理 |
| 后台更新策略 | `storage_config.json` | 否 | 设备特有的 `metadataAutoUpdate`（`off`/`noCellular`/`always`；缺省表示移动端 `noCellular`、桌面 `always`）与 `metadataPrefetchCovers` |
| 端侧 AI 结果 | `ai_insights.json` | 否 | 本设备的 AI 分类结果缓存与推荐的*不感兴趣*列表（`hiddenRecommendations`）（1.6.0）；不备份；可重建；加载时修剪已删除记录的条目 |

`metadata_updates.json` 与 `metadata_covers/` 既不同步也不备份，而这不需要任何特殊处理：同步与备份引擎
只会碰 `ModuleRegistry` 中注册的文件名外加 `images/`，而两者都没有注册进 `lib/app/data_modules.dart`。
它们确实位于 `AnimeStorage.getAppDir()` 之下，所以更换存储路径时会跟着一起迁移。见
[`features/metadata-auto-update.md`](features/metadata-auto-update.md)。

`ai_insights.json`（1.6.0）遵循同样的机制：它也没有注册，因此既不同步也不备份，并随存储路径迁移。由于它还保存
`hiddenRecommendations`，隐藏推荐仅限本设备。其 schema 见
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md)。

### `storage_config.json`

保存上表中除 WebDAV 配置外的每个设备本地偏好：主题模式、语言区域、日历周起始/布局/时间基准/视图格式偏好、存储路径覆盖、自动备份启用 + 保留天数（`backupRetentionDays`）、提醒设置、API 服务器启用/监听地址/端口/凭据、托盘/开机自启偏好，以及后台资料更新设置（`metadataAutoUpdate`、`metadataPrefetchCovers`）、分模块的列表列数（`homeListColumns`、`manageListColumns`、`statsListColumns`），是否显示假名标签（`kanaTabEnabled`，仅在开启时写入），以及端侧 AI 开关与「使用更快的模型」偏好（`onDeviceAiEnabled`、`onDeviceAiPreferFast`，都仅在开启时写入；见 [`on-device-ai.md`](on-device-ai.md)），以及是否开启自动分类（`autoCategoriesEnabled`，仅在开启时写入），以及是否开启推荐（`recommendationsEnabled`，仅在开启时写入）。此文件的任何内容都不被同步——它刻意设备特有，而这正是网络策略应有的归宿：接有线网的桌面与走流量套餐的手机本就该不同。

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

导出在写入前从每个 `anime` 负载中剥离个人数据（`episodeStatuses`、`episodeWeekOffsets`、`localArchive`，以及自 1.6.0 起的 `seriesLink`）。导入总是分配新 UUID，绝不覆盖既有的本地记录；它会丢弃文件携带的任何 `seriesLink`，并自 1.6.0 起带过 `externalMeta`（更早的版本导入时会丢弃它，尽管导出保留了它）；`categories` 导出时不剥离、导入时也不丢弃（1.6.0）；多动画捆绑导入运行与 [`features/duplicate-detection.md`](features/duplicate-detection.md) 相同的冲突检测来判断传入记录是否与本地记录冲突，并为每个冲突提供保留本地/使用导入/合并选项。
