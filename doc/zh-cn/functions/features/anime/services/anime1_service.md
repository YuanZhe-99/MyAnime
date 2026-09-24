# lib/features/anime/services/anime1_service.dart

`Anime1Service` 为一条记录找到 `anime1.me` 的系列页面，并为已保存的观看链接读取站点的更新进度。它索引优先：
站点把整个片库当作 `animelist.json` 发布，因此每一行都在归一化的简体键上本地打分
（[`anime_search_service.md`](anime_search_service.md) 提供 `foldTitle`、`similarityRaw`、`orderedSimilarity`、
`bestSimilarity`、`harvestAliases`、`userAgent` 与 `decodeHtmlEntities`）；1.5.6 之前作为全部机制的 WordPress
`?s=` 搜索只保留为最后手段。持久化的结果是 [`../models/anime.md`](../models/anime.md) 中的
`AnimeWatchProgress`。仅完整版——由调用方门禁；各阶段、排序常量与后台刷新见
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md)。`rank` 与 `search` 使用的季数序数读取函数
`seasonOrdinal`（及其辅助 `_parseCjkNumber`）已于 1.6.0 原样移到共享的
[`../../../shared/utils/season_label.md`](../../../shared/utils/season_label.md)，系列索引也使用它。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `Anime1EpisodeInfo(...)` | 构造函数（`Anime1EpisodeInfo`） | B | 保存一个集数单元格的解析结果。 |
| `isOngoing` | getter（`Anime1EpisodeInfo`） | B | 站点是否标记该作品仍在更新。 |
| `Anime1IndexEntry(...)` | 构造函数（`Anime1IndexEntry`） | B | 保存 `animelist.json` 的一行。 |
| `url` | getter（`Anime1IndexEntry`） | B | `?cat=<id>` 形式的系列页面 URL。 |
| `episodes` | getter（`Anime1IndexEntry`） | B | 解析本行的集数单元格。 |
| `Anime1Match(...)` | 构造函数（`Anime1Match`） | B | 保存一条排序后的候选。 |
| `Anime1Match.fromIndex` | 工厂（`Anime1Match`） | B | 从索引行构建命中；空单元格变为 `null`。 |
| `Anime1Match.fromScrape` | 工厂（`Anime1Match`） | B | 从抓取到的链接构建命中，不带集数数据。 |
| [`toProgress`](#toprogress) | 方法（`Anime1Match`） | A | 把命中转换为持久化的观看进度记录。 |
| `markedViaAliases` | 方法（`Anime1Match`） | B | 标记为经补采别名找到的副本。 |
| `Anime1Service._()` | 构造函数（`Anime1Service`） | B | 阻止实例化。 |
| [`loadIndex`](#loadindex) | 静态方法（`Anime1Service`） | A | 返回系列索引，每个 TTL 至多拉取一次。 |
| `resetIndexCache` | 静态方法（`Anime1Service`），`@visibleForTesting` | B | 丢弃缓存的索引。 |
| [`_fetchIndex`](#_fetchindex) | 静态方法（`Anime1Service`） | A | 下载并解析 `animelist.json`。 |
| [`parseIndex`](#parseindex) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 把索引 JSON 解析为条目，跳过畸形行。 |
| [`parseEpisodes`](#parseepisodes) | 静态方法（`Anime1Service`） | A | 解析 `1-12+OVA` 或 `連載中(09)` 之类的集数单元格。 |
| [`seasonIndex`](#seasonindex) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 把行的年份/季节放到连续的季度时间轴上。 |
| [`quarterIndexFor`](#quarterindexfor) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 把首播日期放到同一时间轴上，晚首播向前贴靠。 |
| [`querySet`](#queryset) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 为一次查找构建归一化、去重的查询集合。 |
| [`rank`](#rank) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 对索引行按归一化查询打分并排序。 |
| [`search`](#search) | 静态方法（`Anime1Service`） | A | 为记录查找系列页面：索引、别名、抓取依次进行。 |
| [`_mergeMatches`](#_mergematches) | 静态方法（`Anime1Service`） | A | 把别名辅助的排序合并进基础排序。 |
| `_isLikelyChinese` | 静态方法（`Anime1Service`） | B | 字符串是否为汉字且无假名。 |
| [`isAnime1Url`](#isanime1url) | 静态方法（`Anime1Service`） | A | URL 是否指向 anime1.me。 |
| [`catIdFromUrl`](#catidfromurl) | 静态方法（`Anime1Service`） | A | 从 `?cat=` URL 中读出分类 id。 |
| [`parseCategoryPage`](#parsecategorypage) | 静态方法（`Anime1Service`），`@visibleForTesting` | A | 从页面中提取 id、标题、最新一集与分类链接。 |
| [`fetchProgress`](#fetchprogress) | 静态方法（`Anime1Service`） | A | 读取站点当前为已保存观看链接列出的内容。 |
| `_progressFromEntry` | 静态方法（`Anime1Service`） | B | 从索引行构建进度记录。 |
| `_getPage` | 静态方法（`Anime1Service`） | B | 以文本形式 GET 一个页面（15 秒超时）。 |
| [`_scrapeSearch`](#_scrapesearch) | 静态方法（`Anime1Service`） | A | 搜索站点自己的 `?s=` 端点，即 1.5.7 之前的方法。 |
| [`_scrapeOne`](#_scrapeone) | 静态方法（`Anime1Service`） | A | 运行一次 `?s=` 查询并提取系列标题/URL 对。 |

六个声明标注了 `@visibleForTesting`；它们公开是为了让 `test/anime1_service_test.dart` 用夹具行驱动解析器与排序
——HTTP 调用是静态的、不接受可注入客户端。`parseEpisodes` 与 `catIdFromUrl` 是普通公开成员，因为
`anime1_labels.dart` 与 `metadata_update_service.dart` 会调用它们。

## 文档

### `AnimeWatchProgress toProgress(DateTime now)` <a id="toprogress"></a>
- **种类：** `Anime1Match` 的方法
- **来源：** `lib/features/anime/services/anime1_service.dart`（约第 176 行）
- **用途：** 把本命中转换为以其 URL 为键的持久化观看进度记录。
- **输入：** `now`。
- **返回：** `AnimeWatchProgress`，`sourceUrl = url`，含分类 id、`latestEpisode`、原始集数文本、连载中标志与
  `checkedAt = now.toUtc()`。
- **副作用：** 无。
- **用法：**
  ```dart
  final progress = selected.toProgress(DateTime.now());
  _externalMeta = (_externalMeta ?? const AnimeExternalMeta()).mergedWith(
    AnimeExternalMeta(watchProgress: progress),
  );
  ```
  （`anime_edit_page.dart`，`_searchWatchUrl`）
- **备注：** 抓取命中产出一条没有集数数据但有 `checkedAt` 的记录，因此后台刷新器仍会正常调度它。

### `static Future<List<Anime1IndexEntry>> loadIndex({bool forceRefresh = false})` <a id="loadindex"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 258 行
- **用途：** 返回系列索引，每 30 分钟的 TTL 内至多拉取一次。
- **返回：** `Future<List<Anime1IndexEntry>>`。
- **副作用：** 至多一次 HTTP GET；更新静态缓存。
- **算法：**
  1. 缓存比 `_indexTtl` 新且未强制刷新时直接返回缓存列表。
  2. 已有拉取在进行时返回同一个 future，使并发调用共享一个请求。
  3. 否则运行 [`_fetchIndex`](#_fetchindex)；成功时替换缓存并记录时间。
  4. 失败时若有旧副本则返回旧副本；只有无可提供时才重新抛出。
- **备注：** 「出错时用旧的」是刻意的：片库在一小时内很少变化，对话框与后台循环都宁要一小时前的列表而不要错误。

### `static Future<List<Anime1IndexEntry>> _fetchIndex()` <a id="_fetchindex"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 300 行
- **用途：** 下载并解析 `animelist.json`。
- **返回：** `Future<List<Anime1IndexEntry>>`。
- **副作用：** 一次带共享 `userAgent` 的 HTTP GET（15 秒超时）。
- **备注：** 仅在本文件内部使用的辅助函数。非 200 响应或解析为空都会抛错，因此坏掉的部署永远无法替换掉好的
  缓存。

### `static List<Anime1IndexEntry> parseIndex(String jsonText)` <a id="parseindex"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 325 行
- **用途：** 把索引 JSON 按文件顺序（最近更新在前）解析为条目。
- **输入：** `jsonText`——裸的行数组，或 `data` 字段持有该数组的对象。
- **返回：** `List<Anime1IndexEntry>`。
- **副作用：** 无。
- **算法：** 对每个至少三个单元格的列表行：把单元格 0 读作 `int`（或解析）；缺失则跳过。单元格 1 经
  `decodeHtmlEntities` 读取；为空则跳过。单元格 2–5 读作修剪后的字符串，缺失读作空。用 `foldTitle` 把标题
  归一化一次，与显示标题一并存储。
- **备注：** 行的形状是 `[catId, title, episodesText, year, season, fansub]`；归一化在解析时算好，排序时不必逐对
  重复。

### `static Anime1EpisodeInfo parseEpisodes(String text)` <a id="parseepisodes"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 366 行
- **用途：** 解析 `1-12+OVA` 或 `連載中(09)` 之类的集数单元格。
- **返回：** `Anime1EpisodeInfo`；`raw` 始终保存修剪后的输入。
- **副作用：** 无。
- **算法：** 规则按优先级——`^連載中\s*\((\d+)([^)]*)\)` → ongoing，`latest` = 开头的整数，其余为 `extras`；
  `^(\d+)\s*-\s*(\d+)(?:\.\d+)?(.*)$` → range，含 `first`、`last`、`latest = last`，任何后缀为 `extras`；裸整数
  → 单集 range；含 劇場版 → movie，含 特別編 → special；其余 → other。
- **备注：** 连载中单元格只信任开头的整数（`連載中(3 EP4)` 读作 3）。1.5.7 时在线索引中观察到的每一种形状都由
  `test/anime1_service_test.dart` 钉住。

### `static int? seasonIndex(String year, String season)` <a id="seasonindex"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 410 行
- **用途：** 把行的年份/季节放到连续的季度时间轴上：`year * 4 + (冬 0, 春 1, 夏 2, 秋 3)`。
- **返回：** `int?`——年份不是整数或没有可识别的季节字时为 `null`。
- **副作用：** 无。
- **备注：** `春/秋` 这样的组合单元格取第一个季节。

### `static int? quarterIndexFor(DateTime? firstAirDate)` <a id="quarterindexfor"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 428 行
- **用途：** 把首播日期放到与 [`seasonIndex`](#seasonindex) 相同的时间轴上。
- **返回：** `int?`——日期为 null 时为 `null`。
- **副作用：** 无。
- **算法：** `year * 4 + (month - 1) ~/ 3`，日期落在季度最后一个月 21 日及之后时再加一。
- **备注：** anime1 把 9 月 29 日首播归入秋季而日历说是第三季度，因此晚首播向前贴靠；12 月 21 日及之后仅靠算术
  就落入下一年的冬季。

### `static List<String> querySet(String query, List<String> altQueries)` <a id="queryset"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 449 行
- **用途：** 为一次查找构建归一化的查询集合——归一化、去重、至多十二项。
- **返回：** `List<String>`。
- **副作用：** 无。
- **备注：** 少于两个码点的查询被丢弃；单个字能匹配半个片库。

### `static List<Anime1Match> rank(List<Anime1IndexEntry> entries, List<String> foldedQueries, {int? quarterIndex, int? ordinal, double minScore = minScore, int limit = 10})` <a id="rank"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 473 行
- **用途：** 对索引行按归一化查询打分并排序。
- **输入：** `entries`、`foldedQueries`；来自 [`quarterIndexFor`](#quarterindexfor) 的 `quarterIndex`；`ordinal`
  ——记录的季数序数；`minScore`；`limit`。
- **返回：** 最佳在前的 `List<Anime1Match>`。
- **副作用：** 无。
- **算法：**
  1. 对每一行，取其归一化标题对各查询的最佳 `similarityRaw` 与最佳 `orderedSimilarity`；任一低于其底线
     （`minScore` 0.5、`minOrderedScore` 0.4）则跳过。
  2. 行的 [`seasonIndex`](#seasonindex) 等于 `quarterIndex` 时加 `seasonBoost`（0.10），相差一季时加
     `adjacentSeasonBoost`（0.03）。
  3. 记录有序数时：行的序数相等则加 `ordinalBoost`（0.10）；行写着不同序数、或记录要找续作而行没有序数时减
     `ordinalMismatchPenalty`（0.05）。
  4. 按得分降序、再按文件顺序排序；取 `limit` 条。
- **备注：** 顺序敏感的底线之所以存在，是因为基于集合的 Dice 项把 `bocchitherock` 对 `tomjerry` 恰好打到 0.5。
  各常量的解释见
  [`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md#排序)。

### `static Future<List<Anime1Match>> search(String query, {List<String> altQueries = const [], DateTime? firstAirDate, String? seasonText, bool harvestAliases = true})` <a id="search"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 543 行
- **用途：** 索引优先地为一条记录查找 anime1.me 的系列页面。
- **输入：** `query`——显示标题；`altQueries`——日文、英文、罗马音标题与已存别名；`firstAirDate`——启用档期
  加分；`seasonText`——从中读序数；`harvestAliases`——允许一次 bangumi.tv 查询。
- **返回：** 最佳在前、至多十条的 `Future<List<Anime1Match>>`。
- **副作用：** 每 30 分钟至多一次索引 GET，至多一次 bangumi.tv POST，且只在索引不可达或一无所获时才走 `?s=`
  抓取。
- **算法：**
  1. `querySet`；为空则返回 `[]`。加载索引，容忍失败。
  2. 用首播季度与从标题或季度标签读出的序数 `rank`。
  3. 允许时、索引已加载、没有行达到 `confidentScore`（0.9）、且没有替代查询已是中文：
     `AnimeSearchService.harvestAliases(query)`，然后用并集重新排序并 [`_mergeMatches`](#_mergematches)。
  4. 有命中则返回；否则 [`_scrapeSearch`](#_scrapesearch)。
- **用法：**
  ```dart
  final results = await Anime1Service.search(
    q,
    altQueries: widget.altQueries,
    firstAirDate: widget.firstAirDate,
    seasonText: widget.seasonText,
  );
  ```
  （`anime_edit_page.dart`，观看链接对话框）
- **备注：** 在对话框里重新键入查询只花费对缓存索引的一次排序，不会再下载。

### `static List<Anime1Match> _mergeMatches(List<Anime1Match> base, List<Anime1Match> again)` <a id="_mergematches"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 599 行
- **用途：** 把别名辅助的排序合并进基础排序。
- **返回：** 最佳在前、至多十条的 `List<Anime1Match>`。
- **副作用：** 无。
- **备注：** 仅在本文件内部使用的辅助函数。行按 URL 为键；得分高者胜出，新出现或得分提高的行标记
  `viaAliases`，让对话框能说明它来自哪里。

### `static bool isAnime1Url(String? url)` <a id="isanime1url"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 635 行
- **用途：** 报告 URL 是否指向 anime1.me（裸主机或任意子域）。
- **返回：** `bool`；`null` 或空白为 `false`。
- **副作用：** 无。
- **备注：** 每个进度功能都经过的门——详情页标签、列表提示与 `MetadataUpdateService.isWatchProgressStale`。

### `static int? catIdFromUrl(String url)` <a id="catidfromurl"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 649 行
- **用途：** 从 `?cat=` URL 中读出分类 id。
- **返回：** `int?`——`/category/…` slug 与其他一切为 `null`。
- **副作用：** 无。
- **备注：** `MetadataUpdateService` 用它区分免费（索引）解析与需要一次页面请求的解析。

### `static ({int? catId, String? title, int? latestEpisode, String? categoryUrl}) parseCategoryPage(String html)` <a id="parsecategorypage"></a>
- **种类：** `Anime1Service` 的静态方法，`@visibleForTesting`
- **来源：** 约第 665 行
- **用途：** 从系列或单集页面中提取分类 id、标题、最新一集与分类链接。
- **返回：** 一条记录；各字段缺失时为 `null`。
- **副作用：** 无。
- **算法：** `catId` 来自 body 的 `category-<n>` class；`title` 来自 `<h1 class="page-title">`，去标签并解码实体；
  `latestEpisode` 为 `entry-title` 帖子中最大的整数 `[N]` 后缀（忽略 `[OVA]` 与 `[SP1]`，`[12.5]` 读作 12）；
  `categoryUrl` 为第一个 `rel="category tag"` 链接。
- **备注：** 分类链接是单集帖子指回其系列的方式，正是它让旧的单集观看链接仍能解析。

### `static Future<AnimeWatchProgress?> fetchProgress(String watchUrl, {List<Anime1IndexEntry>? index})` <a id="fetchprogress"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 711 行
- **用途：** 读取 anime1.me 当前为已保存观看链接列出的内容。
- **输入：** `watchUrl`；`index`——复用的已加载索引（后台循环会传入）。
- **返回：** `Future<AnimeWatchProgress?>`——URL 不是 anime1.me 或什么都读不到时为 `null`。
- **副作用：** 可能一次索引 GET 与至多两次页面 GET。
- **算法：**
  1. 不是 anime1.me → 不联网直接 `null`。
  2. `catIdFromUrl` → 查索引行 → `_progressFromEntry`。
  3. 否则 GET 页面并 [`parseCategoryPage`](#parsecategorypage)；若是单集帖子（无 id、无集数、有分类链接），跟进
     链接一次。
  4. 解析出的 id 优先用索引行；否则用页面的最新一集构建记录；页面既无标题也无集数时为 `null`。
- **用法：**
  ```dart
  final progress = await Anime1Service.fetchProgress(url);
  ```
  （`anime_detail_page.dart`，`_checkWatchProgress`）
- **备注：** 只要 id 可知就优先用索引行，因为只有索引才说得出作品是否仍在更新；从页面构建的记录标记为非连载中。

### `static Future<List<Anime1Match>> _scrapeSearch(String query, List<String> altQueries)` <a id="_scrapesearch"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 799 行
- **用途：** 搜索站点自己的 `?s=` 端点——1.5.7 之前的方法，保留为最后手段。
- **返回：** 按 `bestSimilarity` 排序、至多十条的 `Future<List<Anime1Match>>`。
- **副作用：** 至多六次串行 HTTP GET，一无所获时再加至多三次二字子串重试。
- **算法：** 构建变体集合（每个查询加其繁体与简体形式，上限六个）；对每个运行 [`_scrapeOne`](#_scrapeone)，按
  URL 去重；为空时用繁体查询的尾部二字子串重试；打分并排序。
- **备注：** 仅在本文件内部使用的辅助函数。站点搜索只匹配繁体精确子串，因此需要这样的扇出。

### `static Future<List<({String title, String url})>> _scrapeOne(String query)` <a id="_scrapeone"></a>
- **种类：** `Anime1Service` 的静态方法
- **来源：** 约第 858 行
- **用途：** 运行一次 `?s=` 查询，从 HTML 中提取系列（而非单集）的标题/URL 对。
- **返回：** `Future<List<({String title, String url})>>`——非 200 响应时为空。
- **副作用：** 一次 HTTP GET（10 秒超时）。
- **算法：** 三种模式按优先级——`rel="category tag"` 链接，然后 `?cat=<id>` 链接，然后去掉尾部 ` [N]` 的
  `entry-title` 帖子。后面的层级只在前面一无所获时运行；每层都按标题去重并解码实体。
- **备注：** 仅在本文件内部使用的辅助函数。这是 1.5.6 的 `_searchAnime1Single` 主体，原样迁移至此。
