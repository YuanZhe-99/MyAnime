# lib/features/anime/services/anime_search_service.dart

`AnimeSearchService` 查询或抓取五个外部番剧资料库（`bangumi.tv`、经 Jikan v4 的 MyAnimeList、AniList、
`acgsecrets.hk` 和 `filmarks.com`），返回规范化的 `AnimeSearchResult`；它还拥有标题评分器（`similarityRaw`、`orderedSimilarity`、`foldTitle`）与 [`anime1_service.md`](anime1_service.md) 所依赖的别名补采——`anime1.me` 观看链接查找在 1.5.7 中迁到了那里。它是**仅在完整版
构建中可用**的普通共享工具——它本身不强制执行该限制；由调用方门禁（flavor 门禁规则、各来源字段矩阵与
两阶段语言策略见
[`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)）。它依赖
[`../../../shared/utils/chinese_convert.md`](../../../shared/utils/chinese_convert.md) 生成简体/繁体
查询变体，并依赖 [`../models/anime.md`](../models/anime.md) 提供它所产出的 `AnimeExternalMeta` 记录。
其结果供给 `anime_edit_page.dart` 的「在线搜索」流程、`anime_detail_page.dart` 的元数据刷新，以及桌面
本地 API 服务器。

`AnimeSearchResult` 字段映射到 [`../../../../data-formats.md`](../../../../data-formats.md) 中记录的
`Anime` 字段（如 `sourceUrl` 变成 `infoUrl`，元数据块变成 `externalMeta`）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AnimeSearchResult(...)`](#animesearchresult-new) | 构造函数（`AnimeSearchResult`） | A | 保存来自任何来源的一条规范化搜索命中。 |
| [`allTitles`](#alltitles) | getter（`AnimeSearchResult`） | A | 收集该结果已知的每个标题，并去重。 |
| [`displayTitle`](#displaytitle) | getter（`AnimeSearchResult`） | B | 返回第一个已知标题，或 `?`。 |
| [`toJson`](#resulttojson) | 方法（`AnimeSearchResult`） | A | 序列化抓取到的结果，以便缓存到磁盘。 |
| [`fromJson`](#resultfromjson) | 工厂（`AnimeSearchResult`） | A | 防御式地从缓存重建结果。 |
| `AnimeSearchSource._()` | 构造函数（`AnimeSearchSource`） | B | 阻止实例化来源名常量持有类。 |
| `AnimeSearchProgress(...)` | 构造器（`AnimeSearchProgress`） | B | 保存单轮检索的实时进度。 |
| `done` | getter（`AnimeSearchProgress`） | B | 已有多少来源作出回应。 |
| `total` | getter（`AnimeSearchProgress`） | B | 本轮查询多少个来源。 |
| [`fraction`](#searchprogressfraction) | getter（`AnimeSearchProgress`） | A | 本轮的完成比例，或 `null`。 |
| `isPending` | 方法（`AnimeSearchProgress`） | B | 某个来源是否仍在等待中。 |
| [`searchAll`](#searchall) | 静态方法（`AnimeSearchService`） | A | 执行两阶段跨语言检索并返回一个排好序的列表。 |
| [`queryVariants`](#queryvariants) | 静态方法（`AnimeSearchService`） | A | 为查询构建简体/繁体变体集合。 |
| [`relevance`](#relevance) | 静态方法（`AnimeSearchService`） | A | 用查询变体集合对结果的全部标题打分。 |
| [`_languageAffinity`](#languageaffinity) | 静态方法（`AnimeSearchService`） | A | 报告结果是否带有用户界面语言的标题。 |
| [`toExternalMeta`](#toexternalmeta) | 静态方法（`AnimeSearchService`） | A | 把搜索结果转换成持久化的 `AnimeExternalMeta` 记录。 |
| [`fetchByUrl`](#fetchbyurl) | 静态方法（`AnimeSearchService`） | A | 按 id 从来源页面 URL 重新抓取一部番剧。 |
| [`refreshAll`](#refreshall) | 静态方法（`AnimeSearchService`） | A | 并行重新抓取多个来源页面，跳过失败项。 |
| [`_runRound`](#runround) | 静态方法（`AnimeSearchService`） | A | 并行查询指定来源一轮，并容忍单点失败。 |
| [`_harvestBackfillTitles`](#harvestbackfilltitles) | 静态方法（`AnimeSearchService`） | A | 从第一轮结果中挑出用于第二轮的跨语言标题。 |
| [`_searchBangumi`](#searchbangumi) | 静态方法（`AnimeSearchService`） | A | 查询 bangumi.tv 的 v0 搜索 API。 |
| [`_fetchBangumiById`](#fetchbangumibyid) | 静态方法（`AnimeSearchService`） | B | 按数字 id 抓取一个 bangumi.tv 条目。 |
| [`mapBangumiSubject`](#mapbangumisubject) | 静态方法（`AnimeSearchService`） | A | 把一个 bangumi.tv v0 条目对象映射为 `AnimeSearchResult`。 |
| [`parseBangumiWeekday`](#parsebangumiweekday) | 静态方法（`AnimeSearchService`） | A | 把 bangumi.tv 的 `放送星期` 文本解析到周一=1..周日=7。 |
| [`_bangumiInfoboxText`](#bangumiinfoboxtext) | 静态方法（`AnimeSearchService`） | B | 把一条 `infobox` 记录读为纯文本。 |
| [`_bangumiInfoboxList`](#bangumiinfoboxlist) | 静态方法（`AnimeSearchService`） | B | 把一条 `infobox` 记录读为字符串列表。 |
| [`_parseCjkDate`](#parsecjkdate) | 静态方法（`AnimeSearchService`） | B | 解析 `2023年9月29日` 这类中日文日期。 |
| [`_searchMAL`](#searchmal) | 静态方法（`AnimeSearchService`） | A | 经 Jikan v4 API 查询 MyAnimeList。 |
| [`_fetchMalById`](#fetchmalbyid) | 静态方法（`AnimeSearchService`） | B | 经 Jikan 的 `/full` 按数字 id 抓取一个 MyAnimeList 条目。 |
| [`mapJikanAnime`](#mapjikananime) | 静态方法（`AnimeSearchService`） | A | 把一个 Jikan 番剧对象映射为 `AnimeSearchResult`。 |
| [`parseJikanDuration`](#parsejikanduration) | 静态方法（`AnimeSearchService`） | A | 把 Jikan 的自然语言时长字符串解析为分钟数。 |
| [`_namedList`](#namedlist) | 静态方法（`AnimeSearchService`） | B | 把 Jikan 的 `[{name: ...}]` 数组读成字符串列表。 |
| [`_searchAcgsecrets`](#searchacgsecrets) | 静态方法（`AnimeSearchService`） | A | 抓取 acgsecrets.hk 季度页面 JSON-LD 并对照查询做模糊匹配。 |
| [`_recentSeasons`](#recentseasons) | 静态方法（`AnimeSearchService`） | B | 计算当前与上一季度的季度代码（`YYYYMM`）。 |
| [`_containsJapanese`](#containsjapanese) | 静态方法（`AnimeSearchService`） | A | 检查字符串是否包含平假名/片假名字符。 |
| [`_isLatinScript`](#islatinscript) | 静态方法（`AnimeSearchService`） | A | 检查字符串是否为拉丁字母书写。 |
| [`_isLikelyChinese`](#islikelychinese) | 静态方法（`AnimeSearchService`） | A | 检查字符串读起来是中文而非日文。 |
| [`_searchFilmarks`](#searchfilmarks) | 静态方法（`AnimeSearchService`） | A | 抓取 filmarks.com 的搜索结果 HTML。 |
| [`_searchAniList`](#searchanilist) | 静态方法（`AnimeSearchService`） | A | 查询 AniList GraphQL API。 |
| [`_fetchAniListById`](#fetchanilistbyid) | 静态方法（`AnimeSearchService`） | B | 按数字 id 抓取一个 AniList media 条目。 |
| [`_postAniList`](#postanilist) | 静态方法（`AnimeSearchService`） | B | 向 AniList POST 一个 GraphQL 文档并返回其 `data` 对象。 |
| [`mapAniListMedia`](#mapanilistmedia) | 静态方法（`AnimeSearchService`） | A | 把一个 AniList media 对象映射为 `AnimeSearchResult`。 |
| [`_aniListDate`](#anilistdate) | 静态方法（`AnimeSearchService`） | B | 从 AniList 的 `{year, month, day}` 对象构建 `DateTime`。 |
| [`_aniListFirstAiringAt`](#anilistfirstairingat) | 静态方法（`AnimeSearchService`） | A | 挑出最能代表放送时段的放送时间戳。 |
| [`_jstBroadcastSlot`](#jstbroadcastslot) | 静态方法（`AnimeSearchService`） | A | 把日本时间的放送时刻映射到它所归属的编成时段。 |
| [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot) | 静态方法（`AnimeSearchService`） | A | 把首播日期平移到深夜时段所属的日历日。 |
| [`_toDouble`](#todouble) | 静态方法（`AnimeSearchService`） | B | 把 JSON 数字强制转换为 `double`。 |
| [`parseDayOfWeek`](#parsedayofweek) | 静态方法（`AnimeSearchService`） | A | 把英文星期名前缀解析为 `1..7`（周一..周日）。 |
| [`harvestAliases`](#harvestaliases) | 静态方法（`AnimeSearchService`） | A | 为 anime1.me 查找从 bangumi.tv 获取一个查询的别名。 |
| [`aliasCandidatesFrom`](#aliascandidatesfrom) | 静态方法（`AnimeSearchService`），`@visibleForTesting` | A | 从可信的搜索命中中挑出中文与拉丁字母的别名字符串。 |
| [`bestSimilarity`](#bestsimilarity) | 静态方法（`AnimeSearchService`） | A | 计算一个标题对若干查询变体中任一的最佳模糊相似度得分。 |
| [`_similarity`](#similarity) | 静态方法（`AnimeSearchService`） | A | 组合 LCS、字符集 Dice 和包含关系的模糊相似度，经简繁归一化。 |
| [`similarityRaw`](#similarityraw) | 静态方法（`AnimeSearchService`） | A | 不做任何归一化的三项相似度核心（LCS-Dice、字符集 Dice、包含关系）。 |
| [`orderedSimilarity`](#orderedsimilarity) | 静态方法（`AnimeSearchService`） | A | 只看顺序的相似度——LCS-Dice 或包含关系。 |
| [`foldTitle`](#foldtitle) | 静态方法（`AnimeSearchService`） | A | 把标题归一化用于匹配：半角、小写、去标点、转简体。 |
| [`_lcsLength`](#lcslength) | 静态方法（`AnimeSearchService`） | A | 两个字符串之间的最长公共子序列长度。 |
| [`decodeHtmlEntities`](#decodehtmlentities) | 静态方法（`AnimeSearchService`） | B | 解码抓取标题中出现的少量 HTML 实体。 |
| `_BackfillTitles(...)` | 构造函数（`_BackfillTitles`） | B | 每个语言家族保存一个补搜标题。 |
| `hasAny` | getter（`_BackfillTitles`） | B | 报告是否收集到任何可用标题。 |

关于校验计数的说明：截至 1.5.7 源文件有 59 个 `/// Purpose:` 文档注释。历史上多出的那一行——`searchAnime1` 带的是普通
（非 `Purpose:`）文档注释——随该方法一起消失：它迁到 `anime1_service.dart` 成为 `search`，并获得了完整注释块。

有七个声明（`mapBangumiSubject`、`parseBangumiWeekday`、`mapJikanAnime`、`parseJikanDuration`、
`mapAniListMedia`、`parseDayOfWeek`、`aliasCandidatesFrom`）标注了 `@visibleForTesting`。它们公开的唯一原因是让
`test/anime_search_test.dart` 能用固定 JSON 数据检验各来源的格式解析——HTTP 调用是静态的、无法注入
client，因此这些映射函数是唯一可行的测试接缝。不要在本文件之外的生产代码中调用它们。

## 文档

### `const AnimeSearchResult({required source, sourceUrl, title, titleJa, titleRomaji, titleEn, synonyms, episodes, firstAirDate, airDayOfWeek, airTime, endDate, format, status, durationMinutes, genres, studios, score, scoreMax, scoreVotes, scoreRank, coverImageUrl, summary})` <a id="animesearchresult-new"></a>
- **种类：** `AnimeSearchResult` 的构造函数
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 68 行）
- **用途：** 保存一条规范化搜索结果，无论来源是哪个，形态都准备好预填番剧编辑表单。
- **输入：** `source` 必填（来源显示名，如 `'bangumi.tv'`）；其余全可选，因为没有单个来源提供每个字段。`synonyms`、`genres`、`studios` 默认为空列表；`scoreMax` 默认为 `10`。
- **返回：** 新的 `AnimeSearchResult`。
- **副作用：** 无。
- **算法：** 通过 `const` 构造函数做平凡字段赋值。
- **备注：** 结果被应用时 `sourceUrl` 会变成 `Anime.infoUrl`，同时也是后续刷新重新查询的键。每个来源的评分在进入 `score` 之前都会归一化到 10 分制，因此当前所有来源的 `scoreMax` 实际都是 `10`。哪个来源填哪个字段见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md) 中的字段矩阵。

### `List<String> get allTitles` <a id="alltitles"></a>
- **种类：** `AnimeSearchResult` 的 getter
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 100 行）
- **用途：** 按展示顺序收集该结果已知的每个标题。
- **返回：** `List<String>` —— 已去重、已过滤空白。
- **副作用：** 无。
- **算法：** 依次遍历 `title`、`titleJa`、`titleRomaji`、`titleEn`，再遍历每个 `synonym`；逐个 trim、跳过空串，并用 `Set<String>` 保持首次出现顺序。
- **用法：**
  ```dart
  for (final title in r.allTitles) { /* 每个标题一个 SelectableText */ }
  ```
  （`lib/features/anime/views/anime_search_dialog.dart`，`_showResultDetails`）
- **备注：** 有三处用途：相关度评分、长按详情面板，以及收集跨语言补搜查询。顺序有意义——`title` 在前意味着展示回退优先使用本地化标题。

### `String get displayTitle` <a id="displaytitle"></a>
- **种类：** `AnimeSearchResult` 的 getter
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 116 行）
- **用途：** 返回最适合作为结果标题行的名称。
- **返回：** `String` —— `allTitles` 的第一项，全为空时返回 `'?'`。
- **副作用：** 无。
- **备注：** 取代了对话框中旧的内联写法 `r.title ?? r.titleJa ?? '?'`，后者看不到罗马音标题和英文标题。

### `Map<String, dynamic> toJson()` <a id="resulttojson"></a>
- **种类：** `AnimeSearchResult` 的方法
- **用途：** 序列化抓取到的结果，以便缓存到磁盘。
- **返回：** `Map<String, dynamic>`，只包含非 null、非空的字段。
- **副作用：** 无。
- **备注：** 1.5.0 新增，用于支撑后台更新缓存 —— 该缓存把候选下载一次，之后无需再联网即可应用。null 与
  空字段被省略，使缓存文件保持小巧可读。

  `firstAirDate` 与 `endDate` 是**日历日，不是时刻**：它们原样写入、读回时不做 UTC 转换，与番剧模型中
  的 `_parseCalendarDate` 一致。把它们归一化到 UTC 会在 UTC 以东的每个时区（包括日本）渲染成前一天。

### `factory AnimeSearchResult.fromJson(Map<String, dynamic>)` <a id="resultfromjson"></a>
- **种类：** `AnimeSearchResult` 的工厂构造器
- **用途：** 从 JSON 形态重建缓存的结果。
- **副作用：** 无。
- **备注：** 每个字段都是防御式读取的 —— 由更新版本写入、或被手工编辑过的缓存会得到 null 而不是抛出。
  `source` 回退为空字符串，因此格式错误的条目仍然可读，可以由调用方丢弃，而不会把整个文件一起拖垮。

### `static Future<List<AnimeSearchResult>> searchAll(String query, {String? preferredLanguage, void Function(AnimeSearchProgress)? onProgress})` <a id="searchall"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 173 行）
- **用途：** 查询每个元数据来源，返回一个去重且按相关度排序的列表。
- **输入：** `query`；`preferredLanguage` —— 调用方传入的界面语言标签（如 `zh_TW`、`ja`）。
- **返回：** `Future<List<AnimeSearchResult>>`。
- **副作用：** 并发向五个外部服务发起 HTTP 请求；跨语言补搜触发时会对其中一部分再发一次。
- **算法：**
  1. 构建 `variants = queryVariants(query)`。
  2. 经 [`_runRound`](#runround) 执行**第一轮**，按源做语言定向：bangumi.tv 收到简体形式，acgsecrets.hk 收到繁体形式，filmarks.com 收到原始查询（带 `Accept-Language: ja`），MyAnimeList/AniList 收到原始查询。
  3. 计算零结果的来源集合。若为空，直接跳到第 6 步。
  4. 经 [`_harvestBackfillTitles`](#harvestbackfilltitles) 最多收集三个跨语言标题。若什么都没收集到，跳到第 6 步。
  5. 经 `_runRound` 执行**第二轮**，*仅*为零结果的来源传入查询，每个来源用它自己的语言。没有收集到拉丁标题时，MyAnimeList 与 AniList 回退到收集到的日文标题，因为两者同样索引原文标题。
  6. 按 `sourceUrl`（回退到 `title`，再回退到 `titleJa`）去重，并按 `AnimeSearchSource.all` 顺序遍历来源，使输出稳定。
  7. 按 [`relevance`](#relevance) 降序排序，同分时按来源名排序。
- **用法：**
  ```dart
  final results = await AnimeSearchService.searchAll(query, preferredLanguage: language);
  ```
  （`lib/features/anime/views/anime_search_dialog.dart`，`_search`）
- **备注：** 取代了 1.4.0 之前的单轮实现——旧实现把原始查询发给每个来源，只对 bangumi.tv 做了简繁特判。额外轮次恰好只有一轮、不递归，因此最坏情况下延迟约翻倍，而各来源仍通过 `.catchError` 各自独立失败。`anime1.me` 刻意不属于 `searchAll`；其查找住在 [`anime1_service.md`](anime1_service.md)。

### `static List<String> queryVariants(String query)` <a id="queryvariants"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 250 行）
- **用途：** 构建各处通用的简体/繁体查询变体。
- **输入：** `query`。
- **返回：** `List<String>` —— trim 后的原始查询在前，随后是各不相同的变体；空串被丢弃。
- **副作用：** 无。
- **算法：** `{trimmed, toSimplified(trimmed), toTraditional(trimmed)}` 构成的 `Set<String>`，过滤掉空串。不含汉字的查询会塌缩成单个条目。
- **备注：** 之所以公开，是为了让搜索对话框能用与服务实际检索时完全相同的变体集合评分，避免各自推导而产生偏差。

### `static double relevance(AnimeSearchResult result, List<String> queries, {String? preferredLanguage})` <a id="relevance"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 270 行）
- **用途：** 评估一条结果与一组查询变体的匹配程度。
- **输入：** `result`、`queries`（通常来自 [`queryVariants`](#queryvariants)）；`preferredLanguage` —— 在接近同分时应当胜出的界面语言标签。
- **返回：** `0.0..1.05` 之间的 `double`。
- **副作用：** 无。
- **算法：** 对 `result.allTitles` 的每一项运行 [`bestSimilarity`](#bestsimilarity) 取最大值，随后在 [`_languageAffinity`](#languageaffinity) 判定该结果带有 `preferredLanguage` 的标题时加上 `_languageBonus`（0.05）。
- **用法：**
  ```dart
  double _relevance(AnimeSearchResult r) => AnimeSearchService.relevance(
    r, _queryVariants, preferredLanguage: _searchLanguage,
  );
  ```
  （`lib/features/anime/views/anime_search_dialog.dart`，`_relevance`）
- **备注：** 对*每个*标题打分正是排序语言中立的原因：日文标题匹配日文查询的命中，与中文标题匹配中文查询的命中得分同样高。语言加成刻意远小于好匹配与差匹配之间的差距，因此它只会重排本就匹配得差不多的结果，绝不可能把更差的匹配抬到更好的匹配之上。对话框传入它检索时所用的同一语言，因此在那里重新排序会精确重现服务返回的顺序，而不会在同分处产生偏差。

### `static double _languageAffinity(AnimeSearchResult result, String? languageTag)` <a id="languageaffinity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 290 行）
- **用途：** 报告结果是否带有用户界面语言的标题。
- **返回：** `double` —— 是则 `1`，否则 `0`（标签为 null 或空串时亦为 `0`）。
- **副作用：** 无。
- **算法：** `ja` 标签经 [`_containsJapanese`](#containsjapanese) 检查 `titleJa`；`zh` 标签经 [`_isLikelyChinese`](#islikelychinese) 检查 `title`；其他（拉丁字母）标签检查 `titleEn` 或 `titleRomaji` 是否非 null。
- **备注：** 按标签的语言前缀匹配，因此 `zh`、`zh_CN`、`zh_TW` 行为一致——简繁之分已由查询变体处理，不在此处重复。

### `static AnimeExternalMeta toExternalMeta(AnimeSearchResult result, {DateTime? fetchedAt})` <a id="toexternalmeta"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 314 行）
- **用途：** 把搜索结果转换成持久化的外部元数据记录。
- **输入：** `result`；`fetchedAt` —— 覆盖时间戳，供测试使用。
- **返回：** `AnimeExternalMeta`。
- **副作用：** 无。
- **算法：** 直接复制各元数据字段；当来源报告了 `score`/`scoreVotes`/`scoreRank` 中任一项时，追加一条 `AnimeExternalRating`，携带 `source`、`sourceUrl`、评分、`scoreMax`、票数、排名与 `fetchedAt`（UTC）。`refreshedAt` 设为同一时间戳。
- **用法：**
  ```dart
  final fetched = AnimeSearchService.toExternalMeta(r);
  result['externalMeta'] = widget.currentExternalMeta?.mergedWith(fetched) ?? fetched;
  ```
  （`lib/features/anime/views/anime_search_dialog.dart`，`_apply`）
- **备注：** 用户自己的 `AnimeRating` 绝不参与其中——外部评分只存在于 `externalMeta.ratings`。在每条评分记录上保留 `sourceUrl` 正是后续 [`refreshAll`](#refreshall) 得以实现的前提；没有评分的来源只贡献元数据、不产生评分记录，因此除 `infoUrl` 外没有可刷新的对象。

### `static Future<AnimeSearchResult?> fetchByUrl(String url)` <a id="fetchbyurl"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 357 行）
- **用途：** 从番剧的来源页面 URL 重新抓取其元数据。
- **输入：** `url` —— AniList、MyAnimeList 或 bangumi.tv 的条目页 URL。
- **返回：** `Future<AnimeSearchResult?>` —— 主机不属于这三个有 API 的来源时，或抓取失败时返回 `null`。
- **副作用：** 向对应 API 发起一次 HTTP 请求。
- **算法：** 依次用正则从 `anilist.co/anime/(\d+)`、`myanimelist.net/anime/(\d+)`、`(?:bgm\.tv|bangumi\.tv|chii\.in)/subject/(\d+)` 中提取数字 id 并分派到对应的按 id 抓取；都不匹配则落到 `null`。
- **备注：** `acgsecrets.hk` 与 `filmarks.com` 是抓取而非按 id 查询，没有稳定的按 URL 端点，因此被跳过。每个按 id 抓取都复用与其搜索路径**完全相同**的映射函数，因此搜索与刷新不会产生偏差。

### `static Future<List<AnimeSearchResult>> refreshAll(Iterable<String> urls)` <a id="refreshall"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 382 行）
- **用途：** 为一次元数据刷新同时重新抓取多个来源页面。
- **输入：** `urls`。
- **返回：** `Future<List<AnimeSearchResult>>` —— 只包含成功的抓取。
- **副作用：** 每个可识别的 URL 一次 HTTP 请求，并行发出。
- **算法：** 丢弃空串、去重，在 `Future.wait` 下对每个 URL 运行 `fetchByUrl` 并各自 `.catchError((_) => null)`，最后用 `whereType` 过滤掉 null。
- **用法：**
  ```dart
  final results = await AnimeSearchService.refreshAll(urls);
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，`_refreshExternalMeta`）
- **备注：** 失败或无法识别的 URL 会被跳过而不是让整次刷新失败，与 `searchAll` 容忍失效来源的方式一致。

### `static Future<Map<String, List<AnimeSearchResult>>> _runRound({required bangumiQuery, required acgsecretsQuery, required filmarksQuery, required globalQuery, malQuery, anilistQuery})` <a id="runround"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 404 行）
- **用途：** 并行查询指定来源一轮，并容忍单点失败。
- **输入：** 每个来源一个查询；`globalQuery` 是 MyAnimeList 与 AniList 的默认值，在补搜轮中由 `malQuery`/`anilistQuery` 覆盖。
- **返回：** `Future<Map<String, List<AnimeSearchResult>>>`，以来源名为键。
- **副作用：** 每个非 null、非空白的查询一次 HTTP 请求。
- **算法：** 局部函数 `run(query, fetch)` 在查询为 `null` 或空白时返回一个立即完成的空列表，否则调用 `fetch(query.trim()).catchError((_) => [])`。五个 future 一并 await，再按来源名 zip 回去。
- **备注：** `null` 或空白查询表示「本轮跳过该来源」——第二轮正是靠这一点只针对零结果来源发起查询。返回值以来源为键，才使 `searchAll` 能区分「返回了空」与「本来就没问」。

### `static _BackfillTitles _harvestBackfillTitles(Map<String, List<AnimeSearchResult>> round, List<String> queryVariants)` <a id="harvestbackfilltitles"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 442 行）
- **用途：** 从第一轮结果中挑出用于第二轮的跨语言标题。
- **输入：** `round` —— 第一轮的按源结果；`queryVariants`。
- **返回：** `_BackfillTitles`，最多包含一个日文、一个拉丁字母、一个中文标题。
- **副作用：** 无。
- **算法：**
  1. 收集相关度不低于 `_backfillMinRelevance`（0.45）的结果，候选数达到 `_maxBackfillTitles * 2` 即停止。
  2. 日文槽取第一个通过 [`_containsJapanese`](#containsjapanese) 的 `titleJa` 或别名；拉丁槽取第一个通过 [`_isLatinScript`](#islatinscript) 的 `titleRomaji`/`titleEn`/别名；中文槽取第一个通过 [`_isLikelyChinese`](#islikelychinese) 的 `title` 或别名。
  3. 三个槽全部填满即提前结束。
  4. 中文标题同时以简体与繁体两种形式返回。
- **备注：** 相关度下限就是整个安全机制——没有它，某个模糊匹配来源的一条无关命中就会劫持第二轮，把完全另一部作品的结果拉进来。

### `static Future<List<AnimeSearchResult>> _searchBangumi(String query)` <a id="searchbangumi"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 498 行）
- **用途：** 查询 bangumi.tv 的 **v0** 条目搜索 API，并映射最多 `_maxPerSource` 条命中。
- **输入：** `query` —— 实践中是简体变体，因为 bangumi.tv 是中国大陆站点。
- **返回：** `Future<List<AnimeSearchResult>>` —— 非 200 响应或缺少 `data` 字段时返回 `[]`。
- **副作用：** 向 `api.bgm.tv` 发起一次 HTTP POST（15 秒超时）。
- **算法：** 向 `https://api.bgm.tv/v0/search/subjects?limit=10` POST `{"keyword": query, "filter": {"type": [2]}}`，再把每一项交给 [`mapBangumiSubject`](#mapbangumisubject)。
- **备注：** `filter.type: [2]` 把结果限定为番剧条目类型。**这在 1.4.0 中从旧版端点迁移而来。** 从首个版本一直用到 1.3.3 的 `GET /search/subject/<query>` 现在对每个请求都返回 Cloudflare 的 `502 Bad gateway`；而由于该方法把任何非 200 都当作「无结果」，bangumi.tv 实际上已经完全从搜索中消失，且任何地方都不会报错。v0 API 返回的内容也严格更多：`infobox` 携带放送星期、别名、制作公司与完结日期，这些在旧版搜索响应中一个都没有。

### `static Future<AnimeSearchResult?> _fetchBangumiById(int id)` <a id="fetchbangumibyid"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 538 行）
- **用途：** 按数字 id 抓取一个 bangumi.tv 条目。
- **返回：** `Future<AnimeSearchResult?>` —— 非 200 响应或响应体没有 `id` 时返回 `null`。
- **副作用：** 向 `api.bgm.tv` 发起一次 HTTP GET（10 秒超时）。
- **备注：** 路径是 `/v0/subjects/{id}` —— **复数**。单数形式 `/v0/subject/{id}` 返回 404，而旧版的 `/subject/{id}` 与该 API 的其余部分一样是 502。响应形态与 v0 搜索相同，因此一个映射函数即可服务两条路径。

### `static AnimeSearchResult mapBangumiSubject(Map<String, dynamic> m)` <a id="mapbangumisubject"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 561 行）
- **用途：** 把一个 bangumi.tv v0 条目对象映射为 `AnimeSearchResult`。
- **输入：** `m` —— 一个 v0 条目 map，来自搜索或按 id 的端点。
- **返回：** `AnimeSearchResult`。
- **副作用：** 无。
- **算法：** `title` 优先取 `name_cn`（空串时为 null），`titleJa` 取 `name`；读取 `eps`（回退到 `total_episodes`）、ISO 格式的 `date` 字段、`rating.score`/`rating.total`/`rating.rank`、`images.large`/`images.common`/`image`，以及使用最多的前五个 `tags` 作为类型标签。排期与其余名称来自 `infobox`：`别名` → `synonyms`，`动画制作` → `studios`，`放送星期` → 经 [`parseBangumiWeekday`](#parsebangumiweekday) 得到 `airDayOfWeek`，`播放结束` → 经 [`_parseCjkDate`](#parsecjkdate) 得到 `endDate`。
- **备注：** `eps` 优先于 `total_episodes`，因为后者把特别篇也算进去了——《葬送的芙莉莲》分别是 28 与 36，而应用要排期的 TV 本篇是 28 集。bangumi.tv 的评分本身就是 10 分制，因此不做缩放直接保存。注意 `rank` 位置变了：在 v0 中它是 `rating.rank`，而非旧版形态中的顶层字段。

### `static String? _bangumiInfoboxText(List<dynamic>? infobox, String key)` <a id="bangumiinfoboxtext"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 612 行）
- **用途：** 把一条 `infobox` 记录读为纯文本。
- **返回：** `String?` —— 键不存在或其值不是纯字符串时返回 `null`。
- **副作用：** 无。
- **备注：** bangumi 的 `infobox` 是一个 `{key, value}` 列表，其中 `value` 视字段而定*要么*是字符串、要么是 `{v: ...}` map 的列表；本函数只读字符串形式，另一种由 [`_bangumiInfoboxList`](#bangumiinfoboxlist) 处理。

### `static List<String> _bangumiInfoboxList(List<dynamic>? infobox, String key)` <a id="bangumiinfoboxlist"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 630 行）
- **用途：** 把一条 `infobox` 记录读为字符串列表。
- **返回：** `List<String>` —— 键不存在时返回空列表。
- **副作用：** 无。
- **算法：** 纯字符串值变成单元素列表；列表值展平为其 `{v: ...}` 条目，并丢弃空白项。
- **备注：** 同时接受两种形态很重要，因为同一个键会因条目而异——`动画制作` 通常是纯字符串而 `别名` 通常是列表，但编辑者可以随意填成任一种。

### `static int? parseBangumiWeekday(String? value)` <a id="parsebangumiweekday"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 663 行）
- **用途：** 把 bangumi.tv 的 `放送星期` 文本解析到周一=1..周日=7。
- **输入：** `value` —— 如 `星期五`、`週六`、`金曜日`。
- **返回：** `int?` —— 没有匹配到可识别形式时返回 `null`。
- **副作用：** 无。
- **算法：** 从周一到周日逐个检查，用该日的中文数字与日文词干去匹配 `星期X` / `週X` / `周X` / `X曜` 各种形式；周日额外接受 `日` 与 `天`。
- **备注：** v0 API 把放送日表述为**自由文本**，而不是旧版 `air_weekday` 字段那样的数字，并且条目会因编辑者不同而呈简体、繁体或日文。无法识别的值（`不定期`、空白）会变成「无数据」而非猜测，因为错误的星期会静默地把每一集的排期都算错。

### `static DateTime? _parseCjkDate(String? value)` <a id="parsecjkdate"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 693 行）
- **用途：** 解析 `2023年9月29日` 这类中日文日期。
- **返回：** `DateTime?` —— 文本中没有此类日期时返回 `null`。
- **副作用：** 无。
- **备注：** 之所以需要它，是因为 `infobox` 中的日期是自然语言，不同于条目自身的 ISO `date` 字段。

### `static Future<List<AnimeSearchResult>> _searchMAL(String query)` <a id="searchmal"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 712 行）
- **用途：** 经公开的 Jikan v4 API 查询 MyAnimeList，并映射最多 `_maxPerSource` 条命中。
- **返回：** `Future<List<AnimeSearchResult>>` —— 非 200 响应或缺少 `data` 时返回 `[]`。
- **副作用：** 向 `api.jikan.moe` 发起一次 HTTP GET（10 秒超时）。
- **算法：** GET `https://api.jikan.moe/v4/anime?q=<urlencoded query>&limit=10`，再把每一项交给 [`mapJikanAnime`](#mapjikananime)。
- **备注：** Jikan 索引所有语言的标题，因此它收到的是原始查询而非某种字形专属的变体。

### `static Future<AnimeSearchResult?> _fetchMalById(int id)` <a id="fetchmalbyid"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 741 行）
- **用途：** 经 Jikan 按数字 id 抓取一个 MyAnimeList 条目。
- **返回：** `Future<AnimeSearchResult?>` —— 非 200 响应或 `data` 不是 map 时返回 `null`。
- **副作用：** 向 `api.jikan.moe` 发起一次 HTTP GET（10 秒超时）。
- **备注：** `/full` 变体返回与搜索相同的对象形态，只是多了本应用不使用的关联信息，因此 `mapJikanAnime` 无需改动即可处理两者。

### `static AnimeSearchResult mapJikanAnime(Map<String, dynamic> m)` <a id="mapjikananime"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 764 行）
- **用途：** 把一个 Jikan 番剧对象映射为 `AnimeSearchResult`。
- **返回：** `AnimeSearchResult`。
- **副作用：** 无。
- **算法：**
  1. 从 `images.jpg` 读封面，经 `DateTime.tryParse` 读 `aired.from`/`aired.to`。
  2. 从 `broadcast` 中经 [`parseDayOfWeek`](#parsedayofweek) 解析 `day`；**仅当** `timezone` 缺失或为 `Asia/Tokyo` 时才采用 `time`。
  3. 遍历 `titles` 数组，把 `Default` → `titleRomaji`、`English` → `titleEn`、`Japanese` → `titleJa`，其余归入 `synonyms`；数组未填满的槽位再回退到扁平的 `title`/`title_english`/`title_japanese` 字段。
  4. 读取 `episodes`、`type` → `format`、`status`、经 [`parseJikanDuration`](#parsejikanduration) 的 `duration`、经 [`_namedList`](#namedlist) 的 `studios`/`genres`，以及 `score`/`scored_by`/`rank`。
- **备注：** 时区判断是关键。Jikan 按 `broadcast.timezone` 所指的时区报告 `broadcast.time`；把非东京时间存为 `Anime.airTime` 会把它标成日本时间，从而让每一集都发生偏移。丢弃它只是让该字段留空，界面能够处理。

### `static int? parseJikanDuration(String? duration)` <a id="parsejikanduration"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 867 行）
- **用途：** 把 Jikan 的自然语言时长字符串解析为分钟数。
- **输入：** `duration` —— 如 `"24 min per ep"`、`"1 hr 35 min"`、`"Unknown"`。
- **返回：** `int?` —— 没有可解析内容或总数为零时返回 `null`。
- **副作用：** 无。
- **算法：** 分别匹配 `(\d+)\s*hr` 与 `(\d+)\s*min`，求 `h * 60 + m`；两者都未匹配时返回 `null`。
- **备注：** Jikan 把时长报告为自然语言而非数字，因此必须分别提取小时与分钟，而不能当成一个数值解析。

### `static List<String> _namedList(Object? value)` <a id="namedlist"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 883 行）
- **用途：** 把 Jikan 的 `[{name: ...}]` 数组读成字符串列表。
- **返回：** `List<String>` —— 非列表或条目没有字符串 `name` 时返回空列表。
- **副作用：** 无。
- **备注：** Jikan 对 `studios` 与 `genres` 采用相同包装，因此一个辅助函数即可覆盖两者。

### `static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query)` <a id="searchacgsecrets"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 901 行）
- **用途：** 抓取 `acgsecrets.hk` 的季度番剧列表（内嵌为 `application/ld+json` 脚本块），对照查询做模糊匹配，先试当前季度、再回退到上一季度。
- **输入：** `query` —— 实践中是繁体变体。
- **返回：** `Future<List<AnimeSearchResult>>` —— 最多 `_maxPerSource` 条，按模糊匹配分降序。
- **副作用：** 向 `acgsecrets.hk` 发起最多两次 HTTP GET（各 15 秒超时）。
- **算法：**
  1. 从 [`_recentSeasons`](#recentseasons) 取 `[当前季度, 上一季度]`；计算繁体与简体变体。
  2. 逐季度：GET 季度页面，非 200 则跳过。提取每个 `<script type="application/ld+json">` 块并 JSON 解码，对每个 `itemListElement` 计算其 `name`/`alternateName` 与各查询变体的最佳 [`_similarity`](#similarity)；低于 `0.3` 的跳过；已见过的 `url` 跳过。
  3. 构建结果时，`startDate` 经 `DateTime.tryParse` 解析，有 `numberOfEpisodes` 则读入，第一个含假名的 `alternateName` 作为 `titleJa`，**其余全部别名进入 `synonyms`**。
  4. 当前季度已有结果时，不再尝试上一季度。
  5. 按分数降序排序并返回前 `_maxPerSource` 条。
- **备注：** 任何单个 `<script>` 块的 JSON 解码失败都被逐块捕获，因此一个损坏的块不会中断整季度的解析。保留全部别名（而非 1.4.0 之前只保留日文那一个）正是让这个来源能贡献跨语言补搜标题的原因。

### `static List<String> _recentSeasons()` <a id="recentseasons"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 987 行）
- **用途：** 计算 `acgsecrets.hk` 的「本季度」与「上一季度」代码（`YYYYMM`），最新在前。
- **返回：** 恰好 2 个季度代码的 `List<String>`。
- **副作用：** 无。
- **算法：** 用 `[1, 4, 7, 10].lastWhere((s) => m >= s)` 求当前季度起始月；上一季度减三个月，1 月时回绕到 `year - 1, 10`。

### `static bool _containsJapanese(String s)` <a id="containsjapanese"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1009 行）
- **用途：** 检测字符串是否包含任何平假名或片假名字符。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 遍历 `s.runes`，遇到第一个落在 `0x3040..0x309F`（平假名）或 `0x30A0..0x30FF`（片假名）的码点即返回 `true`。
- **备注：** 纯汉字字符串**不会**被判定为日文——单看汉字无法区分日文标题与中文标题。这一局限正是 [`_isLikelyChinese`](#islikelychinese) 作为其补集存在的原因。

### `static bool _isLatinScript(String s)` <a id="islatinscript"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1026 行）
- **用途：** 检查字符串是否为拉丁字母书写。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 当字符串至少含一个 ASCII 字母、且不含假名（`0x3040..0x30FF`）或 CJK 表意文字（`0x4E00..0x9FFF`）时为真。
- **备注：** 之所以需要它，是因为 bangumi.tv 没有罗马音/英文*字段*——它把两者都归在 `别名` 下，因此用于补搜的拉丁标题必须按字形识别，而不能按它来自哪个字段。没有这一步，只有 bangumi 命中的中文查询就收集不到拉丁标题，第二轮也就无法触达 MyAnimeList 与 AniList。

### `static bool _isLikelyChinese(String s)` <a id="islikelychinese"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1046 行）
- **用途：** 检查字符串读起来是中文而非日文。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** [`_containsJapanese`](#containsjapanese) 为真则返回 `false`；否则任一码点落在 CJK 统一表意文字区（`0x4E00..0x9FFF`）即返回 `true`。
- **备注：** 这是「该标题可以安全发给中文来源」的实用判据。假名的存在是唯一可靠的否定信号，因此该检查刻意采用「有汉字、无假名」的形式，而不试图做真正的语言识别。

### `static Future<List<AnimeSearchResult>> _searchFilmarks(String query)` <a id="searchfilmarks"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1063 行）
- **用途：** 抓取 `filmarks.com` 番剧搜索结果页的标题/封面/URL，主模式无果时使用更宽松的回退模式。
- **输入：** `query` —— 在第二轮中是收集到的日文标题。
- **返回：** `Future<List<AnimeSearchResult>>` —— 最多 `_maxPerSource` 条。
- **副作用：** 向 `filmarks.com` 发起一次 HTTP GET（10 秒超时，`Accept-Language: ja`）。
- **算法：** GET `https://filmarks.com/search/animes?q=<urlencoded query>`；通过被转义的点击处理器 `onClickDetailLink($event, &#39;/animes/<series>/<season>&#39;)` 匹配每个结果「内容卡片」，再从其后 3000 字符内的海报 `<img alt="…" src="…">` 中取标题与封面。结果按路径去重。若无所获，回退到匹配带邻近海报 `alt` 的普通 `<a href="/animes/<series>/<season>">` 锚点。
- **备注：** **这些模式在 1.4.0 中被重写。** filmarks 把详情 URL 从 `/anime/<id>` 改成了 `/animes/<series>/<season>`，并改为通过客户端组件渲染结果，因此自 v0.1.0 沿用至今的旧 `/anime/` 模式什么都匹配不到，该来源一直在贡献零结果且任何地方都不会报错。标题现在取自海报的 `alt` 属性，因为可见标题已不再位于 `class="...title..."` 元素中。两种模式都抓不到集数、播出日期或排期——filmarks 结果只会填充 `titleJa`/`sourceUrl`/`coverImageUrl`。由于它只索引日文标题，这是从第二轮补搜中获益最大的来源：中文或英文查询只有在其他来源提供了日文标题之后才能触达它。基于 HTML 结构的抓取天然对站点标记变更脆弱，而这已是第二次因此出问题——filmarks 忽然返回零结果时，应先当作标记变更而非真的没匹配到。

### `static Future<List<AnimeSearchResult>> _searchAniList(String query)` <a id="searchanilist"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1155 行）
- **用途：** 查询 AniList GraphQL API，取最多 `_maxPerSource` 条匹配的 media 条目。
- **返回：** `Future<List<AnimeSearchResult>>` —— 非 200 响应或缺少 `data.Page.media` 时返回 `[]`。
- **副作用：** 向 `graphql.anilist.co` 发起一次 HTTP POST（10 秒超时）。
- **算法：** 把 `_aniListMediaFields` 插入 `Page(perPage: 10) { media(search:, type: ANIME, sort: SEARCH_MATCH) }` 文档，经 [`_postAniList`](#postanilist) 发出，再把每个条目交给 [`mapAniListMedia`](#mapanilistmedia)。
- **备注：** `_aniListMediaFields` 是唯一共享的 const 字段选择集，因此搜索路径与按 id 路径绝不会请求不同的字段。

### `static Future<AnimeSearchResult?> _fetchAniListById(int id)` <a id="fetchanilistbyid"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1180 行）
- **用途：** 按数字 id 抓取一个 AniList media 条目。
- **返回：** `Future<AnimeSearchResult?>` —— id 未知或响应不是 map 时返回 `null`。
- **副作用：** 向 `graphql.anilist.co` 发起一次 HTTP POST（10 秒超时）。

### `static Future<Map<String, dynamic>?> _postAniList(String document, Map<String, dynamic> variables)` <a id="postanilist"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1199 行）
- **用途：** 向 AniList POST 一个 GraphQL 文档并返回其 `data` 对象。
- **返回：** `Future<Map<String, dynamic>?>` —— 非 200 响应时返回 `null`。
- **副作用：** 向 `graphql.anilist.co` 发起一次 HTTP POST（10 秒超时）。
- **备注：** 抽出来是为了让搜索查询与按 id 查询共享传输、请求头与错误处理。

### `static AnimeSearchResult mapAniListMedia(Map<String, dynamic> m)` <a id="mapanilistmedia"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1230 行）
- **用途：** 把一个 AniList media 对象映射为 `AnimeSearchResult`。
- **返回：** `AnimeSearchResult`。
- **副作用：** 无。
- **算法：**
  1. 经 [`_aniListDate`](#anilistdate) 构建 `firstAirDate`/`endDate`（三部分缺一不可）。
  2. 从 [`_aniListFirstAiringAt`](#anilistfirstairingat) 取放送时间戳。有值时把 Unix 秒转换为日本时间（`fromMillisecondsSinceEpoch(..., isUtc: true) + 9h`），取其 `.weekday` 与补零的 `HH:mm`。只有在没有时间戳时，`airDayOfWeek` 才回退到 `firstAirDate.weekday`。
  3. 清理 `description` 中的 HTML（`<br>` → 换行，去掉其余标签，反转义 `&amp;`/`&lt;`/`&gt;`/`&quot;`/`&#39;`）。
  4. 展平 `studios.nodes[].name`；读取 `synonyms`、`episodes`、`duration`、`format`、`status`、`genres`、`popularity` 与 `averageScore`。
  5. `title` 优先 `title.english`、其次 `title.romaji`；`titleJa` 取 `title.native`；同时单独保留罗马音与英文标题。
- **备注：** 有两个决定很重要。其一，基于排期表推导的星期取代了 1.4.0 之前一律用 `startDate.weekday` 猜测的做法——首播若不在常规时段，旧做法就是错的。其二，JST 时刻会经过 [`_jstBroadcastSlot`](#jstbroadcastslot)，因此深夜放送会以 `25:00` 形式归入前一天，并经 [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot) 把 `firstAirDate` 同步平移。只挪星期而不挪日期会让两者互相矛盾，`getEpisodeCalendarDate()` 的向前对齐反而会把第 1 集推迟一周。`averageScore` 是 0–100，进入时除以 10。

### `static DateTime? _aniListDate(Object? value)` <a id="anilistdate"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1312 行）
- **用途：** 从 AniList 的 `{year, month, day}` 对象构建 `DateTime`。
- **返回：** `DateTime?` —— 三部分不全为 `int` 时返回 `null`。
- **副作用：** 无。
- **备注：** AniList 对未公布的日期会把部分字段留空，而残缺日期无法用于排期，因此半已知日期被当作完全没有日期，而不是默认成 1 月 1 日。

### `static int? _aniListFirstAiringAt(Map<String, dynamic> m)` <a id="anilistfirstairingat"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1328 行）
- **用途：** 挑出最能代表放送时段的放送时间戳。
- **返回：** `int?` —— 以秒为单位的 Unix 时间戳，无排期时返回 `null`。
- **副作用：** 无。
- **算法：** 优先 `nextAiringEpisode.airingAt`；否则返回第一条 `airingAt` 为 `int` 的 `airingSchedule.nodes[]` 记录。
- **备注：** 优先 `nextAiringEpisode` 意味着正在放送的作品报告的是其*实时*时段，而这正是排下一集时真正相关的那个。作为回退的 `airingSchedule` 查询**不带** `notYetAired`（与 1.4.0 之前的文档不同），因此已完结作品也能拿到真实时段，而不是一个空的节点列表。

### `static ({int weekday, String time, int dayShift}) _jstBroadcastSlot(int weekday, int hour, int minute)` <a id="jstbroadcastslot"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1366 行）
- **用途：** 把日本时间的放送时刻映射到它所归属的编成时段。
- **输入：** `weekday`（1..7）、`hour`、`minute` —— 均为日本时间。
- **返回：** 一个记录，含该时段的 `weekday`、`time`（`HH:mm`，深夜档小时数 ≥ 24），以及 `dayShift` —— 该时段的日历日比钟表日早几天。
- **副作用：** 无。
- **算法：** 小时数低于 `_lateNightBoundaryHour`（04:00）时，星期回退一天（周一回绕到周日），并把小时报告为 `hour + 24`。04:00 及之后原样返回，`dayShift: 0`。
- **备注：** 日本编成惯例把 04:00 之前的一切都归入*前一晚*：周四 01:00 放送的作品就是「周三 25:00」，应当落在周三那一行。这一点之所以关键，是因为 [`Anime.getEpisodeCalendarDate`](../models/anime.md#getepisodecalendardate) **完全不读 `airTime`**，只用 `firstAirDate` + `airDayOfWeek` 定位某一集——若报告原始的钟表星期，每一集深夜番都会比它所属的编成日晚一天。调用方还必须把 `dayShift` 交给 [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot)；只挪星期会让两个字段互相矛盾，向前对齐反而把第 1 集整整推迟一周。

### `static DateTime? _alignFirstAirDateToSlot(DateTime? airDate, ({int weekday, String time, int dayShift}) slot, int clockWeekday)` <a id="alignfirstairdatetoslot"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1393 行）
- **用途：** 把首播日期平移到深夜时段所属的日历日。
- **输入：** `airDate`；来自 [`_jstBroadcastSlot`](#jstbroadcastslot) 的 `slot`；`clockWeekday` —— 未平移的钟表星期。
- **返回：** `DateTime?` —— 无需平移时原样返回。
- **副作用：** 无。
- **算法：** 当 `airDate` 为 null、`slot.dayShift` 为零，**或 `airDate.weekday` 与 `clockWeekday` 不一致**时原样返回；否则减去 `dayShift` 天。
- **备注：** 那个星期判断正是本函数可以无条件调用的原因。它只在来源自身的首播日期落在钟表日时才平移——AniList（`startDate`）与 MyAnimeList（`aired.from`）都是这样记录的。已经按编成日记录的来源，其星期与*平移后*的时段一致，因此会被原样保留，不会被二次平移。

### `static double? _toDouble(Object? value)` <a id="todouble"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1409 行）
- **用途：** 把 JSON 数字强制转换为 `double`。
- **返回：** `double?` —— 非 `num` 时返回 `null`。
- **副作用：** 无。
- **备注：** 各来源根据端点不同，会把评分报告为整数或小数。

### `static int? parseDayOfWeek(String day)` <a id="parsedayofweek"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** `lib/features/anime/services/anime_search_service.dart`（第 1421 行）
- **用途：** 把英文星期名（如 Jikan `broadcast.day` 返回的 `"Mondays"`）解析为 `Anime.airDayOfWeek` 的 `1..7`（周一..周日）编号。
- **返回：** `int?` —— 没有匹配到已知星期前缀时返回 `null`。
- **副作用：** 无。
- **算法：** 把 `day` 转小写后依次检查三字母前缀（`mon`→1 … `sun`→7）。
- **备注：** 用 `startsWith` 匹配，因此 `"Monday"` 与 `"Mondays"` 都能识别。

### `static Future<List<String>> harvestAliases(String query)` <a id="harvestaliases"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** `lib/features/anime/services/anime_search_service.dart`（约第 549 行）
- **用途：** 为 anime1.me 查找从 bangumi.tv 获取一个查询的别名。
- **输入：** `query`——任何语言；以简体形式发送。
- **返回：** `Future<List<String>>`——可信命中的中文与拉丁字母标题，已去重；无命中时为空。
- **副作用：** 向 `api.bgm.tv` 发起一次 HTTP POST。
- **算法：** `_searchBangumi(toSimplified(query))`，然后以 `queryVariants(query)` 调用 [`aliasCandidatesFrom`](#aliascandidatesfrom)。
- **用法：**
  ```dart
  aliases = await AnimeSearchService.harvestAliases(query);
  ```
  （`anime1_service.dart`，`search`，在没有索引行达到可信分数时）
- **备注：** 大陆译名与台译可能一个字都不共享（间谍过家家 / 間諜家家酒），而 bangumi.tv 的别名字段通常两者都列。

### `static List<String> aliasCandidatesFrom(List<AnimeSearchResult> hits, List<String> variants)` <a id="aliascandidatesfrom"></a>
- **种类：** `AnimeSearchService` 的静态方法，`@visibleForTesting`
- **来源：** 约第 565 行
- **用途：** 从与查询匹配良好的搜索命中中挑出别名字符串。
- **返回：** `List<String>`，至多六个，按命中顺序。
- **副作用：** 无。
- **算法：** 对每个 [`relevance`](#relevance) 不低于 `_backfillMinRelevance`（0.45）的命中，保留其 `allTitles` 中每个中文（汉字、无假名）或拉丁字母的条目，去重。
- **备注：** 日文标题无法匹配 anime1 的中文索引；罗马音标题可以，因为站点保留拉丁字母的系列名（`SPY×FAMILY`、`GRAND BLUE`）。

### `static double bestSimilarity(String title, List<String> queries)` <a id="bestsimilarity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1697 行
- **用途：** 计算一个候选标题对一组查询变体的最佳模糊相似度得分。
- **返回：** `0.0..1.0` 的 `double`。
- **副作用：** 无。
- **算法：** 对 `queries` 的每一项运行 [`_similarity`](#similarity)，取最大值。
- **备注：** 支撑公开的 [`relevance`](#relevance) 与 anime1 的抓取回退；anime1 的索引路径改为经 [`similarityRaw`](#similarityraw) 给预先归一化的字符串打分。

### `static double _similarity(String a, String b)` <a id="similarity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1719 行
- **用途：** 两个标题的模糊相似度，对字形与标点不敏感。
- **返回：** `0.0..1.0` 的 `double`；任一输入为空时为 `0`。
- **副作用：** 无。
- **算法：** 取 [`similarityRaw`](#similarityraw) 在原始字符串上与在它们的 [`foldTitle`](#foldtitle) 形式上两者中较好的一个。
- **备注：** 1.5.6 之前第二遍按繁体归一化，那是一对多的方向（干 → 幹 或 乾），恰恰漏掉了它本该抓住的组合；简体才是多对一的方向。改动只会抬高分数，因此其他地方基于 `relevance` 的阈值不受影响。

### `static double similarityRaw(String a, String b)` <a id="similarityraw"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1738 行
- **用途：** 在字符串原样上运行的三项相似度核心。
- **返回：** `0.0..1.0` 的 `double`——经 [`_lcsLength`](#lcslength) 的 LCS-Dice、基于 `.runes.toSet()` 的顺序无关字符集 Dice、以及得分为 `0.7 + 0.3 * (较短 / 较长)` 的包含关系，三者取最佳。
- **副作用：** 无。
- **备注：** 公开是为了让 `Anime1Service.rank` 给预先归一化的字符串打分而不必逐对再归一化；其他所有调用方要的都是 [`_similarity`](#similarity)。

### `static double orderedSimilarity(String a, String b)` <a id="orderedsimilarity"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1764 行
- **用途：** 只看顺序的相似度——LCS-Dice 或包含关系。
- **返回：** `0.0..1.0` 的 `double`。
- **副作用：** 无。
- **备注：** [`similarityRaw`](#similarityraw) 里的字符集 Dice 项对顺序视而不见，在短拉丁串上让 `bocchitherock` 与 `tomjerry` 共享一半字母。`Anime1Service.rank` 同时要求这个分数过线，因此这样的组合永远不会被列出。

### `static String foldTitle(String s)` <a id="foldtitle"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1791 行
- **用途：** 把标题归一化用于匹配——绝不用于显示。
- **返回：** `String`——全角 ASCII 变半角（U+FF01–FF5E，U+3000 变空格）、转小写、去掉空白与 Unicode 标点/符号（`[\s\p{P}\p{S}]`），再转成简体。
- **副作用：** 无。
- **备注：** 规范侧是简体，因为繁转简是多对一（乾/幹 → 干，髮/發 → 发）。转换同样折叠日文汉字（滅 → 灭），所以 `鬼滅の刃` 能够到 `鬼滅之刃`。`SPY×FAMILY` 里的 `×` 这类符号在两侧都被去掉，因此永远不决定匹配。

### `static int _lcsLength(String a, String b)` <a id="lcslength"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1815 行
- **用途：** 计算两个字符串之间的最长公共子序列长度。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** 标准的 O(n·m) 动态规划，用两行滚动数组代替完整二维表。
- **备注：** O(n·m) 之所以可接受，正因为两个输入都是短的番剧标题而非任意长度的文本。

### `static String decodeHtmlEntities(String text)` <a id="decodehtmlentities"></a>
- **种类：** `AnimeSearchService` 的静态方法
- **来源：** 约第 1845 行
- **用途：** 解码从 `filmarks.com` 与 `anime1.me` 抓取的标题中出现的少量固定 HTML 实体。
- **返回：** `String`。
- **副作用：** 无。
- **备注：** 只处理六个实体——`&#39;` 之外的数字字符引用（如 `&#8217;`）会原样透传。自 1.5.7 起公开，因为 `anime1_service.dart` 用它解码索引标题与抓取到的链接。

### `double? AnimeSearchProgress.fraction` <a id="searchprogressfraction"></a>
- **种类：** `AnimeSearchProgress` 的 getter
- **用途：** 报告当前这一轮检索已有多少来源作出回应。
- **输入：** 无。
- **返回：** 0..1 之间的 `double?`；没有来源正在被查询时为 `null`。
- **副作用：** 无。
- **备注：** 每一轮使用**各自的分母**。第二轮只重新查询首轮空手而归的来源，因此若用单一总计，
  分母会在检索途中变大、把进度条往回推；取而代之的是：首轮填满一次，规模更小的第二轮再填一次，
  文案说明当前处于哪一轮。

  失败的来源计入 `done`，因为它已经不再是等待对象。失败仍然可以区分——它会出现在 `failed` 中
  ——因为对于正在决定要不要重搜的人来说，「这个来源坏了」和「这个来源没找到」是两个不同的答案。

  它之所以存在，是因为一次检索确实可能耗时约半分钟：每个来源各有 10–15 秒超时，而且可能跑两轮。
  在这段时间里，一个光秃秃的转圈与真正的卡死无法区分。
