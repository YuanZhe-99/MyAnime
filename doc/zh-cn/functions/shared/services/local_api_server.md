# lib/shared/services/local_api_server.dart

`LocalApiServer` 是 [../../platform-notes.md](../../../platform-notes.md) 和 [../../features/multi-source-search.md](../../../features/multi-source-search.md) 描述的纯桌面本地 HTTP API。它是基于 `shelf` 的服务器，默认禁用，在回环（或带凭据的局域网）上暴露对本地动画库的读/搜索访问。它没有网络客户端角色——它是应用为其他本地/局域网工具（如桌面 Web 仪表盘或脚本）运行以供调用的服务器。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_RankingQuery` 构造函数](#rankingquery-new) | 构造函数（私有值类） | A | 保存解析后的 `/anime/ranking` 查询选项。 |
| [`port`](#port) | 静态 getter | B | 配置的 API 服务器端口。 |
| [`listenAddress`](#listenaddress) | 静态 getter | B | 配置的 API 服务器监听地址。 |
| [`enabled`](#enabled) | 静态 getter | B | 保存的设置中 API 服务器是否启用。 |
| [`isRunning`](#isrunning) | 静态 getter | B | 服务器当前是否已绑定。 |
| [`lastError`](#lasterror) | 静态 getter | B | 上次启动/运行时错误码（如有）。 |
| [`loadConfig`](#loadconfig) | 静态方法 | A | 从 `storage_config.json` 加载 API 服务器设置。 |
| [`start`](#start) | 静态方法 | A | 按当前配置绑定并提供 API 服务器。 |
| [`stop`](#stop) | 静态方法 | A | 强制关闭运行中的服务器（如有）。 |
| [`restart`](#restart) | 静态方法 | A | 重载配置并重启服务器。 |
| `_handlePing` | 静态方法（路由处理器） | B | `GET /ping` 存活检查。 |
| [`_handleSearch`](#handlesearch) | 静态方法（路由处理器） | A | `POST /anime/search`：把查询代理给 `AnimeSearchService`。 |
| [`_handleAdd`](#handleadd) | 静态方法（路由处理器） | A | `POST /anime/add`：创建并持久化新动画。 |
| [`_handleList`](#handlelist) | 静态方法（路由处理器） | A | `GET /anime/list`：按季过滤的动画列表。 |
| [`_handleUnwatched`](#handleunwatched) | 静态方法（路由处理器） | A | `GET /anime/unwatched`：每部动画最早的一条未看已播出剧集。 |
| [`_handleHistory`](#handlehistory) | 静态方法（路由处理器） | A | `GET /anime/history`：按季过滤的动画列表（与 list 形态相同）。 |
| [`_handleRanking`](#handleranking) | 静态方法（路由处理器） | A | `GET /anime/ranking`：委托给 `buildRankingSnapshotForQuery`。 |
| [`buildRankingSnapshotForQuery`](#buildrankingsnapshotforquery) | 静态方法 | A | 纯排名计算，与测试共享。 |
| [`_filterBySeason`](#filterbyseason) | 静态方法 | A | 解析 `?season=` 并过滤/抽样动画列表。 |
| [`_parseRankingQuery`](#parserankingquery) | 静态方法 | A | 把所有 `/anime/ranking` 查询参数解析为 `_RankingQuery`。 |
| [`_parseQuarterId`](#parsequarterid) | 静态方法 | A | 解析 `YYYYQn` 标识符（或 `current`）。 |
| [`_parseAnimeTypeParam`](#parseanimetypeparam) | 静态方法 | A | 解析 `type` 过滤器参数。 |
| [`_parseRatingFieldParam`](#parseratingfieldparam) | 静态方法 | A | 解析 `field`（评分维度）参数。 |
| [`_matchesRankingQuery`](#matchesrankingquery) | 静态方法 | A | 测试一部动画是否匹配解析后的排名过滤器。 |
| [`_rankingFiltersToJson`](#rankingfilterstojson) | 静态方法 | A | 把解析后的过滤器序列化回响应 JSON。 |
| [`_quarterIndex`](#quarterindex) | 静态方法 | A | 把 (year, quarter) 编码为一个可排序整数。 |
| [`_quarterFromIndex`](#quarterfromindex) | 静态方法 | A | 把可排序整数解码回 (year, quarter)。 |
| [`_quarterId`](#quarterid) | 静态方法 | A | 把 (year, quarter) 格式化为 `"YYYYQn"`。 |
| [`_animeToJson`](#animetojson) | 静态方法 | A | 序列化一个 `Anime` 供 API 响应。 |
| [`_episodeStatusCount`](#episodestatuscount) | 静态方法 | A | 统计给定 `EpisodeStatus` 的剧集数。 |
| [`_episodeScanEnd`](#episodescanend) | 静态方法 | A | 确定值得扫描的最后一个集编号。 |
| [`_airedEpisodeCount`](#airedepisodecount) | 静态方法 | A | 统计已播出剧集数（感知 JST）。 |
| [`_airedUnwatchedEpisodeCount`](#airedunwatchedepisodecount) | 静态方法 | A | 统计已播出但未看剧集数（感知 JST）。 |
| [`_ratingToJson`](#ratingtojson) | 静态方法 | A | 序列化 `AnimeRating` 供 API 响应。 |
| [`_computeCounts`](#computecounts) | 静态方法 | A | 派生逐状态计数，带旧键别名。 |
| `_json` | 静态方法 | B | 把值包装为 `200 application/json` `Response`。 |
| [`_jstToUtcString`](#jsttoutcstring) | 静态方法 | A | 把 JST 朴素 `DateTime` 转换为 UTC ISO 字符串。 |
| `_error` | 静态方法 | B | 为给定状态构建 JSON 错误 `Response`。 |
| [`_parseBody`](#parsebody) | 静态方法 | A | 把请求体解析为 JSON，容忍格式错误的输入。 |
| [`_corsMiddleware`](#corsmiddleware) | 静态方法 | A | 为每个响应提供的宽松 CORS 中间件。 |
| [`_authMiddleware`](#authmiddleware) | 静态方法 | A | 强制 Basic Auth / 仅回环访问规则。 |
| [`_validateBasicAuth`](#validatebasicauth) | 静态方法 | A | 对照配置的凭据校验 `Authorization: Basic` 头。 |
| [`_errorMiddleware`](#errormiddleware) | 静态方法 | A | 把未处理的处理器异常捕获为 `500` JSON 错误。 |

## 文档

### `const _RankingQuery({...})` <a id="rankingquery-new"></a>
- **种类：** 私有值类 `_RankingQuery` 的构造函数。
- **来源：** `lib/shared/services/local_api_server.dart`（第 34 行）。
- **用途：** 保存 `/anime/ranking` 查询字符串的完整解析、类型化形式（时间范围、可选年/季或年/季范围、类型过滤器、排序字段、排序方向、结果限制）。
- **输入：** `time`（必填 `_ApiRankingTime`）、可选 `year`/`quarter`/`startYear`/`startQuarter`/`endYear`/`endQuarter`、可选 `type`（`AnimeType?`）、必填 `field`（`AnimeRatingField`）、必填 `descending`（`bool`）、必填 `limit`（`int`）。
- **返回：** 新的不可变 `_RankingQuery`。
- **副作用：** 无。
- **算法：** 平凡字段赋值；所有校验在构造前的 `_parseRankingQuery` 中完成。
- **用法：** 只在所有查询参数校验后于 `_parseRankingQuery` 内部构建；被 `_matchesRankingQuery`、`_rankingFiltersToJson` 和 `buildRankingSnapshotForQuery` 消费。
- **备注：** 本文件私有——它只是排名端点的内部已解析请求类型，不是公共模型。

### `static Future<void> loadConfig()` <a id="loadconfig"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 98 行）。
- **用途：** 从 `storage_config.json` 把 API 服务器的持久化设置（`apiPort`、`apiListenAddress`、`apiEnabled`、`apiUsername`、`apiPassword`）读入类的静态字段。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `AnimeStorage.readConfig()` 读取 `storage_config.json`；修改静态 `_port`/`_listenAddress`/`_enabled`/`_username`/`_password` 字段。
- **算法：** 读取配置映射；键缺失时应用默认值 `apiPort ?? 7788`、`apiListenAddress ?? 'localhost'`、`apiEnabled ?? false`。
- **用法：** 由 `start()` 和 `restart()` 在（重新）绑定前调用，以及设置 UI 显示当前服务器配置时。
- **备注：** 凭据原样读取（按应用文档化的安全姿态，明文存于 `storage_config.json`）；本方法不校验其强度。

### `static Future<void> start()` <a id="start"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 112 行）。
- **用途：** 按当前设置绑定并启动本地 API HTTP 服务器，功能禁用时什么都不做。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 网络：在配置端口上绑定监听 socket（回环、`0.0.0.0` 或特定地址）；设置 `_server` 和 `_lastError`；向 stdout 记录。
- **算法：**
  1. `loadConfig()`，然后 `stop()` 任何先前运行的实例，清除 `_lastError`。
  2. `!_enabled` 时不绑定任何东西地返回。
  3. 确定 `isNonLoopback`（监听地址是 `0.0.0.0`，或既非 `localhost` 也非 `127.0.0.1`）和 `hasCredentials`（用户名和密码都非空）。非回环且未配置凭据时，设 `_lastError = 'credentials_required'` 并拒绝启动——这是 [../../platform-notes.md](../../../platform-notes.md) 描述的安全规则：未带凭据的不安全非 localhost 启动被直接拒绝。
  4. 构建带路由 `GET /ping`、`POST /anime/search`、`POST /anime/add`、`GET /anime/list`、`GET /anime/unwatched`、`GET /anime/history`、`GET /anime/ranking` 的 `shelf_router.Router`。
  5. 把路由器包进按顺序 `_corsMiddleware()`、`_authMiddleware()`、`_errorMiddleware()` 的 `Pipeline`。
  6. 解析绑定地址（`0.0.0.0` 用 `InternetAddress.anyIPv4`、`localhost`/`127.0.0.1` 用 `InternetAddress.loopbackIPv4`、否则字面 `InternetAddress`）并调用 `shelf_io.serve`。
  7. 任何绑定失败时，把 `e.toString()` 捕获进 `_lastError` 而不是抛出。
- **用法：** 用户启用 API 服务器或更改其配置时从桌面设置 UI 调用，应用启动时若服务器被留下为启用也调用。
- **备注：** 中间件顺序重要：CORS 头必须即使对被拒绝的认证响应也适用，因此 `_corsMiddleware` 包在 `_authMiddleware` 外面。

### `static Future<void> stop()` <a id="stop"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 175 行）。
- **用途：** 强制关闭运行中的服务器（如存在）。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 关闭绑定 socket（`force: true`，丢弃在途连接）；把 `_server` 设为 `null`。
- **算法：** `await _server?.close(force: true); _server = null;`——没有运行时空操作。
- **用法：** 在 `start()` 开头调用（避免双重绑定），以及用户禁用 API 服务器时由设置 UI 调用。
- **备注：** `force: true` 意味着在途请求被丢弃而不是排空；没有优雅关闭路径。

### `static Future<void> restart()` <a id="restart"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 185 行）。
- **用途：** 重载设置并重新绑定服务器，如用户更改端口/地址/凭据后。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 与 `loadConfig()` + `start()` 组合相同。
- **算法：** `await loadConfig(); await start();`（`start()` 自己先调用 `stop()`）。
- **用法：** 由设置 UI 的 API 服务器小节"保存"操作调用。
- **备注：** 无。

### `static Future<Response> _handleSearch(Request request)` <a id="handlesearch"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 206 行）。
- **用途：** 实现 `POST /anime/search`：通过多源搜索引擎运行查询并返回最多 5 条结果。
- **输入：** `request` — JSON 正文必须含非空 `query` 字符串。
- **返回：** `Future<Response>` — 正文缺失/无效或 `query` 为空/空白时 `400`；否则 `200` 带 JSON 结果对象数组。
- **副作用：** 经 `AnimeSearchService.searchAll()` 执行出站 HTTP 请求（见 [../../features/multi-source-search.md](../../../features/multi-source-search.md)）。
- **算法：** 解析并校验正文，调用 `AnimeSearchService.searchAll(query.trim())`，取前 5 条结果，把每条映射为平铺 JSON 对象（`source`、`sourceUrl`、`title`、`titleJa`、`episodes`、`firstAirDate`、`airDayOfWeek`、`airTime`、`coverImageUrl`、`summary`）。
- **用法：** 任何命中 `POST /anime/search` 的本地/局域网 HTTP 客户端调用；这是桌面 API 表面唯一的搜索入口（与应用内搜索对话框不同，后者直接调用 `AnimeSearchService`）。
- **备注：** 因为 `AnimeSearchService` 本身不做风味门控，这里是纯桌面服务意味着在线搜索的 store 风味限制不适用——API 服务器是 `full` 风味桌面功能，按本仓库的 `AGENTS.md`。

### `static Future<Response> _handleAdd(Request request)` <a id="handleadd"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 239 行）。
- **用途：** 实现 `POST /anime/add`：从最小 JSON 负载创建新动画记录并持久化。
- **输入：** `request` — 带 `title` 和/或 `titleJa`（至少一个必填）的 JSON 正文，可选 `episodes`、`firstAirDate`（ISO 字符串）、`airDayOfWeek`、`airTime`、`sourceUrl`。
- **返回：** `Future<Response>` — 正文无效或标题缺失时 `400`；否则 `200` 带 `{success: true, id, title}`。
- **副作用：** 经 `AnimeStorage.addOrUpdate()` 持久化新动画。
- **算法：** 解析正文；要求 `title`/`titleJa` 至少一个；用 `DateTime.tryParse` 解析 `firstAirDate`；经 `Anime.create(...)` 构造（把 `episodes` 映射到 `endEpisode`、`sourceUrl` 映射到 `infoUrl`）；保存；用新动画的 id 和显示标题响应。
- **用法：** 想要以编程方式添加动画的外部工具（如响应 RSS 源的脚本或配套应用）调用，绕过应用内新增/搜索 UI。
- **备注：** 这是 API 中唯一的变更端点；其他每个路由都是只读的。

### `static Future<Response> _handleList(Request request)` <a id="handlelist"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 275 行）。
- **用途：** 实现 `GET /anime/list`：返回带 total/status 计数的按季过滤动画。
- **输入：** `request` — 可选 `?season=` 查询参数（见 `_filterBySeason`）。
- **返回：** `Future<Response>` — `200` 带 `{total, counts, data}`，`season=all` 时 `data` 可能是随机 40 项样本。
- **副作用：** 经 `AnimeStorage.load()` 读取动画存储。
- **算法：** 加载所有动画；计算 `allFiltered`（未抽样）供准确的 `total`/`counts`；计算 `sampled`（`season=all` 下可能上限 40）供 `data` 数组；用 `_animeToJson` 序列化每个。
- **用法：** 想要完整或按季动画目录的任何本地/局域网客户端（如配套仪表盘）调用。
- **备注：** 即使 `data` 被抽样，`total`/`counts` 总是反映完整过滤集，因此计数绝不会谎报底层资料库大小。

### `static Future<Response> _handleUnwatched(Request request)` <a id="handleunwatched"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 291 行）。
- **用途：** 实现 `GET /anime/unwatched`：列出每部动画最早一条已播出（JST）的未看剧集，按最早优先排序。
- **输入：** `request`（不消费查询参数）。
- **返回：** `Future<Response>` — `200` 带 JSON 数组；每个条目是 `_animeToJson(anime)` 加 `nextUnwatchedEpisode` 和 `episodeAirDate`（UTC 字符串）。
- **副作用：** 读取动画存储；调用 `JstTime.now()`。
- **算法：** 对每部动画，从 `startEpisode` 到 `_episodeScanEnd(anime)` 扫描剧集；停在第一条播出日期不晚于现在的 `unwatched` 剧集，记录它并 `break`（每部动画只报告最早的未看剧集，不是每个未看剧集）。按 `episodeAirDate` 升序排序结果列表，null 日期排最后。
- **用法：** 想要"我接下来该看什么"信息流而不打开应用的外部工具调用。
- **备注：** 即使一部动画有很多已播出未看剧集，也最多贡献一行。

### `static Future<Response> _handleHistory(Request request)` <a id="handlehistory"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 327 行）。
- **用途：** 实现 `GET /anime/history`：按季过滤的动画列表，响应形态与 `/anime/list` 相同。
- **输入：** `request` — 可选 `?season=` 查询参数。
- **返回：** `Future<Response>` — `200` 带 `{total, counts, data}`。
- **副作用：** 读取动画存储。
- **算法：** 与 `_handleList` 实现相同（加载、按季过滤两次——未抽样供计数、抽样供数据——序列化）。它作为独立路由/名称存在，给想要语义上名为"history"、与"list"分开的端点的 API 消费者，尽管当前实现主体是同一个按季过滤/序列化流水线。
- **用法：** 与 `_handleList` 相同；作为独立文档化端点保留以保证 API 稳定。
- **备注：** 如果 `/anime/list` 和 `/anime/history` 将来要分化（如 history 默认 `season=all`），该分化不在当前实现中——两者目前都经 `_filterBySeason` 默认 `season=current`。

### `static Future<Response> _handleRanking(Request request)` <a id="handleranking"></a>
- **种类：** `LocalApiServer` 的静态方法（路由处理器）。
- **来源：** `lib/shared/services/local_api_server.dart`（第 343 行）。
- **用途：** 实现 `GET /anime/ranking`：`buildRankingSnapshotForQuery` 上的薄 HTTP 适配器。
- **输入：** `request` — 所有支持的查询参数见 `_parseRankingQuery`。
- **返回：** `Future<Response>` — 带解析/校验错误消息的 `400`，或带排名 JSON 的 `200`。
- **副作用：** 读取动画存储。
- **算法：** 加载动画数据，调用 `buildRankingSnapshotForQuery(data.animes, request.url.queryParameters)`，把其 `(data, error)` 记录转换为 HTTP 响应。
- **用法：** 想要经 HTTP 查看已评分动画排名视图的任何本地/局域网客户端调用。
- **备注：** 所有实际排名逻辑都在 `buildRankingSnapshotForQuery` 中，使它无需活 HTTP 服务器就能单元测试。

### `static ({Map<String, dynamic>? data, String? error}) buildRankingSnapshotForQuery(List<Anime> animes, Map<String, String> queryParameters)` <a id="buildrankingsnapshotforquery"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 361 行）。
- **用途：** 从内存动画列表和原始查询参数纯计算 `/anime/ranking` 响应体，从 HTTP 处理器中抽出使其可直接测试。
- **输入：** `animes` — 完整内存动画列表；`queryParameters` — 原始 HTTP 查询字符串映射。
- **返回：** 记录 `(data: Map<String, dynamic>?, error: String?)` — 两者恰好一个非 null。
- **副作用：** 无（对其输入的纯函数）。
- **算法：**
  1. `_parseRankingQuery(queryParameters)`；立即传播任何解析错误。
  2. 把 `animes` 过滤为匹配 `_matchesRankingQuery` **且**对请求的 `field` 有非 null 分数的（未评分动画完全从排名中排除）。
  3. 按分数排序（按 `query.descending` 降序或升序），平局按 `displayTitle` 打破以保稳定顺序。
  4. 取前 `query.limit` 条；把每行构建为 `{rank, score, ...anime JSON}`（1 基排名，展开 `_animeToJson`）。
  5. 组装最终映射：`total`（过滤后、限制前计数）、`filters`（`_rankingFiltersToJson`）、`sort`（`{field, order}`）、`limit`、`data`（排名行）。
- **用法：** 由 `_handleRanking` 调用；也意在由单元测试直接调用（按其自己的文档注释："由路由处理器和测试共享，使排名语义保持可验证"）。
- **备注：** `total` 反映匹配过滤器且有分数的动画数——它不是应用 `limit` 后的计数。

### `static List<Anime> _filterBySeason(List<Anime> animes, Request request, {bool sample = true})` <a id="filterbyseason"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 416 行）。
- **用途：** 解析 `?season=` 查询参数并按此过滤（可选抽样）动画列表。
- **输入：** `animes`；`request`（读取 `request.url.queryParameters['season']`）；`sample` — `season=all` 是否可返回随机子集（默认 `true`）。
- **返回：** `List<Anime>`。
- **副作用：** 无（`current` 情形读取 `JstTime.now()`，无修改）。
- **算法：** `season` 缺失时默认 `'current'`。
  - `'all'`：返回一切，除非 `sample` 为 true 且超过 40 部动画，此时洗牌取 40（`List<Anime>.from(animes)..shuffle(Random())`）。
  - `'unassigned'`：`firstAirDate == null` 的动画。
  - `'current'`：从 `JstTime.now()` 计算当前 JST 年/季并按 `airsInQuarter` 过滤。
  - `'YYYYQn'`（正则 `^(\d{4})Q([1-4])$`）：按那个显式季过滤。
  - 任何其他值：当作无效并**全部**动画不过滤地返回（失败开放，不是失败封闭）。
- **用法：** 由 `_handleList` 和 `_handleHistory` 调用（计数计算用 `sample: false`，返回的 `data` 数组用默认 `sample: true`）。
- **备注：** `all` 抽样行为意味着在超过 40 部动画的资料库上两次带 `season=all` 的调用可能为同一底层数据返回不同的 `data` 数组——那种情况下调用方应把 `data` 当作预览，不是稳定的完整转储。格式错误的 `season` 值静默回退为"all"，不是错误。

### `static ({_RankingQuery? query, String? error}) _parseRankingQuery(Map<String, String> queryParameters)` <a id="parserankingquery"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 456 行）。
- **用途：** 把每个 `/anime/ranking` 查询参数解析并校验为类型化的 `_RankingQuery`，或返回描述性错误。
- **输入：** `queryParameters` — 原始 HTTP 查询字符串映射。识别的键包括 `time`（`all`/`quarter`/`year`/`range`）、`season`（`time=quarter` 用）、`year`（`time=year` 用）、`start`/`end`（`time=range` 用，作为 `YYYYQn`）、`type`、`field`、`order`、`limit`。
- **返回：** 记录 `(query: _RankingQuery?, error: String?)`。
- **副作用：** 无。
- **算法：** 对照四个允许的字面值校验 `time`（空默认 `all`）；`quarter` 时经 `_parseQuarterId` 解析 `season`（默认 `current`）；`year` 时解析裸年字符串；`range` 时经 `_parseQuarterId` 解析 `start`/`end`；把 `type` 委托给 `_parseAnimeTypeParam`、`field` 委托给 `_parseRatingFieldParam`；解析 `order`（`desc`/`asc`，默认 desc）和 `limit`（正整数，带默认值和大概上限——精确默认/上限常量见源码）。任何解析失败用描述性 `error` 字符串和 null `query` 短路。
- **用法：** 由 `_parseRankingQuery` 的两个调用方调用：`_handleRanking`（经 `buildRankingSnapshotForQuery`）和任何测试排名查询解析的测试直接调用。
- **备注：** 这里返回的每个错误字符串都是 `_handleRanking` 原样浮出为 `400` 响应体的东西，因此其措辞是 API 稳定错误契约的一部分。

### `static (int, int)? _parseQuarterId(String? value, {bool allowCurrent})` <a id="parsequarterid"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 557 行）。
- **用途：** 把 `YYYYQn` 季标识符（可选接受字面 `current`）解析为 `(year, quarter)` 对。
- **输入：** `value`；`allowCurrent` — 字面字符串 `current` 是否应解析为今天的 JST 季。
- **返回：** `(int, int)?` — 任何解析失败为 `null`。
- **副作用：** 解析 `current` 时读取 `JstTime.now()`。
- **算法：** `allowCurrent` 且 `value == 'current'` 时，以 `_filterBySeason` 相同方式从 `JstTime.now()` 派生年/季；否则匹配 `^(\d{4})Q([1-4])$` 并解析两个捕获组。
- **用法：** `_parseRankingQuery` 对 `quarter` 时间范围（`season=`）和 `range` 时间范围（`start=`/`end=`）都调用。
- **备注：** 与 `_filterBySeason` 共享其季标识符格式和当前季派生，但是排名端点本地的一个独立实现。

### `static ({AnimeType? value, String? error}) _parseAnimeTypeParam(String? value)` <a id="parseanimetypeparam"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 577 行）。
- **用途：** 把 `type` 查询参数解析为可选 `AnimeType` 过滤器。
- **输入：** `value` — 原始查询字符串，预期匹配 `AnimeType` 枚举名，或 `all`/空表示"无过滤器"。
- **返回：** 记录 `(value: AnimeType?, error: String?)`。
- **副作用：** 无。
- **算法：** 空或 `all`（大小写处理按源码）映射为 `(value: null, error: null)`（无类型过滤器）；任何其他值对照 `AnimeType` 枚举名匹配，不识别则返回错误。
- **用法：** `_parseRankingQuery` 调用以填充 `_RankingQuery.type`。
- **备注：** 无。

### `static ({AnimeRatingField? value, String? error}) _parseRatingFieldParam(String? value)` <a id="parseratingfieldparam"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 595 行）。
- **用途：** 把 `field` 查询参数（按哪个评分维度排序/排名）解析为 `AnimeRatingField`。
- **输入：** `value` — 原始查询字符串；空默认总分字段。
- **返回：** 记录 `(value: AnimeRatingField?, error: String?)`。
- **副作用：** 无。
- **算法：** 空值默认"总分"字段；否则对照 `AnimeRatingField` 枚举名（visual/story/character/music/enjoyment/overall）匹配，不识别则返回错误。
- **用法：** `_parseRankingQuery` 调用以填充 `_RankingQuery.field`。
- **备注：** 无。

### `static bool _matchesRankingQuery(Anime anime, _RankingQuery query)` <a id="matchesrankingquery"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 611 行）。
- **用途：** 决定一部动画是否满足解析后的排名过滤器（类型 + 时间范围），与其是否有分数无关。
- **输入：** `anime`；`query`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `query.type` 已设置且不匹配 `anime.effectiveType` 时立即失败。然后按 `query.time` 分支：`all` 总是通过；`quarter` 检查 `airsInQuarter(year, quarter)`；`year` 经 `airsInQuarter` 检查当年全部 4 个季度；`range` 经 `_quarterFromIndex` 遍历 `_quarterIndex(start)` 与 `_quarterIndex(end)` 之间的每个季度索引（范围给反时交换），对每个检查 `airsInQuarter`。
- **用法：** 从 `buildRankingSnapshotForQuery` 的过滤步骤调用，并经 `range` 分支的逐季检查从自身内部传递调用。
- **备注：** 分数存在性检查（`anime.rating?.scoreFor(query.field) != null`）**不**是此函数的一部分——它由调用方单独应用，因此此函数单独回答"这部动画是否属于请求的时间/类型范围"，而不是"它是否可排名"。

### `static Map<String, dynamic> _rankingFiltersToJson(_RankingQuery query)` <a id="rankingfilterstojson"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 645 行）。
- **用途：** 把解析后的排名过滤器序列化回 API 响应中返回的 `filters` 对象，使客户端能看到它们的查询被如何解释。
- **输入：** `query`。
- **返回：** `Map<String, dynamic>`，带 `time`、可选 `season`/`year`/`start`/`end`（只包含与所选 `time` 范围相关的键）和 `type`（未设置时 `'all'`）。
- **副作用：** 无。
- **算法：** `year` 和 `quarter` 都设置时经 `_quarterId` 条件包含 `season`，`time == year` 时只包含 `year`，对应对设置时包含 `start`/`end`。
- **用法：** 从 `buildRankingSnapshotForQuery` 调用以构建响应的 `filters` 字段。
- **备注：** 无。

### `static int _quarterIndex(int year, int quarter)` <a id="quarterindex"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 664 行）。
- **用途：** 把 (year, quarter) 对编码为单个单调递增整数，使季度范围能用普通整数运算比较/迭代。
- **输入：** `year`、`quarter`（1–4）。
- **返回：** `int`（`year * 4 + quarter`）。
- **副作用：** 无。
- **算法：** `year * 4 + quarter`。
- **用法：** `_matchesRankingQuery` 的 `range` 分支调用以计算起始/结束索引。
- **备注：** 与 `_quarterFromIndex` 配对，后者是其精确逆。

### `static (int, int) _quarterFromIndex(int index)` <a id="quarterfromindex"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 671 行）。
- **用途：** 把 `_quarterIndex` 编码的整数解码回 (year, quarter) 对。
- **输入：** `index`。
- **返回：** `(int year, int quarter)`。
- **副作用：** 无。
- **算法：** `year = (index - 1) ~/ 4; quarter = ((index - 1) % 4) + 1`。
- **用法：** `_matchesRankingQuery` 的 `range` 分支迭代起始与结束索引之间的每个季度时调用。
- **备注：** `_quarterIndex` 的精确逆。

### `static String _quarterId(int year, int quarter)` <a id="quarterid"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 682 行）。
- **用途：** 把 (year, quarter) 对格式化为 API 的 `"YYYYQn"` 字符串形式。
- **输入：** `year`、`quarter`。
- **返回：** `String`，如 `"2026Q2"`。
- **副作用：** 无。
- **算法：** `'${year}Q$quarter'`。
- **用法：** `_rankingFiltersToJson` 调用以渲染 `season`/`start`/`end`。
- **备注：** 这与 `_parseQuarterId` 解析的字符串格式相同，也是应用别处季标识符使用的格式（见 [../../features/anime-tracking.md](../../../features/anime-tracking.md)）。

### `static Map<String, dynamic> _animeToJson(Anime a)` <a id="animetojson"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 689 行）。
- **用途：** 把一个 `Anime` 序列化为每个 API 响应（`/anime/list`、`/anime/unwatched`、`/anime/history`、`/anime/ranking`）使用的平铺 JSON 形态。
- **输入：** `a` — 要序列化的 `Anime`。
- **返回：** `Map<String, dynamic>`，带身份/URL/日程字段加派生字段：`status`（`viewingStatus.name`）、`nextUnwatchedEpisode`/`nextEpisodeAirDate`（经 `_jstToUtcString` 的 UTC 字符串）、`type`/`manualType`、`watchedEpisodes`/`skippedEpisodes`（`_episodeStatusCount`）、`airedEpisodes`/`airedUnwatchedEpisodes`、`rating`（`_ratingToJson`）和作为 ISO 8601 字符串的 `createdAt`/`modifiedAt`。
- **副作用：** 无（只读）。
- **算法：** 直接字段映射加对上面列出的每个派生字段的小辅助函数调用；文档化字段列表见本仓库 `AGENTS.md` 的"桌面 API"一节。
- **用法：** 每个返回动画行的路由处理器调用：`_handleList`、`_handleUnwatched`、`_handleHistory` 和（经 `buildRankingSnapshotForQuery`）`_handleRanking`。
- **备注：** 按其自己的文档注释，"既有键被保留，新键是添加式的"——这是 API 的向前兼容契约：可以添加新字段，但既有字段不会在发布流程别处不 bump 版本的情况下被重命名或移除。

### `static int _episodeStatusCount(Anime anime, EpisodeStatus status)` <a id="episodestatuscount"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 729 行）。
- **用途：** 统计多少条已记录剧集状态等于给定 `EpisodeStatus`。
- **输入：** `anime`、`status`。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** 按与 `status` 的相等性过滤 `anime.episodeStatuses.values` 并计数。
- **用法：** `_animeToJson` 为 `watchedEpisodes`（状态 `watched`）和 `skippedEpisodes`（状态 `skippedThisWeek`）调用。
- **备注：** 只统计有显式记录状态的剧集；不扫描范围。

### `static int _episodeScanEnd(Anime anime)` <a id="episodescanend"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 740 行）。
- **用途：** `anime.endEpisode` 未知（进行中系列）时，确定值得为进度/播出日期计算扫描的最后一个集编号。
- **输入：** `anime`。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** `endEpisode` 已设置时直接返回它。否则取 `episodeStatuses` 中存在的最高集编号，`nextUnwatchedEpisode` 更高时再延伸它，并把结果下限为 `startEpisode`。
- **用法：** `_handleUnwatched`、`_airedEpisodeCount` 和 `_airedUnwatchedEpisodeCount` 调用以约束对未知长度系列的扫描。
- **备注：** 这是对进行中/未知长度动画的启发式边界，不是不存在更晚剧集的保证——它只扫描应用已有某种记录的那些剧集。

### `static int? _airedEpisodeCount(Anime anime)` <a id="airedepisodecount"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 756 行）。
- **用途：** 统计截至现在已播出的剧集数，感知 JST。
- **输入：** `anime`。
- **返回：** `int?` — 日程数据不完整时（扫描范围内无法计算某集播出日期）为 `null`。
- **副作用：** 读取 `JstTime.now()`。
- **算法：** 扫描剧集 `startEpisode..._episodeScanEnd(anime)`；对每个，经 `anime.getEpisodeAirDate(episode)` 取播出日期——任何播出日期为 null 时中止并立即返回 `null`（日程不完整）；在第一条未来剧集处停止计数（不报错）；否则递增计数。
- **用法：** `_animeToJson` 为 `airedEpisodes` 字段调用。
- **备注：** 扫描范围内任何位置的单个缺失播出日期使整个计数为 `null`，不只是那集——这是保守的"不报告部分数字"选择。

### `static int? _airedUnwatchedEpisodeCount(Anime anime)` <a id="airedunwatchedepisodecount"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 774 行）。
- **用途：** 统计仍未看的已播出剧集数，感知 JST。
- **输入：** `anime`。
- **返回：** `int?` — 与 `_airedEpisodeCount` 相同的日程不完整条件下为 `null`。
- **副作用：** 读取 `JstTime.now()`。
- **算法：** 与 `_airedEpisodeCount` 相同的扫描，但只在剧集状态为 `unwatched`（显式或默认）时递增计数。
- **用法：** `_animeToJson` 为 `airedUnwatchedEpisodes` 字段调用。
- **备注：** 与 `_airedEpisodeCount` 共享其 null 传播和扫描边界行为；两者是对同一范围的两趟独立扫描，不是一趟合并的遍历。

### `static Map<String, dynamic>? _ratingToJson(AnimeRating? rating)` <a id="ratingtojson"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 793 行）。
- **用途：** 序列化动画评分供 API 响应，无事可报时完全省略。
- **输入：** `rating` — 可空 `AnimeRating`。
- **返回：** `Map<String, dynamic>?` — `rating` 为 null 或完全没有分数（`!rating.hasAnyScore`）时为 `null`；否则 `{overall, effectiveOverall, hasManualOverall, visual, story, character, music, enjoyment}`。
- **副作用：** 无。
- **算法：** null/空检查，然后直接字段映射。
- **用法：** `_animeToJson` 为 `rating` 字段调用。
- **备注：** 按其自己的文档注释，"未知的未来评分字段刻意不通过 API 暴露"——这是固定、策划的字段集，不是完整评分模型的透传（不同于 `_animeToJson` 对顶层动画字段的"添加式"契约）。

### `static Map<String, int> _computeCounts(List<Anime> animes)` <a id="computecounts"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 812 行）。
- **用途：** 为动画列表派生逐派生状态计数（completed/watching/dropped/not-started），包括为既有 API 消费者准备的旧键别名。
- **输入：** `animes`。
- **返回：** `Map<String, int>`，键为 `completed`、`watching`、`inProgress`（`watching` 的别名）、`dropped`、`abandoned`（`dropped` 的别名）、`notStarted`。
- **副作用：** 无。
- **算法：** 对 `animes` 单趟遍历，按每部动画的 `viewingStatus`（恰好四个 case 的枚举）切换并递增匹配计数器；两个别名键从同一计数器填充，不重新计算。
- **用法：** `_handleList` 和 `_handleHistory` 为 `counts` 字段调用。
- **备注：** `inProgress`/`abandoned` 别名纯粹为 API 向后兼容存在——按其自己的文档注释，它们是早期术语的"旧……别名，供既有 API 消费者"使用。

### `static String? _jstToUtcString(DateTime? jst)` <a id="jsttoutcstring"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 854 行）。
- **用途：** 把 JST 朴素 `DateTime`（动画日程模型产生的那种）转换为带尾部 `Z` 的 UTC ISO-8601 字符串，供 API 序列化。
- **输入：** `jst` — 可空基于 JST 的 `DateTime`。
- **返回：** `String?` — `jst` 为 null 时为 `null`。
- **副作用：** 无。
- **算法：** null 检查，然后做产生以 `Z` 结尾的 ISO 字符串的 UTC 转换（按本仓库的 `AGENTS.md`："API 日期序列化把从 JST 派生的剧集日期转换为带 `Z` 的 UTC 字符串"）。
- **用法：** `_handleUnwatched`（为 `episodeAirDate`）和 `_animeToJson`（为 `nextEpisodeAirDate`）调用。
- **备注：** 这使 API 的时间戳在单一、无歧义的时区中可机器解析，尽管应用内部调度数学基于 JST。

### `static Future<Map<String, dynamic>?> _parseBody(Request request)` <a id="parsebody"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 883 行）。
- **用途：** 读取并 JSON 解码请求体，容忍格式错误或非 JSON 输入。
- **输入：** `request`。
- **返回：** `Future<Map<String, dynamic>?>` — 正文缺失、不是有效 JSON 或不是 JSON 对象时为 `null`。
- **副作用：** 读取请求体流。
- **算法：** 把 `jsonDecode(await request.readAsString())` 包进 try/catch，任何解码失败返回 `null`，而不是让异常传播到错误中间件。
- **用法：** `_handleSearch` 和 `_handleAdd` 调用，两者都把 `null` 结果变成 `400 invalid JSON body` 响应。
- **备注：** 这正是格式错误的 JSON 产生干净 `400` 而不是作为 `_errorMiddleware` 的通用 `500` 浮出的原因。

### `static Middleware _corsMiddleware()` <a id="corsmiddleware"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 900 行）。
- **用途：** 给每个响应附加宽松 CORS 头，使基于浏览器的本地工具能跨域调用 API。
- **输入：** 无。
- **返回：** `Middleware`（一个 `shelf` 中间件工厂）。
- **副作用：** 除包装处理器外无。
- **算法：** 返回一个给内层处理器产生的每个响应周围添加宽松 CORS 响应头（allow-origin `*` 及相关头）的中间件。
- **用法：** `start()` 的 `Pipeline` 中第一个应用的中间件，使 CORS 头即使在 `_authMiddleware` 拒绝的响应上也存在。
- **备注：** "CORS 宽松"是本仓库 `AGENTS.md` 中显式、文档化的权衡——这正是 `_authMiddleware` 的 Basic Auth 强制（一旦配置凭据，即使在回环上也强制）存在的原因：单靠宽松 CORS 会让任何本地网页读到 API。

### `static Middleware _authMiddleware()` <a id="authmiddleware"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 926 行）。
- **用途：** 强制 API 的访问控制规则：回环默认可信，但一旦配置凭据，每个请求（包括回环）都必须出示有效的 HTTP Basic Auth。
- **输入：** 无。
- **返回：** `Middleware`。
- **副作用：** 除包装处理器外无；从 `request.context['shelf.io.connection_info']` 读取传入连接的远程地址。
- **算法：**
  1. 从连接的远程地址确定 `isLoopback`（连接信息缺失当作回环）。
  2. 请求非回环且未配置凭据时，以 `403 authentication required for non-localhost access` 拒绝。
  3. **配置了**凭据时，无论回环状态如何都要求有效的 `Authorization: Basic` 头（经 `_validateBasicAuth`）；失败时以带 `WWW-Authenticate: Basic realm="MyAnime API"` 头的 `401` 响应。
  4. 否则（回环、未配置凭据）透传给内层处理器。
- **用法：** `start()` 的 `Pipeline` 中第二个中间件，应用于每个路由。
- **备注：** 文档注释对理由很明确，这里引用因为它是对整个服务器安全关键的恒等式："配置了凭据时，每个请求都需要 Basic Auth，包括回环，因为宽松的 CORS 否则会让任何本地网页读到 API。未配置凭据时只允许回环请求。"

### `static bool _validateBasicAuth(String header)` <a id="validatebasicauth"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 968 行）。
- **用途：** 对照配置的 `_username`/`_password` 校验 `Authorization: Basic <base64>` 头。
- **输入：** `header` — 原始 `Authorization` 头值。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 拒绝任何不以 `"Basic "` 开头的东西；base64 解码其余部分，按第一个 `:` 拆分为用户名/密码，并对照配置的凭据比较。
- **用法：** 配置了凭据时由 `_authMiddleware` 调用。
- **备注：** 这是对照明文存储于 `storage_config.json`/设置中的凭据做的普通相等检查，与应用围绕本地凭据存储文档化（且显式不在变更范围内）的安全姿态一致。

### `static Middleware _errorMiddleware()` <a id="errormiddleware"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** `lib/shared/services/local_api_server.dart`（第 985 行）。
- **用途：** 捕获路由处理器抛出的任何未处理异常，把它变成干净的 JSON `500` 响应，而不是未处理错误崩溃或裸堆栈泄漏给客户端。
- **输入：** 无。
- **返回：** `Middleware`。
- **副作用：** 除包装处理器外无。
- **算法：** 把内层处理器调用包进 try/catch；任何异常时构建 JSON 错误响应（经 `_error`）而不是传播。
- **用法：** `start()` 的 `Pipeline` 中最内层中间件，紧贴路由器本身。
- **备注：** 这是最后防线——路由预期为预期失败模式返回自己的 `400`/`401`/`403` 响应；此中间件只捕获真正意外的异常。
