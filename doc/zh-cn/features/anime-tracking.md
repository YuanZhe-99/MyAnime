# 动画模型与跟踪

核心数据模型是 `lib/features/anime/models/anime.dart` 中的 `Anime`。逐字段细节（身份、URL、日程、剧集、`AnimeType`、`AnimeRating`、`extraJson`）在 [`../data-formats.md`](../data-formats.md)——本页聚焦构建在这些字段之上的跟踪/季度归属逻辑。

## 季度归属

季度归属使用日式动画 **cour** 惯例（一 cour 大约是一个 3 个月的播出季/季度）。

- `startQuarter` 从 `firstAirDate` 的月份派生 `(year, quarter)`：1–3 月 -> Q1，4–6 月 -> Q2，7–9 月 -> Q3，10–12 月 -> Q4。
- `airsInQuarter(year, quarter)` 决定一部动画是否应出现在给定季度的列表中：
  - **设置了 `manualType` 时**（且不是 `longRunning`），归属使用从 `startQuarter` 起的固定 cour 风格跨度：`allAtOnce`/`singleCour` 跨 1 个季度，`halfYear` 跨 2 个，`fullYear` 跨 4 个。**`manualType` 总是优先**于任何按集数的估计。
  - **没有 `manualType`**，且 `endEpisode` 已知时，归属从集数和 `episodeWeekOffsets` 估计*实际*播出周数（`actualWeeks = (episodeCount - 1) + weekOffsetFor(lastEpisode)`），然后把周数映射为季度跨度，每个 cour 边界约有 2 周容差：≤15 周 -> 1 个季度，≤28 -> 2 个，≤41 -> 3 个，≤54 -> 4 个，否则 `ceil(weeks / 13)` 个季度。
  - **长期连载**（无 `endEpisode`、无 `manualType`）回退为与从 `firstAirDate` 起估计的 51 周运行做简单的日期重叠检查。

## 剧集播出日期与深夜回卷

`getEpisodeAirDate(episodeNumber)` 和 `getEpisodeCalendarDate(episodeNumber)` 都从 `firstAirDate` 加上 `(episodeOffset + weekOffsetFor(episodeNumber))` 周计算目标日期，然后在计算出的星期几不匹配时向前吸附到 `airDayOfWeek` 的下一次出现——因此第 1 集（以及之后每一集）绝不会早于 `firstAirDate`，即使 `airDayOfWeek` 与 `firstAirDate` 的实际星期几不一致。

两个 getter 在广播时间的处理上不同：

- `getEpisodeAirDate()` 应用 `airTime`，包括超过午夜的深夜值，如 `"25:00"`（解析为下一个日历日的 01:00）——这个惯例为什么存在见 [`../data-formats.md`](../data-formats.md)。如果 `airTime` 为 null，它把播出时间当作 23:59。
- `getEpisodeCalendarDate()` 刻意跳过那个日内回卷，即使对 `24:00`/`25:00` 值也留在计划播出*日期*上——适用于应用想要"这一集是哪个日历日的播出日"而不是"它在哪个 UTC/JST 时刻播出"的任何地方。

## 类型检测 vs 手动覆盖

- `autoType` 纯粹从 `totalEpisodes` 推断 `AnimeType`（阈值见 [`../data-formats.md`](../data-formats.md)）。
- `effectiveType` 在 `manualType` 已设置时返回它，否则回退到 `autoType`。这个优先级在读取 `effectiveType` 的每个地方都一致，包括上面的季度归属。

## 状态

观看状态（completed / watching / dropped / not-started）从 `episodeStatuses` 计算，不存储——派生规则见 [`../data-formats.md`](../data-formats.md)，在哪里显示见 [`../features/home-management-statistics.md`](home-management-statistics.md)。

## 评分：你的与资料库的

有两个评分概念并存，切不可混为一谈：

- **`AnimeRating`** 是*用户自己*的评分——一个手动总分加五个分项分，在编辑页编辑，在详情页的评分卡片中
  展示。它是唯一参与统计与本地 API 排行端点的评分。
- **`externalMeta.ratings`** 保存各外部资料库的说法，每个来源一条，统一归一化到 10 分制，且每条都记住
  自己的来源页面 URL。它展示在个人评分卡片*上方*的独立「资料库信息」卡片中，绝不参与统计。这种区分由
  版面本身承担 —— 独立的卡片、独立的分区标题，以及每个 chip 前缀的来源名。1.5.0 删除了一句用文字重述
  这一点的说明：它没有告诉读者任何卡片本身没有展示的信息。

没有任何路径会把外部评分写进 `AnimeRating`。应用搜索结果、刷新某部番剧的资料库信息，以及后台资料刷新，
都只改动 `externalMeta` —— 用户自己的评分、观看进度与手动编辑保持原样。存储形态见
[`../data-formats.md`](../data-formats.md#animeexternalmeta-与-animeexternalrating)，刷新流程见
[`multi-source-search.md`](multi-source-search.md)，后台更新器见
[`metadata-auto-update.md`](metadata-auto-update.md)。

## 更新建议

属于*用户*的字段绝不会在后台被写入。当更新器发现某条记录缺少首播日期、封面或集数，或者其集数与来源
不一致时，它会下载候选数据并归档成一条**建议**，而不是直接应用。建议从管理页的角标进入审阅，可以逐字段
处理，并按设备存储在同步数据文件之外。见 [`metadata-auto-update.md`](metadata-auto-update.md)。

## 本地存档

与观看进度无关，每部动画可以携带一条可选的**本地下载存档**记录：是否保留了本地资源、其片源与分辨率、
存了几份，以及由哪个资料仓库或物理位置保管。字段形状是 `localArchive` 键下的 `AnimeLocalArchive`——见
[`../data-formats.md`](../data-formats.md#animelocalarchive)。

它回答了模型其余部分无法回答的一个问题：*我是不是已经有了，放在哪儿？* 其中没有任何内容参与季度归属、
播出日期、状态推导或统计——它是关于用户自己存储的描述性元数据，而不是关于这部作品的。

- 在编辑页可折叠的"本地存档"小节中**编辑**，结构与评分小节相同：`archived` 的开关、两个下拉框
  （片源 × 分辨率），以及份数和位置字段。
- 在动画详情页作为只读卡片**展示**，紧邻评分卡片，显示合并后的画质标签（`BD · 1080p`）、份数和位置。
- 在管理页通过 AppBar 筛选器**筛选**，三种状态——全部、已存档、未存档——同样作用于季度页、"其他"页和
  搜索结果。"未存档"把没有记录的动画和明确标记为未保留的动画合为一类，因为要问的问题是"还有什么需要
  下载"。该筛选仅是视图状态；页面重建时会重置为"全部"。

因为这些值指明的是用户自己的存储基础设施，该字段**同步但从不分享**：它通过 WebDAV 在用户的设备之间传输，
但会从 `.myanimeitem` 分享文件中剥离，也从不绘制进分享图片卡片。见
[`share-and-import.md`](share-and-import.md)。
