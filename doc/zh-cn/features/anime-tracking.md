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
