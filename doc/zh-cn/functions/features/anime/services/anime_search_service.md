# lib/features/anime/services/anime_search_service.dart

`AnimeSearchService` 并行查询或抓取六个外部动画数据库（`bangumi.tv`、经 Jikan v4 的 MyAnimeList、AniList、`acgsecrets.hk`、`filmarks.com` 和 `anime1.me`），返回规范化的 `AnimeSearchResult`。它是**仅在 full 构建**中可用的普通共享工具——它本身不强制执行该限制；调用方门控它（风味门控规则和各来源说明见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)）。它依赖 [`../../../shared/utils/chinese_convert.md`](../../../shared/utils/chinese_convert.md) 生成对中文来源使用的简体/繁体查询变体，其结果供给 `anime_edit_page.dart` 的"在线搜索"流程和桌面本地 API 服务器。`AnimeSearchResult` 字段映射到 [`../../../../data-formats.md`](../../../../data-formats.md) 中记录的 `Anime` 字段（如 `sourceUrl` 变成 `infoUrl`）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AnimeSearchResult(...)`](#animesearchresult-new) | 构造函数（`AnimeSearchResult`） | A | 保存来自任何来源的一条规范化搜索命中。 |
| [`searchAll`](#searchall) | 静态方法（`AnimeSearchService`） | A | 并行查询所有元数据来源、去重、返回合并结果。 |
| [`_searchBangumi`](#searchbangumi) | 静态方法（`AnimeSearchService`） | A | 查询 bangumi.tv 的旧搜索 API。 |
| [`_searchMAL`](#searchmal) | 静态方法（`AnimeSearchService`） | A | 经 Jikan v4 API 查询 MyAnimeList。 |
| [`_searchAcgsecrets`](#searchacgsecrets) | 静态方法（`AnimeSearchService`） | A | 抓取 acgsecrets.hk 季页面 JSON-LD 数据并对照查询模糊匹配。 |
| [`_recentSeasons`](#recentseasons) | 静态方法（`AnimeSearchService`） | A | 计算当前和上一季代码（`YYYYMM`），供 `acgsecrets.hk` 抓取使用。 |
| [`_containsJapanese`](#containsjapanese) | 静态方法（`AnimeSearchService`） | A | 检查字符串是否包含平假名/片假名字符。 |
| [`_searchFilmarks`](#searchfilmarks) | 静态方法（`AnimeSearchService`） | A | 抓取 filmarks.com 的搜索结果 HTML。 |
| [`_searchAniList`](#searchanilist) | 静态方法（`AnimeSearchService`） | A | 查询 AniList GraphQL API。 |
| [`_parseDayOfWeek`](#parsedayofweek) | 静态方法（`AnimeSearchService`） | A | 把英文星期名前缀解析为 `1..7`（周一..周日）。 |
| [`searchAnime1`](#searchanime1) | 静态方法（`AnimeSearchService`） | A | 搜索 anime1.me 找观看页 URL，带中文变体和子串回退及模糊排序。 |
| [`_bestSimilarity`](#bestsimilarity) | 静态方法（`AnimeSearchService`） | A | 计算一个标题对几个查询变体中任一的最佳模糊相似度得分。 |
| [`_similarity`](#similarity) | 静态方法（`AnimeSearchService`） | A | 组合 LCS、字符集 Dice 和包含关系的模糊相似度，经 S/T 规范化。 |
| [`_lcsLength`](#lcslength) | 静态方法（`AnimeSearchService`） | A | 两个字符串之间的最长公共子序列长度。 |
| [`_searchAnime1Single`](#searchanime1single) | 静态方法（`AnimeSearchService`） | A | 运行一次 anime1.me 搜索查询并从 HTML 提取系列标题/URL 对。 |
| [`_decodeHtmlEntities`](#decodehtmlentities) | 静态方法（`AnimeSearchService`） | A | 解码抓取标题中出现的少量 HTML 实体。 |

关于校验计数的说明：源文件有 14 个 `/// Purpose:` 文档注释，但本表有 16 行——`searchAnime1`（第 482 行）只有普通（非 `Purpose:`）文档注释，`_searchAnime1Single`（第 620 行）完全没有文档注释。两者都是真实、非平凡的声明，被上面索引为 Tier A。

## 文档

### `const AnimeSearchResult({required source, sourceUrl, title, titleJa, episodes, firstAirDate, airDayOfWeek, airTime, coverImageUrl, summary})` <a id="animesearchresult-new"></a>
- **种类：** `AnimeSearchResult` 的构造函数
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 25 行）
- **用途：** 保存一条规范化搜索结果，无论来源是哪个，形态都准备好预填动画编辑表单。
- **输入：** `source` 必填（来源显示名，如 `'bangumi.tv'`）；其余全可选，因为没有单个来源提供每个字段。
- **返回：** 新的 `AnimeSearchResult`。
- **副作用：** 无。
- **算法：** 通过 `const` 构造函数平凡字段赋值。
- **用法：**
  ```dart
  return AnimeSearchResult(
    source: 'bangumi.tv',
    sourceUrl: 'https://bgm.tv/subject/${m['id']}',
    title: (m['name_cn'] as String?)?.isNotEmpty == true ? m['name_cn'] as String : null,
    titleJa: m['name'] as String?,
    episodes: m['eps'] as int? ?? m['eps_count'] as int?,
    firstAirDate: airDate,
    coverImageUrl: images?['large'] as String? ?? images?['common'] as String?,
    summary: m['summary'] as String?,
  );
  ```
  （`AnimeSearchService._searchBangumi`，同一文件——五个元数据来源方法每个结果都构建一个）
- **备注：** `sourceUrl` 就是结果应用到编辑表单时后来变成 `Anime.infoUrl` 的东西——见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)。

### `static Future<List<AnimeSearchResult>> searchAll(String query)` <a id="searchall"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 47 行）
- **用途：** 并行查询 bangumi.tv、MyAnimeList、AniList、acgsecrets.hk 和 filmarks.com，返回一个去重后的结果列表。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>`。
- **副作用：** 并发向五个（或六个，见下）外部服务发起 HTTP 请求。
- **算法：**
  1. 计算 `simplified = ChineseConvert.toSimplified(query)`。
  2. 并发启动 `_searchBangumi`、`_searchMAL`、`_searchAcgsecrets`、`_searchFilmarks`、`_searchAniList`，每个都包在 `.catchError((_) => [])` 中，使一个来源的失败不会让整个调用失败。
  3. `simplified != query`（查询含繁体字符）时，额外加一次 `_searchBangumi(simplified)` 调用，因为 bangumi.tv 是大陆（简体）站点。
  4. `Future.wait` 全部，扁平化，用已见键的 `Set<String>` 按 `sourceUrl` 去重（`sourceUrl` 为 null 时回退 `title`），保留首见顺序。
- **用法：**
  ```dart
  final results = await AnimeSearchService.searchAll(query);
  ```
  （`lib/features/anime/views/anime_search_dialog.dart`，`_search`）
- **备注：** `anime1.me`（经 [`searchAnime1`](#searchanime1)）刻意**不**属于 `searchAll`——它返回观看页标题/URL 对，不是完整元数据，由编辑页的"查找观看 URL"流程单独查询。见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)。

### `static Future<List<AnimeSearchResult>> _searchBangumi(String query)` <a id="searchbangumi"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 82 行）
- **用途：** 查询 bangumi.tv 的旧条目搜索 API，把最多 5 条命中映射为 `AnimeSearchResult`。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>` — 非 200 响应或 `list` 字段缺失时为 `[]`。
- **副作用：** 对 `api.bgm.tv` 一次 HTTP GET（10 秒超时）。
- **算法：**
  1. GET `https://api.bgm.tv/search/subject/<urlencoded query>?type=2&responseGroup=large&max_results=5`。
  2. 状态不是 200 或 `json['list']` 缺失时返回 `[]`。
  3. 映射前 5 项：`title` 优先 `name_cn`（空则回退 `null`）、`titleJa` 用 `name`、集数用 `eps` 或 `eps_count`、`air_date` 经 `DateTime.tryParse` 解析、封面用 `images['large']`/`images['common']`。
- **用法：**
  ```dart
  _searchBangumi(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  （`AnimeSearchService.searchAll`，同一文件）
- **备注：** `type=2` 把结果限制在 bangumi.tv API 的动画条目类型。

### `static Future<List<AnimeSearchResult>> _searchMAL(String query)` <a id="searchmal"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 127 行）
- **用途：** 经公共 Jikan v4 API 查询 MyAnimeList，把最多 5 条命中映射为 `AnimeSearchResult`。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>` — 非 200 响应或 `data` 缺失时为 `[]`。
- **副作用：** 对 `api.jikan.moe` 一次 HTTP GET（10 秒超时）。
- **算法：**
  1. GET `https://api.jikan.moe/v4/anime?q=<urlencoded query>&limit=5`。
  2. 对每项：封面读 `images.jpg.large_image_url`/`image_url`；`aired.from` 经 `DateTime.tryParse` 解析；`broadcast` 存在时，经 [`_parseDayOfWeek`](#parsedayofweek) 解析其 `day` 字符串（如 `"Mondays"`），并直接把 `broadcast.time` 作为 `airTime`。
  3. 构建 `AnimeSearchResult`：`source: 'MyAnimeList'`、`title` 来自 `title`、`titleJa` 来自 `title_japanese`、`episodes`、`summary` 来自 `synopsis`。
- **用法：**
  ```dart
  _searchMAL(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  （`AnimeSearchService.searchAll`，同一文件）
- **备注：** Jikan 的 `broadcast.time` 已是 `HH:MM` 日本时间形式，因此不做重格式化直接透传为 `Anime.airTime`。

### `static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query)` <a id="searchacgsecrets"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 183 行）
- **用途：** 抓取 `acgsecrets.hk` 的每季动画列表（嵌入为 `application/ld+json` 脚本块）并对照查询模糊匹配条目，先试当前季、回退到上一季。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>` — 最多 5 条，按模糊匹配得分降序。
- **副作用：** 对 `acgsecrets.hk` 最多两次 HTTP GET（每次 15 秒超时），每试一季一次。
- **算法：**
  1. 从 [`_recentSeasons`](#recentseasons) 取 `[currentSeason, previousSeason]`；计算 `query` 的繁体与简体变体。
  2. 按顺序对每季：GET 季页面；非 200 跳过。用正则提取每个 `<script type="application/ld+json">` 块并 JSON 解码；对每个 `itemListElement` 条目，计算条目的 `name`/`alternateName`s 对 `query`/`queryTrad`/`querySimp` 的最佳 [`_similarity`](#similarity) 得分；跳过得分低于 `0.3` 的条目；跳过已见过的重复 `url`。
  3. 对存活的条目，经 [`_containsJapanese`](#containsjapanese) 从 `alternateName` 挑一个日文 `titleJa`（第一个含假名的别名），构建 `AnimeSearchResult`，`startDate` 经 `DateTime.tryParse` 解析。
  4. 当前季已产出任何结果时，在试上一季之前停下（`break`）。
  5. 把所有收集的 `(result, score)` 对按得分降序排序，返回前 5 条结果。
- **用法：**
  ```dart
  _searchAcgsecrets(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  （`AnimeSearchService.searchAll`，同一文件）
- **备注：** 任何单个 `<script>` 块的 JSON 解码失败按块捕获（`catch (_) {}`），使一个格式错误的块不会中止整季解析。

### `static List<String> _recentSeasons()` <a id="recentseasons"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 267 行）
- **用途：** 计算"本季"和"上一季"的 `acgsecrets.hk` 季代码（`YYYYMM`），最新优先。
- **输入：** 无（用 `DateTime.now()`）。
- **返回：** 恰好 2 个季代码的 `List<String>`。
- **副作用：** 无。
- **算法：** 从 `[1, 4, 7, 10].lastWhere((s) => m >= s)` 找当前季起始月；格式化 `'$year$month'`（零填充）；减去 3 个月计算上一季，当前季是一月时回卷为 `year - 1, 10`。
- **用法：**
  ```dart
  final seasons = _recentSeasons();
  ```
  （`AnimeSearchService._searchAcgsecrets`，同一文件）
- **备注：** 无。

### `static bool _containsJapanese(String s)` <a id="containsjapanese"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 288 行）
- **用途：** 检测字符串是否包含任何平假名或片假名字符，用于挑出日文假名替代标题。
- **输入：** `s`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 遍历 `s.runes`，在 `0x3040..0x309F`（平假名）或 `0x30A0..0x30FF`（片假名）中的第一个码点返回 `true`；没有匹配返回 `false`。
- **用法：**
  ```dart
  for (final n in altNames) {
    if (_containsJapanese(n)) {
      titleJa = n;
      break;
    }
  }
  ```
  （`AnimeSearchService._searchAcgsecrets`，同一文件）
- **备注：** 纯汉字替代名（与中文字符重叠）不被此检查判为日文——只有假名存在才算，因为单靠汉字无法区分日文标题和中文标题。

### `static Future<List<AnimeSearchResult>> _searchFilmarks(String query)` <a id="searchfilmarks"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 303 行）
- **用途：** 抓取 `filmarks.com` 的动画搜索结果页的标题/封面/URL，主模式一无所获时用更宽松的回退模式。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>` — 最多 5 条。
- **副作用：** 对 `filmarks.com` 一次 HTTP GET（10 秒超时，`Accept-Language: ja`）。
- **算法：**
  1. GET `https://filmarks.com/search/animes?q=<urlencoded query>`；非 200 返回 `[]`。
  2. 主模式：匹配包含可选 `<img>` 和一个 `class="...title..."` 元素的 `<a href="/anime/...">` 块；取最多 5 个，经 [`_decodeHtmlEntities`](#decodehtmlentities) 解码标题中的 HTML 实体。
  3. 主模式一无所获时，回退到匹配任何带可见文本（超过 1 个字符）的 `<a href="/anime/<digits>...">` 的宽松模式。
- **用法：**
  ```dart
  _searchFilmarks(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  （`AnimeSearchService.searchAll`，同一文件）
- **备注：** 两种模式都不捕获集数、播出日期或星期几/播出时间——`filmarks.com` 结果只会填充 `title`/`titleJa`（按抓取原样）/`sourceUrl`/`coverImageUrl`。这种 HTML 结构抓取本质上对站点标记变更脆弱。

### `static Future<List<AnimeSearchResult>> _searchAniList(String query)` <a id="searchanilist"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 367 行）
- **用途：** 查询 AniList GraphQL API，取最多 5 条匹配的媒体条目。
- **输入：** `query`。
- **返回：** `Future<List<AnimeSearchResult>>` — 非 200 响应或 `data.Page.media` 缺失时为 `[]`。
- **副作用：** 对 `graphql.anilist.co` 一次 HTTP POST（10 秒超时）。
- **算法：**
  1. POST 一个固定 GraphQL 查询（请求 `title`、`episodes`、`startDate`、`airingSchedule`、`coverImage`、`description`、`siteUrl`），带 `variables: {search: query}`。
  2. 对每个 `media` 条目：只在三者都出现时从 `startDate.{year,month,day}` 构建 `firstAirDate`；从该日期的 `.weekday` 派生 `airDayOfWeek`（因此它反映*首集*的星期几，而不是单独报告的播出日程）；从 `description` 剥离 HTML（把 `<br>` 变体替换为 `\n`、剥离剩余标签、反转义 `&amp;`/`&lt;`/`&gt;`/`&quot;`/`&#39;`）构建 `summary`。
  3. `title` 优先 `title.english`，回退 `title.romaji`；`titleJa` 用 `title.native`。
- **用法：**
  ```dart
  _searchAniList(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  （`AnimeSearchService.searchAll`，同一文件）
- **备注：** GraphQL 查询还请求 `airingSchedule(notYetAired: true, perPage: 1)`，但下方的解析代码目前不读该字段——`airDayOfWeek` 纯粹从 `startDate.weekday` 派生。

### `static int? _parseDayOfWeek(String day)` <a id="parsedayofweek"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 466 行）
- **用途：** 把英文星期名（如 Jikan 的 `broadcast.day` 返回的 `"Mondays"`）解析为 `Anime.airDayOfWeek` 的 `1..7`（周一..周日）编号。
- **输入：** `day`。
- **返回：** `int?` — 无可识别的星期前缀匹配时为 `null`。
- **副作用：** 无。
- **算法：** 小写化 `day`，按顺序检查三字母前缀（`mon`→1、`tue`→2、`wed`→3、`thu`→4、`fri`→5、`sat`→6、`sun`→7）。
- **用法：**
  ```dart
  if (dayStr != null) airDayOfWeek = _parseDayOfWeek(dayStr);
  ```
  （`AnimeSearchService._searchMAL`，同一文件）
- **备注：** 按前缀（`startsWith`）匹配，因此同时容忍 `"Monday"` 和 `"Mondays"` 两种形式。

### `static Future<List<({String title, String url})>> searchAnime1(String query, {List<String> altQueries = const []})` <a id="searchanime1"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 482 行）
- **用途：** 为一个标题找候选 `anime1.me` 分类/观看页 URL，尝试简体/繁体变体和可选替代查询，什么都不匹配时用双字子串回退，按模糊相似度排序。
- **输入：** `query`；`altQueries` — 也要尝试的额外标题变体（如搜索结果中的副标题）。
- **返回：** `Future<List<({String title, String url})>>` — 最多 10 条，最佳匹配在前。
- **副作用：** 对 `anime1.me` 一次或多次 HTTP GET（经 [`_searchAnime1Single`](#searchanime1single)），每个尝试的查询变体一次。
- **算法：**
  1. 构建 `Set<String>` 查询变体：`query`、它的繁体与简体形式，外加每个非空 `altQueries` 条目及其繁体/简体形式。
  2. 对每个变体运行 [`_searchAnime1Single`](#searchanime1single)，合并结果并按 `url` 去重。
  3. 没有匹配时，派生 `query` 的繁体、纯字母/数字形式；至少 4 个字符时，经 `_searchAnime1Single` 尝试最多 3 个尾部双字（2 字符子串，从尾部向前扫描），一旦某个子串产出结果就停止——这能捕捉繁体查询与实际系列标题共享短子串、但完整标题不同的情况。
  4. 把所有收集的结果按每个结果的 `title` 对每个查询变体的 [`_bestSimilarity`](#bestsimilarity) 降序排序。
  5. 返回前 10 条。
- **用法：**
  ```dart
  final results = await AnimeSearchService.searchAnime1(
    q,
    altQueries: widget.altQueries,
  );
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，"查找观看 URL"对话框中的 `_search`）
- **备注：** 此方法（与 `searchAll` 不同）不属于通用元数据搜索——它专门存在是为了给 `Anime.watchUrl` 找系列的 `anime1.me` 观看页 URL；见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)。

### `static double _bestSimilarity(String title, List<String> queries)` <a id="bestsimilarity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 551 行）
- **用途：** 计算一个候选标题对查询变体列表的最佳模糊相似度得分。
- **输入：** `title`、`queries`。
- **返回：** `0.0..1.0` 的 `double`。
- **副作用：** 无。
- **算法：** 对 `queries` 中的每个条目运行 [`_similarity`](#similarity)，保留最大值。
- **用法：**
  ```dart
  allResults.sort((a, b) {
    final sa = _bestSimilarity(a.title, queryVariants);
    final sb = _bestSimilarity(b.title, queryVariants);
    return sb.compareTo(sa); // descending
  });
  ```
  （`AnimeSearchService.searchAnime1`，同一文件）
- **备注：** 无。

### `static double _similarity(String a, String b)` <a id="similarity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 565 行）
- **用途：** 给两个字符串的相似程度打分，组合三种度量并取最佳，使重排过的标题和同一标题的简体/繁体变体都能得高分。
- **输入：** `a`、`b`。
- **返回：** `0.0..1.0` 的 `double`；任一输入为空时 `0`。
- **副作用：** 无。
- **算法：**
  1. 计算 `a` 和 `b` 的繁体规范化形式（`aNorm`、`bNorm`）。
  2. 对 `(a, b)` 和 `(aNorm, bNorm)` 各做：
     - 基于 LCS 的 Dice：经 [`_lcsLength`](#lcslength) 得 `2 * lcsLength / (len(s1) + len(s2))`。
     - 字符集 Dice（与顺序无关）：在 `.runes.toSet()` 上 `2 * |set1 ∩ set2| / (|set1| + |set2|)`。
     - 包含关系：一个字符串包含另一个时，得分 `0.7 + 0.3 * (shorter.length / longer.length)`（保证至少 `0.7`）。
  3. 返回两遍规范化和全部三种度量中见过的最高分。
- **用法：**
  ```dart
  final s = _similarity(n, q);
  if (s > bestScore) bestScore = s;
  ```
  （`AnimeSearchService._searchAcgsecrets`，同一文件——`_bestSimilarity` 也用它做 `anime1.me` 排序）
- **备注：** 同时比较原始和繁体规范化形式意味着简体查询仍能对纯繁体标题得高分（反之亦然），两侧都不需要调用方预先规范化。

### `static int _lcsLength(String a, String b)` <a id="lcslength"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 599 行）
- **用途：** 计算两个字符串之间的最长公共子序列（LCS）长度，是 `_similarity` 的 LCS-Dice 得分背后的核心原语。
- **输入：** `a`、`b`。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** 标准 O(n·m) 动态规划 LCS，用两个滚动行（`prev`/`curr`）而不是完整 2D 表省内存；字符匹配时 `curr[j] = prev[j-1] + 1`，否则 `curr[j] = max(prev[j], curr[j-1])`；每次外层迭代后交换并清空两行。
- **用法：**
  ```dart
  final lcs = 2.0 * _lcsLength(s1, s2) / (s1.length + s2.length);
  ```
  （`AnimeSearchService._similarity`，同一文件）
- **备注：** 这里 O(n·m) 可接受，正是因为两个输入都是短的动画标题，不是任意长度的文本，按源码注释。

### `static Future<List<({String title, String url})>> _searchAnime1Single(String query)` <a id="searchanime1single"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 620 行）
- **用途：** 运行一次 `anime1.me` 搜索查询，从结果 HTML 提取系列（不是剧集）标题/URL 对，按优先级顺序尝试三个回退正则模式。
- **输入：** `query`。
- **返回：** `Future<List<({String title, String url})>>` — 非 200 响应时为 `[]`。
- **副作用：** 对 `anime1.me` 一次 HTTP GET（10 秒超时）。
- **算法：**
  1. GET `https://anime1.me/?s=<urlencoded query>`；非 200 返回 `[]`。
  2. 优先级 1：匹配带 `rel="...category..."` 标签的 `<a href="https://anime1.me/category/...">` 链接——这些是系列/合集页。
  3. 优先级 2（只在优先级 1 一无所获时）：匹配 `<a href="https://anime1.me/?cat=<id>">` 链接。
  4. 优先级 3（只在上面两个都一无所获时）：匹配 `<h2 class="...entry-title...">` 剧集帖链接，从标题剥离尾部 `" [<episode number>]"` 后缀，使同一系列的重复剧集坍缩为一个条目。
  5. 每个模式按标题去重（`Set<String> seen`）并经 [`_decodeHtmlEntities`](#decodehtmlentities) 解码 HTML 实体。
- **用法：**
  ```dart
  final partial = await _searchAnime1Single(q);
  for (final r in partial) {
    if (seenUrls.add(r.url)) {
      allResults.add(r);
    }
  }
  ```
  （`AnimeSearchService.searchAnime1`，同一文件——每个查询变体调用一次）
- **备注：** 三个优先级层存在是因为 `anime1.me` 的搜索结果页混着分类链接（干净的系列级结果）和单个剧集帖链接（优先级 3 的回退）——只在更干净的模式一无所获时下探，可避免在分类链接可用时浮出几十条重复的逐剧集条目。

### `static String _decodeHtmlEntities(String text)` <a id="decodehtmlentities"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 695 行）
- **用途：** 解码从 `filmarks.com` 和 `anime1.me` 抓取的标题中出现的小型固定 HTML 实体集。
- **输入：** `text`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 按固定顺序对 `&amp;`、`&lt;`、`&gt;`、`&quot;`、`&#39;`、`&apos;` 链式 `replaceAll`。
- **用法：**
  ```dart
  titleJa: _decodeHtmlEntities(title),
  ```
  （`AnimeSearchService._searchFilmarks`，同一文件）
- **备注：** 只处理这七个实体——`&#39;` 之外的数字字符引用（如 `&#8217;`）或此列表之外的命名实体原样通过、不转义。
