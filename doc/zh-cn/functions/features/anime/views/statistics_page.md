# lib/features/anime/views/statistics_page.dart

`StatisticsPage` 是应用三个主要数据浏览标签中的第三个（主页 / 管理 / 统计——见 [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md) 和 `go_router` 外壳的 [`../../../../architecture.md`](../../../../architecture.md)）。它有两个由 `_StatsView` 选择的子视图：**摘要**视图（季度/年/全范围、摘要计数卡片、可滚动季度/年趋势条形图，以及可展开的 completed/watching/dropped/not-started 列表）和**排名**视图（基于评分的排名，带时间/类型过滤器和升序/降序排序，带封面缩略图）。两个视图都可以分享/导出为图像、`.myanimeitem` 数据文件或纯文本名称列表——实际字节生成和平台分享机制位于 `ShareService`（`shared/services/share_service.dart`，文档见 [`../../../../features/share-and-import.md`](../../../../features/share-and-import.md)）；本文件拥有供给该服务的过滤、分组、排名、趋势计算和行数限制逻辑。季度归属（`airsInQuarter`、`startQuarter`）来自 `Anime`（`lib/features/anime/models/anime.dart`，[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)）；本文件还定义了自己的紧凑 `year * 4 + quarter` 索引约定（`_quarterIndex`/`_quarterFromIndex`）用于迭代和比较季度。数据重载来自 `AnimeStorage.load()`，并经 `AutoSyncService` 的"本地数据变更"回调自动重新触发。

本文件还声明了五个无自身逻辑的私有枚举（`_StatsView`、`_TimeScope`、`_TrendGranularity`、`_RankingTimeFilter`、`_SummarySharePriority`）和一个小型私有数据类 `_TrendEntry`（一个趋势图条目的年/季度/已跟踪/已完成/弃看计数）——这里用散文而不是 `Declarations` 行描述它们，与本文档集其他地方处理普通枚举/字段声明的方式一致。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `StatisticsPage.new` | 构造函数（`StatisticsPage`） | B | 创建 `StatisticsPage` 实例。 |
| `StatisticsPage.createState` | 方法（`StatisticsPage`） | B | 为此组件创建可变状态对象。 |
| `_StatisticsPageState.initState` | 方法（`_StatisticsPageState`） | B | 把季度/年过滤器默认值设为当前日期，注册自动同步重载回调，并触发首次加载。 |
| `_StatisticsPageState.dispose` | 方法（`_StatisticsPageState`） | B | 注销自动同步重载回调并释放趋势滚动控制器。 |
| [`_StatisticsPageState._load`](#_load) | 方法（`_StatisticsPageState`） | A | 从存储加载当前动画列表并刷新趋势图的滚动位置。 |
| `_StatisticsPageState._scrollTrendToEnd` | 方法（`_StatisticsPageState`） | B | 在下一帧后把趋势图的滚动位置跳到其最后一条。 |
| [`_StatisticsPageState._scrollTrendToFocused`](#_scrolltrendtofocused) | 方法（`_StatisticsPageState`） | A | 滚动趋势图，使当前聚焦的季度/年条目居中。 |
| [`_StatisticsPageState._filteredAnime`](#_filteredanime) | getter（`_StatisticsPageState`） | A | 摘要视图当前时间范围（季度/年/全部）的动画列表。 |
| [`_StatisticsPageState._rankingAnime`](#_rankinganime) | getter（`_StatisticsPageState`） | A | 当前排名视图的过滤并排序动画列表。 |
| [`_StatisticsPageState._rankingShareEntries`](#_rankingshareentries) | 方法（`_StatisticsPageState`） | A | 把排序后的排名列表转换为带 1 基排名的分享图像条目。 |
| [`_StatisticsPageState._shareRanking`](#_shareranking) | 方法（`_StatisticsPageState`） | A | 为当前过滤器/排序/方向生成并分享排名图像，可选行数限制。 |
| `_StatisticsPageState._summaryShareSubtitle` | 方法（`_StatisticsPageState`） | B | 构建摘要分享图像副标题（范围标签 + 计数），受限时带截断说明。 |
| [`_StatisticsPageState._summaryShareEntries`](#_summaryshareentries) | 方法（`_StatisticsPageState`） | A | 把分组的 completed/watching/dropped/not-started 映射扁平化为有序分享条目。 |
| `_StatisticsPageState._shareSubtitleWithTruncation` | 方法（`_StatisticsPageState`） | B | 显示行数少于总行数时向副标题追加"显示/总数"截断说明。 |
| [`_StatisticsPageState._shareCoverCount`](#_sharecovercount) | 方法（`_StatisticsPageState`） | A | 统计不同的非空封面图像 URL，供分享进度对话框的计数器使用。 |
| [`_StatisticsPageState._renumberStatisticsEntries`](#_renumberstatisticsentries) | 方法（`_StatisticsPageState`） | A | 排序/限制摘要分享条目后重新分配连续的 1 基排名。 |
| [`_StatisticsPageState._sortSummaryShareEntries`](#_sortsummaryshareentries) | 方法（`_StatisticsPageState`） | A | 按首播日期重排摘要分享条目，使行数限制保留最近/最早的动画。 |
| [`_StatisticsPageState._summaryFromEntries`](#_summaryfromentries) | 方法（`_StatisticsPageState`） | A | 从将实际渲染的最终条目重新计算已跟踪/已完成/弃看计数。 |
| [`_StatisticsPageState._generateImageWithProgress`](#_generateimagewithprogress) | 方法（`_StatisticsPageState`） | A | 在阻塞进度对话框后运行异步图像生成回调，带失败处理。 |
| `_StatisticsPageState._showSummaryStatusSelectionDialog` | 方法（`_StatisticsPageState`） | B | 询问要在摘要分享图像中包含哪些派生观看状态。 |
| `_StatisticsPageState._showSummaryShareLimitDialog` | 方法（`_StatisticsPageState`） | B | 询问摘要分享行数限制和最近/最早首播日期优先级。 |
| `_StatisticsPageState._showRankingShareLimitDialog` | 方法（`_StatisticsPageState`） | B | 询问排名分享行数限制，保持当前排名顺序。 |
| [`_StatisticsPageState._shareStatistics`](#_sharestatistics) | 方法（`_StatisticsPageState`） | A | 顶层分享入口：询问导出格式，然后为当前视图生成它。 |
| [`_StatisticsPageState._matchesRankingTimeFilter`](#_matchesrankingtimefilter) | 方法（`_StatisticsPageState`） | A | 决定一部动画是否通过排名视图的当前时间过滤器（全部/季度/年/自定义）。 |
| [`_StatisticsPageState._groupedAnime`](#_groupedanime) | getter（`_StatisticsPageState`） | A | 把当前范围的过滤动画分入四个派生观看状态桶。 |
| [`_StatisticsPageState._prevPeriod`](#_prevperiod) | 方法（`_StatisticsPageState`） | A | 把活动周期（排名或摘要季度/年）回退一步，带回卷。 |
| [`_StatisticsPageState._nextPeriod`](#_nextperiod) | 方法（`_StatisticsPageState`） | A | 把活动周期（排名或摘要季度/年）前进一步，带回卷。 |
| [`_StatisticsPageState._availableYearRange`](#_availableyearrange) | getter（`_StatisticsPageState`） | A | 计算季度/年选择器对话框的可选年份范围。 |
| `_StatisticsPageState._pickSummaryQuarter` | 方法（`_StatisticsPageState`） | B | 打开季度选择器对话框并把所选季度应用到摘要范围。 |
| `_StatisticsPageState._pickSummaryYear` | 方法（`_StatisticsPageState`） | B | 打开年选择器对话框并把所选年份应用到摘要范围。 |
| `_StatisticsPageState._pickRankingQuarter` | 方法（`_StatisticsPageState`） | B | 打开季度选择器对话框并把所选季度应用到排名时间过滤器。 |
| `_StatisticsPageState._pickRankingYear` | 方法（`_StatisticsPageState`） | B | 打开年选择器对话框并把所选年份应用到排名时间过滤器。 |
| `_StatisticsPageState._pickRankingRangeStart` | 方法（`_StatisticsPageState`） | B | 为自定义排名范围的起始季度打开季度选择器，然后规范化范围。 |
| `_StatisticsPageState._pickRankingRangeEnd` | 方法（`_StatisticsPageState`） | B | 为自定义排名范围的结束季度打开季度选择器，然后规范化范围。 |
| `_StatisticsPageState._showYearPickerDialog` | 方法（`_StatisticsPageState`） | B | 渲染可滚动年份列表对话框，每个条目旁带逐年份动画计数。 |
| `_StatisticsPageState._countAnimeInQuarter` | 方法（`_StatisticsPageState`） | B | 统计在给定季度播出的动画，供季度选择器的逐项徽章使用。 |
| `_StatisticsPageState._countAnimeInYear` | 方法（`_StatisticsPageState`） | B | 统计在给定年份任何季度播出的动画，供年选择器的逐项徽章使用。 |
| [`_StatisticsPageState._normalizeRankingCustomRange`](#_normalizerankingcustomrange) | 方法（`_StatisticsPageState`） | A | 自定义排名范围的起始/结束季度顺序颠倒时交换它们。 |
| [`_StatisticsPageState._quarterIndex`](#_quarterindex) | 静态方法（`_StatisticsPageState`） | A | 把 (year, quarter) 对编码为单个可比较/可步进整数。 |
| [`_StatisticsPageState._quarterFromIndex`](#_quarterfromindex) | 静态方法（`_StatisticsPageState`） | A | 把紧凑季度索引解码回 (year, quarter) 对。 |
| [`_StatisticsPageState._trendData`](#_trenddata) | getter（`_StatisticsPageState`） | A | 为活动摘要范围和（"全部"时）粒度构建趋势图数据。 |
| [`_StatisticsPageState._quarterTrendData`](#_quartertrenddata) | 方法（`_StatisticsPageState`） | A | 构建覆盖完整已知动画时间线的季度级趋势条目。 |
| [`_StatisticsPageState._yearTrendData`](#_yeartrenddata) | 方法（`_StatisticsPageState`） | A | 构建覆盖完整已知动画时间线的年级趋势条目。 |
| [`_StatisticsPageState._quarterTrendEntry`](#_quartertrendentry) | 方法（`_StatisticsPageState`） | A | 构建一个季度的趋势条目（已跟踪/已完成/弃看计数）。 |
| [`_StatisticsPageState._yearTrendEntry`](#_yeartrendentry) | 方法（`_StatisticsPageState`） | A | 构建一个年份的趋势条目（已跟踪/已完成/弃看计数）。 |
| [`_StatisticsPageState._focusedTrendIndex`](#_focusedtrendindex) | 方法（`_StatisticsPageState`） | A | 定位匹配当前所选摘要周期的趋势数据索引（如有）。 |
| `_StatisticsPageState.build` | 方法（`_StatisticsPageState`，组件构建） | B | 构建页面脚手架：范围/视图切换、摘要或排名正文，以及分享操作。 |
| `_StatisticsPageState._buildSummaryCard` | 方法（组件辅助） | B | 渲染一个给定颜色的摘要计数卡片（标签 + 计数）。 |
| `_StatisticsPageState._buildRankingView` | 方法（组件辅助） | B | 渲染排名视图：过滤器控件后跟排名动画列表。 |
| `_StatisticsPageState._buildRankingFilters` | 方法（组件辅助） | B | 渲染排名视图的时间/类型/排序字段/方向过滤器控件。 |
| `_StatisticsPageState._buildRankingRangeButton` | 方法（组件辅助） | B | 为自定义排名时间过滤器渲染一个季度范围按钮（起始或结束）。 |
| `_StatisticsPageState._buildRankingTile` | 方法（组件辅助） | B | 渲染一个带排名、封面缩略图、标题和分数的排名动画行。 |
| `_StatisticsPageState._buildCoverThumbnail` | 方法（组件辅助） | B | 渲染动画的封面图像缩略图，没有则占位符。 |
| `_StatisticsPageState._coverPlaceholder` | 方法（组件辅助） | B | 渲染缺失封面缩略图时显示的占位图标。 |
| `_StatisticsPageState._buildTrendChart` | 方法（组件辅助） | B | 渲染可滚动趋势条形图，数据来自 `_trendData`。 |
| `_StatisticsPageState._buildYAxisStub` | 方法（组件辅助） | B | 渲染趋势图固定的左侧 Y 轴标签列。 |
| `_StatisticsPageState._buildBarChart` | 方法（组件辅助） | B | 渲染趋势图的可滚动 `fl_chart` 条形图主体。 |
| `_StatisticsPageState._legendDot` | 方法（组件辅助） | B | 渲染一个彩色点加标签的图例条目。 |
| `_StatisticsPageState._buildGroupedLists` | 方法（组件辅助） | B | 渲染摘要视图可展开的逐状态动画列表。 |
| `_StatisticsPageState._quarterLabel` | 方法（`_StatisticsPageState`） | B | 把 (year, quarter) 对格式化为本地化的季 + 年标签。 |
| `_StatisticsPageState._rankingTimeFilterLabel` | 方法（`_StatisticsPageState`） | B | 排名时间过滤器选项（全部/季度/年/自定义范围）的本地化标签。 |
| `_StatisticsPageState._rankingShareSubtitle` | 方法（`_StatisticsPageState`） | B | 从当前时间和类型过滤器构建排名分享图像副标题。 |
| `_StatisticsPageState._ratingFieldLabel` | 方法（`_StatisticsPageState`） | B | `AnimeRatingField`（总分或五个子分之一）的本地化标签。 |
| `_StatisticsPageState._typeLabel` | 方法（`_StatisticsPageState`） | B | `AnimeType` 的本地化标签。 |
| `_StatisticsPageState._formatScore` | 方法（`_StatisticsPageState`） | B | 把评分格式化为一位小数。 |
| `_TrendEntry.new` | 构造函数（`_TrendEntry`） | B | 创建趋势条目实例（年、季度、已跟踪/已完成/弃看计数）。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 114 行）
- **用途：** 把当前动画列表从存储加载进状态，并刷新趋势图的滚动位置。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `AnimeStorage.load()`；`setState` 替换 `_allAnime`；滚动趋势图。
- **算法：**
  1. `await AnimeStorage.load()` 取当前 `AnimeData`。
  2. 仍 `mounted` 时，`setState` 用 `data.animeList` 替换 `_allAnime`。
  3. 调用 `_scrollTrendToEnd()`，在下一帧后把趋势图跳到其最后一条。
- **用法：**
  ```dart
  AutoSyncService.instance.addOnLocalDataChanged(_load);
  _load();
  ```
  （来自 `initState`，同一文件，第 93-94 行；也在 `build` 第 1509 行直接用作页面 `RefreshIndicator` 的 `onRefresh: _load`）
- **备注：** 同时注册为初始加载器和 `AutoSyncService`"本地数据变更"回调（在 `dispose` 中再次移除），使外部同步/导入在页面 mounted 时自动刷新本页。

### `void _scrollTrendToFocused({bool fallbackToEnd = false})` <a id="_scrolltrendtofocused"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 142 行）
- **用途：** 滚动趋势图，使当前聚焦的季度/年条目在视口中居中。
- **输入：** `fallbackToEnd` — 为 true 且没有聚焦条目时，滚动到图表末尾而不是什么都不做。
- **返回：** 无。
- **副作用：** 在下一帧后移动 `_trendScrollController`，当它有客户端时。
- **算法：**
  1. 等待下一帧（`addPostFrameCallback`）；滚动控制器没有附加客户端时提前返回。
  2. 计算 `_trendData` 并经 `_focusedTrendIndex(data)` 定位聚焦索引。
  3. 没有聚焦索引时：`fallbackToEnd` 为 false 则返回，否则以最大滚动范围为目标。
  4. 否则计算把固定宽度（50px）条在视口居中的像素目标：`focusedIndex * entryWidth + entryWidth / 2 - viewportDimension / 2`。
  5. 把目标钳制在 `minScrollExtent`/`maxScrollExtent` 之间并跳到它。
- **用法：**
  ```dart
  if (shouldScrollSummaryTrend) _scrollTrendToFocused();
  ```
  （来自 `_nextPeriod`/`_prevPeriod`，同一文件；也在 `_pickSummaryQuarter`/`_pickSummaryYear` 之后调用——用默认 `fallbackToEnd: false`）
- **备注：** 50px 条目宽度是硬编码常量，必须与 `_buildBarChart`/`_buildTrendChart` 使用的条宽度匹配，居数学才能视觉对齐。

### `List<Anime> get _filteredAnime` <a id="_filteredanime"></a>
- **种类：** `_StatisticsPageState` 的 getter
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 176 行）
- **用途：** 摘要视图当前时间范围（季度/年/全部）的动画列表。
- **输入：** 无。
- **返回：** `List<Anime>`。
- **副作用：** 无。
- **算法：** 对 `_scope` 做 `switch`：
  1. `quarter` — 把 `_allAnime` 按 `anime.airsInQuarter(_selectedYear, _selectedQuarter)` 过滤。
  2. `year` — 把 `_allAnime` 按是否在 `_selectedYearOnly` 的 4 个季度中任一播出过滤（循环 `q = 1..4`，首次匹配短路）。
  3. `all` — 不过滤地返回 `_allAnime`。
- **用法：**
  ```dart
  final animes = isRanking ? _rankingAnime : _filteredAnime;
  ```
  （来自 `_shareStatistics`，同一文件，第 799 行）
- **备注：** 同时支撑摘要分组列表（`_groupedAnime`）和摘要分享/导出流程；本身不应用任何观看状态过滤器。`airsInQuarter` 考虑什么（多 cour 跨度、`manualType` 覆盖等）见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `List<Anime> get _rankingAnime` <a id="_rankinganime"></a>
- **种类：** `_StatisticsPageState` 的 getter
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 199 行）
- **用途：** 计算排名视图的当前过滤并排序动画列表。
- **输入：** 无。
- **返回：** `List<Anime>`。
- **副作用：** 无。
- **算法：**
  1. 过滤 `_allAnime`，保留通过 `_matchesRankingTimeFilter`、匹配 `_rankingTypeFilter`（设置时，经 `anime.effectiveType`）、且 `anime.rating?.scoreFor(_rankingSortField)` 非 null 的动画。
  2. 按该分数排序过滤后的列表——`_rankingDescending` 时降序，否则升序——平局按 `displayTitle` 升序打破。
- **用法：**
  ```dart
  final rankedAnime = isRanking ? _rankingAnime : const <Anime>[];
  ```
  （来自 `build`，同一文件，第 1492 行；`_shareRanking` 和 `_shareStatistics` 也使用）
- **备注：** 对所选 `AnimeRatingField` 没有分数的动画被完全排除，而不是显示空白分数。

### `List<RankingShareEntry> _rankingShareEntries(List<Anime> rankedAnime)` <a id="_rankingshareentries"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 226 行）
- **用途：** 把已排序的排名列表转换为带 1 基排名和当前排序字段分数的分享图像条目。
- **输入：** `rankedAnime` — 预期已预过滤/预排序（即 `_rankingAnime`）。
- **返回：** `List<RankingShareEntry>`。
- **副作用：** 无。
- **算法：** 对 `rankedAnime` 做 `List.generate`，每个包装为 `RankingShareEntry(anime, rank: index + 1, score: anime.rating!.scoreFor(_rankingSortField)!)`。
- **用法：**
  ```dart
  var entries = _rankingShareEntries(rankedAnime);
  ```
  （来自 `_shareRanking`，同一文件，第 249 行）
- **备注：** 假设 `rankedAnime` 中每部动画对 `_rankingSortField` 已有非 null 分数——由 `_rankingAnime` 的过滤器保证——否则会抛出。

### `Future<void> _shareRanking()` <a id="_shareranking"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 244 行）
- **用途：** 为当前过滤器/排序/方向生成并分享排名图像，可选限制为前 N 行。
- **输入：** 无（读取 `context`/状态）。
- **返回：** `Future<void>`。
- **副作用：** 显示可选限制/进度对话框，生成 PNG 图像，调用平台分享流程。
- **算法：**
  1. `_rankingAnime` 为空时提前返回。
  2. 经 `_rankingShareEntries` 构建分享条目；记住 `totalCount`。
  3. 超过 50 个条目时，询问 `_showRankingShareLimitDialog(l10n, entries.length)`；取消则返回。启用限制时，`take` 前 N 个条目（N 钳制到 `1..entries.length`），保持它们既有的排名/顺序。
  4. 经 `_rankingShareSubtitle` 加 `_shareSubtitleWithTruncation` 构建副标题。
  5. 经 `_generateImageWithProgress` 调用 `ShareService.generateRankingShareBytes`（带排序字段和方向标签）生成图像字节。
  6. 经 `ShareService.shareImageBytesMulti` 以文件基名 `myanime_ranking` 分享结果页。
- **用法：**
  ```dart
  if (isRanking) {
    await _shareRanking();
  } else {
    // summary image branch
  }
  ```
  （来自 `_shareStatistics`，同一文件，第 832 行）
- **备注：** 受限排名分享保持排名的*既有*顺序——它取已排序列表的前 N 个，与摘要分享路径（见 `_sortSummaryShareEntries`，它提供单独的最近/最早优先级）不同。50 行阈值和 `ShareService` 拥有的多页 PNG 拆分行为见 [`../../../../features/share-and-import.md`](../../../../features/share-and-import.md)。

### `List<StatisticsShareEntry> _summaryShareEntries(Map<AnimeViewingStatus, List<Anime>> grouped, AppLocalizations l10n)` <a id="_summaryshareentries"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 321 行）
- **用途：** 把 completed/watching/dropped/not-started 分组映射扁平化为按固定显示顺序排列的单个分享条目排名列表。
- **输入：** `grouped` — 状态到动画列表的映射（通常是 `_groupedAnime`，可能过滤到所选状态）；`l10n` — 用于状态标签。
- **返回：** `List<StatisticsShareEntry>`。
- **副作用：** 无。
- **算法：**
  1. 固定状态顺序：completed、watching、dropped、not-started（各配本地化标签）。
  2. 按顺序对每个状态，对 `grouped[status]` 中的每部动画：计算 `watchedCount`（`episodeStatuses` 值等于 `EpisodeStatus.watched` 的计数）和 `totalEps`（`(endEpisode ?? startEpisode) - startEpisode + 1`）；追加一个带连续 1 基 `rank`、状态标签、`"watched/total"` 进度标签和 `anime.rating?.effectiveOverall` 作为分数的 `StatisticsShareEntry`。
- **用法：**
  ```dart
  var entries = _summaryShareEntries(selectedGrouped, l10n);
  ```
  （来自 `_shareStatistics`，同一文件，第 855 行）
- **备注：** 排名编号跨全部四个组连续（不是每组重启）；顺序与 `_buildGroupedLists` 构建的屏幕分组列表匹配。

### `int _shareCoverCount(Iterable<Anime> animes)` <a id="_sharecovercount"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 374 行）
- **用途：** 统计分享图像可能加载的唯一封面图数量，供进度对话框的"N of M"计数器使用。
- **输入：** `animes` — 其封面将被渲染的动画。
- **返回：** `int` — 不同非空 `coverImage` 值的计数。
- **副作用：** 无。
- **算法：** 构建 `coverImage` 值的 `Set<String>`，跳过 `null`/空；返回其长度。
- **用法：**
  ```dart
  coverCount: _shareCoverCount(entries.map((e) => e.anime)),
  ```
  （来自 `_shareRanking` 和 `_shareStatistics` 的图像分支）
- **备注：** 统计唯一 URL，不是条目——共享同一封面 URL 的动画计一次，因为底层加载器只会取一次那个 URL。

### `List<StatisticsShareEntry> _renumberStatisticsEntries(List<StatisticsShareEntry> entries)` <a id="_renumberstatisticsentries"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 388 行）
- **用途：** 排序或限制分享条目后重新分配连续的 1 基排名。
- **输入：** `entries` — 要重新编号的条目，按最终顺序。
- **返回：** 带连续排名的新 `List<StatisticsShareEntry>`；其他所有字段保留。
- **副作用：** 无。
- **算法：** `List.generate` 复制每个条目，`rank: index + 1`，保持其他每个字段不变。
- **用法：**
  ```dart
  entries = _renumberStatisticsEntries(entries);
  ```
  （来自 `_shareStatistics`，同一文件，第 866 行，排序和限制后立即）
- **备注：** 必须在 `_sortSummaryShareEntries` + `take(limitCount)` 之后运行，使显示排名从 1 连续，而不是原始分组列表的排名。

### `List<StatisticsShareEntry> _sortSummaryShareEntries(List<StatisticsShareEntry> entries, _SummarySharePriority priority)` <a id="_sortsummaryshareentries"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 409 行）
- **用途：** 按首播日期排序摘要分享条目，使行数限制保留最近（或最早）的动画。
- **输入：** `entries`；`priority` — `recent` 或 `oldest`。
- **返回：** 新的排序 `List<StatisticsShareEntry>`。
- **副作用：** 无。
- **算法：**
  1. 复制 `entries`，然后用 `anime.firstAirDate` 上的比较器排序。
  2. 两个日期都 `null` → 按 `displayTitle` 比较。恰好一个 `null` → 无日期条目总是排最后，无论 `priority`。
  3. 两个日期都在 → 比较它们；`recent` 优先级取反自然（升序）比较，使更新的日期先排，`oldest` 保持升序。
  4. 日期相等 → 按 `displayTitle` 打破平局。
- **用法：**
  ```dart
  entries = _sortSummaryShareEntries(entries, limit.priority);
  ```
  （来自 `_shareStatistics`，同一文件，第 861 行；只在 `entries.length > 50` 时到达）
- **备注：** 没有 `firstAirDate` 的条目无论优先级总是排到底部，因此"最近"限制仍然先丢弃无日期动画。

### `StatisticsShareSummary _summaryFromEntries(List<StatisticsShareEntry> entries)` <a id="_summaryfromentries"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 436 行）
- **用途：** 从分享图像中实际渲染的条目构建已跟踪/已完成/弃看摘要计数。
- **输入：** `entries` — 最终（可能受限/重新编号）条目列表。
- **返回：** 恰好反映这些条目的 `StatisticsShareSummary`。
- **副作用：** 无。
- **算法：** 循环 `entries`，对 `entry.anime.viewingStatus` 做 `switch`，递增 `completed` 或 `dropped` 计数器（`watching`/`notStarted` 是空操作）；返回 `StatisticsShareSummary(tracked: entries.length, completed, dropped)`。
- **用法：**
  ```dart
  final summary = _summaryFromEntries(entries);
  ```
  （来自 `_shareStatistics`，同一文件，第 868 行，任何限制/重新编号之后）
- **备注：** 限制后重新计算，使分享图像的页头条形图反映可能受限的行集，而不是来自 `_groupedAnime` 的完整未过滤摘要。

### `Future<List<Uint8List>?> _generateImageWithProgress({required AppLocalizations l10n, required int coverCount, required Future<List<Uint8List>> Function(ValueNotifier<double> progress) generate})` <a id="_generateimagewithprogress"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 465 行）
- **用途：** 显示阻塞进度对话框的同时生成图像页，生成抛出时浮出失败 snackbar。
- **输入：** `l10n`；`coverCount` — 用于"完成/总数"进度文本；`generate` — 实际字节生成回调，给定一个 `ValueNotifier<double>` 向其报告进度。
- **返回：** PNG 页字节列表，生成失败时为 `null`。
- **副作用：** 显示/关闭不可关闭的 `AlertDialog`；可能显示失败 `SnackBar`。
- **算法：**
  1. 创建 `ValueNotifier<double> progress`，显示带绑定它的 `LinearProgressIndicator`（`coverCount > 0` 时加"完成/coverCount"计数器）的 `PopScope(canPop: false)` `AlertDialog`。
  2. `await Future.delayed(Duration.zero)`，使对话框在工作开始前实际绘制。
  3. `try`/`catch`/`finally`：`await generate(progress)`；出错时捕获它；`finally` 中仍 `mounted` 时弹出对话框的导航器并 await 对话框的 future，然后释放 `progress`。
  4. 发生错误且仍 `mounted` 时，显示带 `l10n.shareFailed` 的 `SnackBar`。
  5. 返回生成的页，生成失败时返回 `null`。
- **用法：**
  ```dart
  final pages = await _generateImageWithProgress(
    l10n: l10n,
    coverCount: _shareCoverCount(entries.map((e) => e.anime)),
    generate: (progress) => ShareService.generateRankingShareBytes(
      entries: entries,
      title: l10n.statsRanking,
      subtitle: subtitle,
      sortLabel: _ratingFieldLabel(_rankingSortField, l10n),
      orderLabel: _rankingDescending ? l10n.statsRankingDescending : l10n.statsRankingAscending,
      l10n: l10n,
      progress: progress,
    ),
  );
  ```
  （来自 `_shareRanking`，同一文件；`_shareStatistics` 的摘要图像分支用 `ShareService.generateStatisticsShareBytes` 类似调用）
- **备注：** 平台分享面板只在对话框关闭后显示，因此——按它自己的源码注释——此方法运行期间不触发桌面预览行为。

### `Future<void> _shareStatistics()` <a id="_sharestatistics"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 764 行）
- **用途：** AppBar 分享操作的顶层入口：询问用户分享为图像、数据文件还是 TXT 名称列表，然后为当前统计视图（摘要或排名）生成适当输出。
- **输入：** 无（读取 `context`/状态）。
- **返回：** `Future<void>`。
- **副作用：** 显示对话框、生成图像、分享文件。
- **算法：**
  1. 经 `SimpleDialog` 询问 `shareType`：`'image'`、`'data'` 或 `'txt'`；取消返回。
  2. 计算 `animes`（`_rankingAnime` 或 `_filteredAnime`）和 `displayName`（`myanime_ranking`，或按 `_scope` 的 `myanime_<year>_Q<quarter>` / `myanime_<year>` / `myanime_all`），供 `txt`/`data` 分支使用。
  3. `'txt'` → `ShareService.shareStatisticsTxt` 并返回。
  4. `'data'` → `animes` 为空则提前返回，否则 `ShareService.shareStatisticsData` 并返回。
  5. 图像分享、排名视图 → 完全委托给 `_shareRanking()`。
  6. 图像分享、摘要视图 → 询问 `_showSummaryStatusSelectionDialog`，把 `_groupedAnime` 过滤到所选状态（未选状态变空列表），经 `_summaryShareEntries` 构建条目。超过 50 个条目时：询问 `_showSummaryShareLimitDialog`，经 `_sortSummaryShareEntries(priority)` 排序，可选 `take(limitCount)`，然后 `_renumberStatisticsEntries`。经 `_summaryFromEntries` 计算 `summary`，经 `_summaryShareSubtitle` 计算副标题。经 `_generateImageWithProgress` 调用 `ShareService.generateStatisticsShareBytes` 生成页，然后经 `ShareService.shareImageBytesMulti` 以文件基名 `myanime_stats` 分享。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.ios_share),
    tooltip: l10n.statsShare,
    onPressed: (isRanking ? rankedAnime.isNotEmpty : _filteredAnime.isNotEmpty)
        ? _shareStatistics
        : null,
  ),
  ```
  （来自 `build`，同一文件，第 1498-1505 行）
- **备注：** 这是唯一会调用 `_showSummaryStatusSelectionDialog`、`_sortSummaryShareEntries`、`_renumberStatisticsEntries` 或 `_summaryFromEntries` 的方法——那些辅助纯粹为支持此方法的摘要图像分支而存在。

### `bool _matchesRankingTimeFilter(Anime anime)` <a id="_matchesrankingtimefilter"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 901 行）
- **用途：** 决定一部动画是否被纳入排名视图的当前时间过滤器。
- **输入：** `anime`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 对 `_rankingTimeFilter` 做 `switch`：
  1. `all` → 总是 `true`。
  2. `quarter` → `anime.airsInQuarter(_rankingSelectedYear, _rankingSelectedQuarter)`。
  3. `year` → 若 `anime.airsInQuarter(_rankingSelectedYearOnly, q)` 对 `1..4` 中任一 `q` 成立则为 `true`。
  4. `custom` → 经 `_quarterIndex` 把起始/结束 `(year, quarter)` 对转换为紧凑索引，`end < start` 时局部交换它们，然后循环 `[start, end]` 中的每个索引，经 `_quarterFromIndex` 转回，在动画播出的第一个季度返回 `true`。
- **用法：**
  ```dart
  final filtered = _allAnime.where((anime) {
    if (!_matchesRankingTimeFilter(anime)) return false;
    ...
  }).toList();
  ```
  （来自 `_rankingAnime`，同一文件，第 200-201 行）
- **备注：** `custom` 分支在每次调用时局部重新派生规范化的 `[start, end]`，而不是依赖 `_normalizeRankingCustomRange` 已运行，因此即使存储的起始/结束被留下为交换状态，结果也保持正确。

### `Map<AnimeViewingStatus, List<Anime>> get _groupedAnime` <a id="_groupedanime"></a>
- **种类：** `_StatisticsPageState` 的 getter
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 936 行）
- **用途：** 把当前范围的过滤动画分入摘要视图可展开列表显示的四个派生观看状态桶。
- **输入：** 无。
- **返回：** `Map<AnimeViewingStatus, List<Anime>>`。
- **副作用：** 无。
- **算法：** 用 `watching`/`completed`/`dropped`/`notStarted` 的空列表预播种映射（按该插入顺序）；遍历 `_filteredAnime`，把每部动画追加到 `map[anime.viewingStatus]`。
- **用法：**
  ```dart
  final grouped = _groupedAnime;
  ```
  （来自 `build`，同一文件，第 1490 行；`_shareStatistics` 在过滤到用户所选状态前也使用，第 836 行）
- **备注：** 完全依赖 `Anime.viewingStatus` 做 completed/watching/dropped/notStarted 分类——本 getter 不做任何自己的状态推断。见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) / [`../../../../data-formats.md`](../../../../data-formats.md)。

### `void _prevPeriod()` <a id="_prevperiod"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 956 行）
- **用途：** 把活动周期（排名季度/年过滤器，或摘要季度/年范围）回退一步，带季度/年回卷。
- **输入：** 无。
- **返回：** 无。
- **副作用：** `setState` 修改相关所选年/季字段；可能重新滚动趋势图。
- **算法（在一个 `setState` 内）：**
  1. 排名视图 + `quarter` 时间过滤器 → 递减 `_rankingSelectedQuarter`；降到 1 以下时回卷到 4 并递减 `_rankingSelectedYear`。
  2. 否则排名视图 + `year` 时间过滤器 → 递减 `_rankingSelectedYearOnly`。
  3. 否则摘要范围 `quarter` → 以同样的回卷到 `_selectedYear` 上递减 `_selectedQuarter`；标记 `shouldScrollSummaryTrend`。
  4. 否则摘要范围 `year` → 递减 `_selectedYearOnly`；标记 `shouldScrollSummaryTrend`。
  5. `setState` 之后，`shouldScrollSummaryTrend` 时调用 `_scrollTrendToFocused()`。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevPeriod),
  ```
  （来自 `build`，同一文件，第 1581 行，以及 `_buildRankingFilters`，第 1782 行）
- **备注：** 排名的 `all`/`custom` 时间过滤器没有可步进的单一周期，因此那些情况下（以及 `_view`/`_scope` 不匹配上面四个分支之一时）此方法除空的 `setState` 调用外是空操作。

### `void _nextPeriod()` <a id="_nextperiod"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 989 行）
- **用途：** 把活动周期（排名季度/年过滤器，或摘要季度/年范围）前进一步，带季度/年回卷。
- **输入：** 无。
- **返回：** 无。
- **副作用：** `setState` 修改相关所选年/季字段；可能重新滚动趋势图。
- **算法：** 镜像 `_prevPeriod`，用递增替代递减：季度计数器从 4 回卷到 1 同时递增配对的年；仅年计数器直接递增。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextPeriod),
  ```
  （来自 `build`，同一文件，第 1600 行，以及 `_buildRankingFilters`，第 1804 行）
- **备注：** 与 `_prevPeriod` 相同的范围/视图适用性注意事项。

### `(int, int) get _availableYearRange` <a id="_availableyearrange"></a>
- **种类：** `_StatisticsPageState` 的 getter
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1022 行）
- **用途：** 构建摘要和排名的年/季选择器对话框的可选年份范围。
- **输入：** 无。
- **返回：** `(int, int)` — `(minYear, maxYear)`。
- **副作用：** 无。
- **算法：**
  1. 把 `_allAnime` 中每个不同的 `startQuarter.$1`（起始年）收集进 `Set<int>`。
  2. 添加 `now.year`、`now.year + 1` 和每个当前所选年份字段（`_selectedYear`、`_selectedYearOnly`、`_rankingSelectedYear`、`_rankingSelectedYearOnly`、`_rankingStartYear`、`_rankingEndYear`），使选择器总是包含当前选中的任何项。
  3. 经 `reduce` 返回结果集的 `(min, max)`。
- **用法：**
  ```dart
  final range = _availableYearRange;
  ```
  （来自 `_pickSummaryQuarter`、`_pickSummaryYear`、`_pickRankingQuarter`、`_pickRankingYear`、`_pickRankingRangeStart` 和 `_pickRankingRangeEnd`，同一文件）
- **备注：** 包含动画数据年份、"当前上下文"（今年和明年）和每个当前选择，因此范围绝不会意外排除 UI 中某处已选择的年份。

### `void _normalizeRankingCustomRange()` <a id="_normalizerankingcustomrange"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1296 行）
- **用途：** 自定义排名范围的起始/结束季度被留下为逆序时交换它们。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 顺序颠倒时原地修改 `_rankingStartYear`/`_rankingStartQuarter`/`_rankingEndYear`/`_rankingEndQuarter`。
- **算法：**
  1. 对当前起始/结束经 `_quarterIndex` 计算 `startIdx`/`endIdx`。
  2. `endIdx >= startIdx` 时返回（已在顺序中）。
  3. 否则交换年/季对，使起始总是先于结束。
- **用法：**
  ```dart
  setState(() {
    _rankingStartYear = selected.year;
    _rankingStartQuarter = selected.quarter;
    _normalizeRankingCustomRange();
  });
  ```
  （来自 `_pickRankingRangeStart`，同一文件，第 1143-1147 行；`_pickRankingRangeEnd` 类似调用）
- **备注：** 与选择器赋值在同一个 `setState` 内运行，因此 UI 绝不会短暂显示颠倒的范围。`_matchesRankingTimeFilter` 的 `custom` 分支还会额外局部重新规范化，因此此方法是 UX/状态一致性便利，而不是过滤本身正确性的要求。

### `static int _quarterIndex(int year, int quarter)` <a id="_quarterindex"></a>
- **种类：** `_StatisticsPageState` 的静态方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1314 行）
- **用途：** 把 `(year, quarter)` 对编码为单个可比较/可步进整数。
- **输入：** `year`；`quarter`（1-4）。
- **返回：** `int` — `year * 4 + quarter`。
- **副作用：** 无。
- **算法：** `year * 4 + quarter`。
- **用法：**
  ```dart
  var startIdx = _quarterIndex(_rankingStartYear, _rankingStartQuarter);
  ```
  （来自 `_matchesRankingTimeFilter` 的 `custom` 分支、`_normalizeRankingCustomRange` 和 `_quarterTrendData`）
- **备注：** 整个文件把它用作季度的紧凑"时间线位置"——比较、min/max 和迭代季度范围都归结为这个索引上的整数运算。

### `static (int, int) _quarterFromIndex(int index)` <a id="_quarterfromindex"></a>
- **种类：** `_StatisticsPageState` 的静态方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1321 行）
- **用途：** 把紧凑季度索引解码回 `(year, quarter)` 对。
- **输入：** `index` — 由 `_quarterIndex` 产生。
- **返回：** `(int, int)` — `(year, quarter)`。
- **副作用：** 无。
- **算法：** `year = (index - 1) ~/ 4`；`quarter = ((index - 1) % 4) + 1`。
- **用法：**
  ```dart
  final (year, quarter) = _quarterFromIndex(idx);
  ```
  （来自 `_matchesRankingTimeFilter` 的 `custom` 分支，同一文件，第 924 行；`_quarterTrendData` 也用它把索引范围展开回条目）
- **备注：** 必须保持为 `_quarterIndex` 的 `year * 4 + quarter` 约定的精确逆——两者只在一起使用。

### `List<_TrendEntry> get _trendData` <a id="_trenddata"></a>
- **种类：** `_StatisticsPageState` 的 getter
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1334 行）
- **用途：** 为活动摘要范围构建趋势图数据，并为"全部"范围按当前所选趋势粒度。
- **输入：** 无。
- **返回：** `List<_TrendEntry>`。
- **副作用：** 无。
- **算法：** 对 `_scope` 做 `switch`：
  1. `quarter` → `_quarterTrendData(includeFocused: true)`。
  2. `year` → `_yearTrendData(includeFocused: true)`。
  3. `all` → 对 `_allTrendGranularity` 做 `switch`：`quarter` → `_quarterTrendData(includeFocused: false)`；`year` → `_yearTrendData(includeFocused: false)`。
- **用法：**
  ```dart
  final data = _trendData;
  if (data.isEmpty) return const SizedBox.shrink();
  ```
  （来自 `_buildTrendChart`，同一文件，第 2090-2091 行；`_scrollTrendToFocused` 也使用）
- **备注：** 季度/年范围总是包含聚焦（当前所选）周期，即使它没有动画；"全部"范围只显示实际有数据的周期。

### `List<_TrendEntry> _quarterTrendData({required bool includeFocused})` <a id="_quartertrenddata"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1353 行）
- **用途：** 构建覆盖完整已知动画时间线的季度级趋势条目。
- **输入：** `includeFocused` — 是否也扩宽范围以包含当前所选季度。
- **返回：** `List<_TrendEntry>`。
- **副作用：** 无。
- **算法：**
  1. 以 `startIndex = endIndex = _quarterIndex(currentYear, currentQuarter)`（今天的季度）开始；`hasData = false`。
  2. 对每部有非 null `startQuarter` 的动画，把 `[startIndex, endIndex]` 扩宽以包含其季度索引并设 `hasData = true`。
  3. `includeFocused` 时，进一步扩宽范围以包含 `_quarterIndex(_selectedYear, _selectedQuarter)`。否则，没有任何动画有数据时返回 `[]`。
  4. 对从 `startIndex` 到 `endIndex`（闭区间）的每个索引（经 `_quarterFromIndex`）构建一个 `_quarterTrendEntry`。
- **用法：**
  ```dart
  List<_TrendEntry> get _trendData {
    switch (_scope) {
      case _TimeScope.quarter:
        return _quarterTrendData(includeFocused: true);
      ...
  ```
  （来自 `_trendData`，同一文件，第 1336-1337 行）
- **备注：** 完整时间线总是至少跨越"今天的季度"，即使没有数据，因此全新资料库仍显示一个条。

### `List<_TrendEntry> _yearTrendData({required bool includeFocused})` <a id="_yeartrenddata"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1388 行）
- **用途：** 构建覆盖完整已知动画时间线的年级趋势条目。
- **输入：** `includeFocused` — 是否也扩宽范围以包含当前所选年份。
- **返回：** `List<_TrendEntry>`。
- **副作用：** 无。
- **算法：** 与 `_quarterTrendData` 形态相同但在年级粒度：从 `[now.year, now.year]` 开始，对每部动画的 `startQuarter.$1` 扩宽，可选进一步扩宽以包含 `_selectedYearOnly`，然后对范围内的每年构建一个 `_yearTrendEntry`（`!includeFocused && !hasData` 时为 `[]`）。
- **用法：**
  ```dart
  case _TimeScope.year:
    return _yearTrendData(includeFocused: true);
  ```
  （来自 `_trendData`，同一文件，第 1338-1339 行）
- **备注：** 见 `_quarterTrendData` 的备注——同样"至少总是当前周期"和"未聚焦且无数据时为空"的行为适用。

### `_TrendEntry _quarterTrendEntry((int, int) yearQuarter)` <a id="_quartertrendentry"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1419 行）
- **用途：** 构建一个季度级趋势条目（已跟踪/已完成/弃看计数）。
- **输入：** `yearQuarter` — 一个 `(year, quarter)` 对。
- **返回：** `_TrendEntry`。
- **副作用：** 无。
- **算法：**
  1. 把 `_allAnime` 过滤为 `airsInQuarter(yearQuarter.$1, yearQuarter.$2)` 为 true 的那些。
  2. `tracked` = 该列表长度；`completed`/`dropped` = 其中匹配对应 `AnimeViewingStatus` 的计数。
- **用法：**
  ```dart
  return [
    for (var index = startIndex; index <= endIndex; index++)
      _quarterTrendEntry(_quarterFromIndex(index)),
  ];
  ```
  （来自 `_quarterTrendData`，同一文件，第 1377-1380 行）
- **备注：** 经 `airsInQuarter` 统计动画，它考虑多 cour 跨度——跨多季度的动画在其播出的每个季度都被计数，不只起始季度。见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `_TrendEntry _yearTrendEntry(int year)` <a id="_yeartrendentry"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1441 行）
- **用途：** 构建一个年级趋势条目（已跟踪/已完成/弃看计数）。
- **输入：** `year`。
- **返回：** `_TrendEntry`（`quarter: 0`，用作年范围哨兵）。
- **副作用：** 无。
- **算法：**
  1. 把 `_allAnime` 过滤为在当年四个季度中任一播出的（循环 `q = 1..4`，首次匹配短路）——因此跨季度动画每年计一次，不是每季度一次。
  2. `tracked` = 该列表长度；`completed`/`dropped` = 其中匹配对应 `AnimeViewingStatus` 的计数。
- **用法：**
  ```dart
  return [
    for (var year = startYear; year <= endYear; year++) _yearTrendEntry(year),
  ];
  ```
  （来自 `_yearTrendData`，同一文件，第 1410 行）
- **备注：** `quarter: 0` 字段正是 `_focusedTrendIndex` 和 `_TrendEntry` 区分年级条目与共享同一 `year` 的季度级条目的方式。

### `int? _focusedTrendIndex(List<_TrendEntry> data)` <a id="_focusedtrendindex"></a>
- **种类：** `_StatisticsPageState` 的方法
- **来源：** `lib/features/anime/views/statistics_page.dart`（第 1466 行）
- **用途：** 定位匹配当前所选摘要周期的趋势条目（如有）。
- **输入：** `data` — 要搜索的趋势条目（通常是 `_trendData` 的结果）。
- **返回：** `int?` — 匹配索引，无（或在 `all` 范围）时为 `null`。
- **副作用：** 无。
- **算法：** 对 `_scope` 做 `switch`：`quarter` → `data.indexWhere` 同时匹配 `_selectedYear` 和 `_selectedQuarter`；`year` → `data.indexWhere` 匹配 `_selectedYearOnly` 且 `quarter == 0`；`all` → `-1`（无聚焦）。任何 `-1` 结果转为 `null`。
- **用法：**
  ```dart
  final focusedIndex = _focusedTrendIndex(data);
  ```
  （来自 `_scrollTrendToFocused` 和 `_buildTrendChart`，同一文件）
- **备注：** `all` 范围按设计没有单一聚焦周期（它以用户选择的粒度显示完整时间线），因此无论 `data` 内容如何总是返回 `null`。
