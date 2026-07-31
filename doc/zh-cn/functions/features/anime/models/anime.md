# lib/features/anime/models/anime.dart

核心数据模型：`Anime`（一部被跟踪的系列）、`AnimeRating`（可选个人评分）、`AnimeData`（顶层 `{animes: [...]}` 持久化容器），外加 `AnimeType`、`EpisodeStatus`、`AnimeViewingStatus` 和 `AnimeRatingField` 枚举。本文件拥有全部三个类的 `fromJson`/`toJson`、同步合并使用的 `extraJson` 未知字段保留模式，以及驱动主页日历和按季度管理视图的季度归属/剧集播出日期逻辑。逐字段参考（身份、日程、剧集、`AnimeType` 阈值、`AnimeRating` 计分、`extraJson`）在 [`../../../../data-formats.md`](../../../../data-formats.md)；构建在这些字段之上的跟踪/季度归属算法在 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) 中走查。使用者包括 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）、`WebDAVService`/`sync_merge.dart`（三方同步，[`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md)），以及 `lib/features/anime/views/` 下的每个视图。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_unknownJson`](#unknownjson) | 顶层函数 | A | 计算"本类型不认识的键"映射，供 `extraJson` 使用。 |
| [`_stringKeyedMap`](#stringkeyedmap) | 顶层函数 | A | 把 `Map<dynamic, dynamic>`（来自 JSON decode）规范化为 `Map<String, dynamic>`。 |
| [`_mergeJsonMaps`](#mergejsonmaps) | 顶层函数 | A | 深度合并 JSON 映射列表，后置映射的标量值胜出，嵌套映射递归合并。 |
| [`_parseAnimeType`](#parseanimetype) | 顶层函数 | A | 把 JSON 字符串解析为 `AnimeType`，不认识则 `null`。 |
| [`_parseEpisodeStatus`](#parseepisodestatus) | 顶层函数 | A | 把 JSON 字符串解析为 `EpisodeStatus`，不认识则 `null`。 |
| [`AnimeRating(...)`](#animerating-new) | 构造函数（`AnimeRating`） | A | 创建个人评分值（手动总分 + 五个子分）。 |
| `hasManualOverall` | getter（`AnimeRating`） | B | `overall` 是否已设置。 |
| `hasAnyScore` | getter（`AnimeRating`） | B | `overall`/`visual`/`story`/`character`/`music`/`enjoyment` 中是否有任一设置。 |
| `hasAnyData` | getter（`AnimeRating`） | B | 是否有任何分数或保留的 `extraJson`。 |
| [`effectiveOverall`](#effectiveoverall) | getter（`AnimeRating`） | A | 手动 `overall` 已设置时返回它，否则返回已填子分的平均。 |
| [`scoreFor`](#scorefor) | 方法（`AnimeRating`） | A | 查找给定 `AnimeRatingField` 的分数。 |
| [`withExtraJson`](#withextrajson-animerating) | 方法（`AnimeRating`） | A | 复制并把 `extraJson` 替换。 |
| [`toJson`](#tojson-animerating) | 方法（`AnimeRating`） | A | 序列化为存储在 `Anime.rating` 下的 JSON 形态。 |
| [`AnimeRating.fromJson`](#animerating-fromjson) | 工厂构造函数 | A | 从 JSON 解析评分，把非数值分数路由进 `extraJson`。 |
| [`_parseScore`](#parsescore) | 顶层函数 | A | 把 JSON 值解析为 `double` 分数，否则 `null`。 |
| [`_writeScore`](#writescore) | 顶层函数 | A | 在构建中的 JSON 映射里写入（或移除）一个分数键。 |
| [`Anime(...)`](#anime-new) | 构造函数（`Anime`） | A | 用全部持久化字段创建动画记录。 |
| [`displayTitle`](#displaytitle) | getter（`Anime`） | A | 最佳可用标题：`title`，否则 `titleJa`，否则空字符串。 |
| [`totalEpisodes`](#totalepisodes) | getter（`Anime`） | A | `endEpisode - startEpisode + 1`，开放结局时为 `null`。 |
| [`autoType`](#autotype) | getter（`Anime`） | A | 按集数阈值推断 `AnimeType`。 |
| [`effectiveType`](#effectivetype) | getter（`Anime`） | A | `manualType` 已设置时返回它，否则 `autoType`。 |
| [`airsInQuarter`](#airsinquarter) | 方法（`Anime`） | A | 这部动画是否应出现在给定的 `(year, quarter)` 列表中。 |
| [`startQuarter`](#startquarter) | getter（`Anime`） | A | 从 `firstAirDate` 的月份派生的 `(year, quarter)`。 |
| [`weekOffsetFor`](#weekoffsetfor) | 方法（`Anime`） | A | 对不超过某集编号的 `episodeWeekOffsets` 条目求和。 |
| [`getEpisodeAirDate`](#getepisodeairdate) | 方法（`Anime`） | A | 一集的 JST 播出时间戳，带深夜（`25:00` 式）回卷。 |
| [`getEpisodeCalendarDate`](#getepisodecalendardate) | 方法（`Anime`） | A | 一集的 JST 日历日期，不回卷。 |
| [`nextUnwatchedEpisode`](#nextunwatchedepisode) | getter（`Anime`） | A | 第一个仍未观看的集编号。 |
| [`isCompleted`](#iscompleted) | getter（`Anime`） | A | 到 `endEpisode` 为止的每一集是否都已看。 |
| [`viewingStatus`](#viewingstatus) | getter（`Anime`） | A | 派生的 `AnimeViewingStatus`（completed/watching/dropped/notStarted）。 |
| [`copyWith`](#copywith) | 方法（`Anime`） | A | 用所选字段创建副本（可为可空字段带 `clearXxx` 标志）。 |
| [`withExtraJson`](#withextrajson-anime) | 方法（`Anime`） | A | 复制并把 `extraJson` 替换。 |
| [`withPreservedUnknownJson`](#withpreservedunknownjson-anime) | 方法（`Anime`） | A | 从后备来源合并 `extraJson`（含嵌套评分 `extraJson`）。 |
| [`toJson`](#tojson-anime) | 方法（`Anime`） | A | 序列化为存储在 `anime_data.json` 中的 JSON 形态。 |
| [`Anime.fromJson`](#anime-fromjson) | 工厂构造函数 | A | 从 JSON 解析动画记录，保留不认识的字段。 |
| [`Anime.create`](#anime-create) | 工厂构造函数 | A | 用新 UUID 和 UTC 时间戳构建全新记录。 |
| `animeList` | getter（`AnimeData`） | B | `animes` 的别名。 |
| `AnimeData(...)` | 构造函数（`AnimeData`） | B | 平凡的默认值构造函数（`animes`/`extraJson` 都默认为空）。 |
| [`withExtraJson`](#withextrajson-animedata) | 方法（`AnimeData`） | A | 复制并把 `extraJson` 替换。 |
| [`withPreservedUnknownJson`](#withpreservedunknownjson-animedata) | 方法（`AnimeData`） | A | 从后备来源合并顶层 `extraJson`。 |
| [`toJson`](#tojson-animedata) | 方法（`AnimeData`） | A | 序列化为 `{...extraJson, animes: [...]}`。 |
| [`AnimeData.fromJson`](#animedata-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `{animes: [...]}` 容器。 |

关于校验计数的说明：源文件有 40 个 `/// Purpose:` 文档注释，但本表有 41 行——`AnimeData` 默认构造函数（第 1063 行）在源码中完全没有文档注释（与本文件其他构造函数不同），但它仍是真实声明，被索引在上（Tier B：无逻辑的平凡默认值构造函数）。

## 文档

### `Map<String, dynamic> _unknownJson(Map<String, dynamic> json, Set<String> knownKeys)` <a id="unknownjson"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 41 行）
- **用途：** 计算原始 JSON 映射中本应用版本不认识、按给定类型的已知键集合过滤后的子集。
- **输入：** `json` — 原始解码映射；`knownKeys` — 本类型理解的字段名（`_animeJsonKeys`、`_ratingJsonKeys` 或 `_animeDataJsonKeys`）。
- **返回：** `Map<String, dynamic>` — `json` 移除 `knownKeys` 中每个键后的副本。
- **副作用：** 无。
- **算法：** 把 `json` 复制进新映射，然后对 `knownKeys` 中存在的任何键 `removeWhere`。
- **用法：**
  ```dart
  final extraJson = _unknownJson(json, _animeJsonKeys);
  ```
  （`Anime.fromJson`，同一文件）
- **备注：** 这是 [`../../../../data-formats.md`](../../../../data-formats.md) 描述的 `extraJson` 向前兼容模式的基础——本文件每个 `fromJson` 都先调用它，然后各字段可能再向 `extraJson` 添加更多条目（如值无法按预期类型解析时）。

### `Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> map)` <a id="stringkeyedmap"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 55 行）
- **用途：** 把动态键映射（`jsonDecode` 为嵌套对象产生的）强转为 `Map<String, dynamic>`。
- **输入：** `map`。
- **返回：** `Map<String, dynamic>`，每个键都经 `.toString()` 转换。
- **副作用：** 无。
- **算法：** 对 `map.entries` 的单个推导式，把每个键经 `.toString()` 映射。
- **用法：**
  ```dart
  final rawStatuses = _stringKeyedMap(rawStatusesValue);
  ```
  （`Anime.fromJson`，同一文件——`rawStatusesValue` 直接来自 `jsonDecode`，类型为 `Map<dynamic, dynamic>`）
- **备注：** 需要它是因为 `dart:convert` 的 `jsonDecode` 把嵌套对象值类型化为 `Map<dynamic, dynamic>` 而不是 `Map<String, dynamic>`，因此对任何带 `episodeStatuses`、`episodeWeekOffsets` 或 `rating` 子对象的动画，直接转型都会抛出。

### `Map<String, dynamic> _mergeJsonMaps(Iterable<Map<String, dynamic>> maps)` <a id="mergejsonmaps"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 64 行）
- **用途：** 按顺序深度合并任意数量的 JSON 映射，使来自多个候选来源（如一条记录的本地和远程副本）的 `extraJson` 字段合并，而不是后置来源把前置来源的嵌套键冲掉。
- **输入：** `maps` — 从左到右合并，标量值后置条目优先。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：**
  1. 按顺序遍历 `maps` 中的每个映射。
  2. 对每个键，如果已合并的值和传入值都是 `Map`，递归合并（先经 `_stringKeyedMap` 规范化两侧）而不是覆盖。
  3. 否则，传入值直接覆盖该键上的合并值。
- **用法：**
  ```dart
  extraJson: _mergeJsonMaps([
    for (final source in sources)
      if (source != null) source.extraJson,
    extraJson,
  ]),
  ```
  （`Anime.withPreservedUnknownJson`，同一文件）
- **备注：** 递归没有深度限制；本应用中 `extraJson` 负载是小型的、手工形态的 JSON，因此这不是实际关切，但病态深层/循环形态的映射（正常 `jsonDecode` 输出不可能，它无法成环）没有专门防护。

### `AnimeType? _parseAnimeType(Object? value)` <a id="parseanimetype"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 88 行）
- **用途：** 把原始 JSON 值解析为 `AnimeType` 枚举，容忍任何不是可识别字符串的东西。
- **输入：** `value` — 通常是 `json['manualType']`。
- **返回：** `AnimeType?` — `value` 不是 `String` 或不匹配任何枚举名时为 `null`。
- **副作用：** 无。
- **算法：** `value is! String` 时立即返回 `null`；否则线性扫描 `AnimeType.values` 找 `.name` 匹配。
- **用法：**
  ```dart
  final manualType = _parseAnimeType(json['manualType']);
  if (json.containsKey('manualType') && manualType == null) {
    extraJson['manualType'] = json['manualType'];
  }
  ```
  （`Anime.fromJson`，同一文件）
- **备注：** 存在但不可解析的 `manualType`（如本应用版本不认识的未来枚举值）由调用方原样保留在 `extraJson` 中，而不是静默丢弃——见上面的用法。

### `EpisodeStatus? _parseEpisodeStatus(Object? value)` <a id="parseepisodestatus"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 101 行）
- **用途：** 把原始 JSON 值解析为 `EpisodeStatus` 枚举。
- **输入：** `value` — `episodeStatuses` JSON 映射中一个条目的值。
- **返回：** `EpisodeStatus?` — `value` 不是可识别的状态字符串时为 `null`。
- **副作用：** 无。
- **算法：** 与 `_parseAnimeType` 形态相同：先类型守卫，再按 `.name` 线性扫描 `EpisodeStatus.values`。
- **用法：**
  ```dart
  final status = _parseEpisodeStatus(entry.value);
  if (ep != null && status != null) {
    statuses[ep] = status;
  } else {
    unknownStatuses[entry.key] = entry.value;
  }
  ```
  （`Anime.fromJson`，同一文件）
- **备注：** 解析失败的条目（坏集编号键或不识别的状态字符串）收集进 `unknownStatuses`，最终进入 `extraJson['episodeStatuses']` 而不是丢失。

### `const AnimeRating({overall, visual, story, character, music, enjoyment, extraJson = const {}})` <a id="animerating-new"></a>
- **种类：** `AnimeRating` 的构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 154 行）
- **用途：** 保存个人评分：可选的手动总分加五个可选的 0–10 子分（visual、story、character、music、enjoyment）。
- **输入：** 六个分数字段都可选；`extraJson` 默认为 `{}`。
- **返回：** 新的 `AnimeRating`。
- **副作用：** 无。
- **算法：** 通过 `const` 构造函数平凡字段赋值。
- **用法：**
  ```dart
  final rating = AnimeRating(
    overall: _parseScore(_ratingOverallController),
    visual: _parseScore(_ratingVisualController),
    story: _parseScore(_ratingStoryController),
    character: _parseScore(_ratingCharacterController),
    music: _parseScore(_ratingMusicController),
    enjoyment: _parseScore(_ratingEnjoymentController),
  );
  return rating.hasAnyData ? rating : null;
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，`_buildRating`）
- **备注：** 计分量表和 `effectiveOverall` 回退规则见 [`../../../../data-formats.md`](../../../../data-formats.md)。

### `double? get effectiveOverall` <a id="effectiveoverall"></a>
- **种类：** `AnimeRating` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 196 行）
- **用途：** 手动总分已设置时返回它，否则返回已填子分的平均。
- **输入：** 无。
- **返回：** `double?` — 只在 `overall` 未设置且每个子分也未设置时为 `null`。
- **副作用：** 无。
- **算法：**
  1. 如果 `overall != null`，直接返回它。
  2. 否则把 `visual`/`story`/`character`/`music`/`enjoyment` 的非 null 值收集进列表。
  3. 如果该列表为空，返回 `null`。
  4. 否则返回 `sum / count`（对存在的子分求直平均）。
- **用法：**
  ```dart
  if (anime.rating?.effectiveOverall != null) ...[
    const SizedBox(height: 12),
  ```
  （`lib/features/anime/views/anime_detail_page.dart`）
- **备注：** 手动 `overall` 总是完全胜出；手动总分与子分平均之间没有混合。

### `double? scoreFor(AnimeRatingField field)` <a id="scorefor"></a>
- **种类：** `AnimeRating` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 215 行）
- **用途：** 查找该评分对给定可排序/可显示字段的值，把 `AnimeRatingField.overall` 经 `effectiveOverall` 路由，而不是原始 `overall` 字段。
- **输入：** `field`。
- **返回：** `double?`。
- **副作用：** 无。
- **算法：** 对 `AnimeRatingField` 做 `switch`：`overall` 映射到 `effectiveOverall`；其他每个 case 直接返回匹配字段（`visual`、`story`、`character`、`music`、`enjoyment`）。
- **用法：**
  ```dart
  return anime.rating?.scoreFor(query.field) != null;
  ```
  （`lib/shared/services/local_api_server.dart`，排名查询过滤器）
- **备注：** 这正是本地 API 和 UI 中按"总分"排名/排序反映与显示相同的有效总分回退、而不是排除只有子分的动画的原因。

### `AnimeRating withExtraJson(Map<String, dynamic> extraJson)` <a id="withextrajson-animerating"></a>
- **种类：** `AnimeRating` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 237 行）
- **用途：** 返回只替换 `extraJson` 的评分副本。
- **输入：** `extraJson`。
- **返回：** 每个分数字段都未变的新 `AnimeRating`。
- **副作用：** 无。
- **算法：** 重建一个 `AnimeRating`，复用全部六个分数字段并替换给定的 `extraJson`。
- **用法：**
  ```dart
  final preservedRating = rating != null
      ? rating!.withExtraJson(mergedRatingExtraJson)
      : (mergedRatingExtraJson.isNotEmpty
            ? AnimeRating(extraJson: mergedRatingExtraJson)
            : null);
  ```
  （`Anime.withPreservedUnknownJson`，同一文件）
- **备注：** 无。

### `Map<String, dynamic> toJson()`（`AnimeRating`） <a id="tojson-animerating"></a>
- **种类：** `AnimeRating` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 252 行）
- **用途：** 把评分序列化为存储在 `Anime.rating` 下的 JSON 形态。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — `extraJson` 覆盖上每个已知分数键。
- **副作用：** 无。
- **算法：** 从 `extraJson` 的副本开始，然后对六个分数字段各调用一次 [`_writeScore`](#writescore)，它在分数非 null 时设置键，否则让任何既有的 `extraJson` 值保持原样（见 `_writeScore` 自己的备注）。
- **用法：**
  ```dart
  if (rating != null && rating!.hasAnyData) {
    json['rating'] = rating!.toJson();
  } else if (!extraJson.containsKey('rating')) {
    json.remove('rating');
  }
  ```
  （`Anime.toJson`，同一文件）
- **备注：** 无。

### `factory AnimeRating.fromJson(Map<String, dynamic> json)` <a id="animerating-fromjson"></a>
- **种类：** `AnimeRating` 的工厂构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 268 行）
- **用途：** 从持久化 JSON 形态重建评分，保留任何不是可识别分数名的键和任何不是数值的分数值。
- **输入：** `json`。
- **返回：** 新的 `AnimeRating`。
- **副作用：** 无。
- **算法：**
  1. 通过 [`_unknownJson`](#unknownjson) 把 `extraJson` 计算为 `json` 中 `_ratingJsonKeys` 之外的每个键。
  2. 对六个分数键各调用一次内联 `readScore` 闭包：经 [`_parseScore`](#parsescore) 解析；如果键在 `json` 中存在但未解析为 `num`（`score == null` 而 `json.containsKey(key)`），把原始值暂存进 `extraJson[key]` 而不是丢弃。
  3. 从六个解析出的分数加累积的 `extraJson` 构造 `AnimeRating`。
- **用法：**
  ```dart
  rating = AnimeRating.fromJson(_stringKeyedMap(rawRatingValue));
  if (!rating.hasAnyData) rating = null;
  ```
  （`Anime.fromJson`，同一文件——没有分数且没有额外数据的评分收缩回 `null`）
- **备注：** 根本不是 `Map` 的 `rating` JSON 值由调用方（`Anime.fromJson`）处理，不在这里——它被保留进父级的 `extraJson['rating']`，而不是调用此工厂。

### `double? _parseScore(Object? value)` <a id="parsescore"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 296 行）
- **用途：** 把原始 JSON 值解析为 `double` 分数。
- **输入：** `value`。
- **返回：** `double?` — `value is num` 时为 `value.toDouble()`，否则 `null`。
- **副作用：** 无。
- **算法：** 单个类型检查和转换。
- **用法：**
  ```dart
  double? readScore(String key) {
    final score = _parseScore(json[key]);
    ...
  ```
  （`AnimeRating.fromJson`，同一文件）
- **备注：** 无。

### `void _writeScore(Map<String, dynamic> json, String key, double? score)` <a id="writescore"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime.dart`（第 306 行）
- **用途：** 在构建评分 JSON 映射时设置或清除一个分数键。
- **输入：** `json`（原地修改）、`key`、`score`。
- **返回：** 无。
- **副作用：** 修改 `json` — `score != null` 时设置 `json[key] = score`。
- **算法：** 如果 `score` 非 null，写它。否则，只在 `json` 尚未包含 `key` 时才会移除它——但 `remove` 调用受 `!json.containsKey(key)` 守卫，因此实践中既有的 `extraJson[key]` 值（如被 `fromJson` 保留的非数值分数）完全不被触碰而不是被清除。
- **用法：**
  ```dart
  _writeScore(json, 'overall', overall);
  ```
  （`AnimeRating.toJson`，同一文件）
- **备注：** `else if (!json.containsKey(key)) json.remove(key);` 分支按构造是空操作（只在键已缺失时才到达 `remove`）——实际效果就是"类型化字段为 null 时不要动既有的未识别值"。

### `const Anime({required id, title, titleJa, season = 'Season 1', startEpisode = 1, endEpisode = 13, manualType, airDayOfWeek, airTime, firstAirDate, episodeStatuses = const {}, coverImage, infoUrl, watchUrl, episodeWeekOffsets = const {}, notes, rating, required createdAt, required modifiedAt, extraJson = const {}})` <a id="anime-new"></a>
- **种类：** `Anime` 的构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 384 行）
- **用途：** 直接从每个持久化字段构造 `Anime` 记录。
- **输入：** `id`、`createdAt`、`modifiedAt` 必填；`season` 默认为 `'Season 1'`、`startEpisode` 为 `1`、`endEpisode` 为 `13`（新的单 cour 假设）、`episodeStatuses`/`episodeWeekOffsets`/`extraJson` 默认为空；其余全可选。
- **返回：** 新的 `Anime`。
- **副作用：** 无。
- **算法：** 通过 `const` 构造函数平凡字段赋值；无派生状态或校验（如它不强制 `title`/`titleJa` 至少设置一个——那是文档化的不变量，不是被检查的）。
- **用法：**
  ```dart
  return Anime(
    id: const Uuid().v4(),
    title: parsed.title,
    titleJa: parsed.titleJa,
    season: parsed.season,
    startEpisode: parsed.startEpisode,
    endEpisode: parsed.endEpisode,
    ...
  );
  ```
  （`lib/shared/services/file_open_service.dart`，`_importOne`——导入共享 `.myanimeitem` 记录时重新分配新 UUID）
- **备注：** `endEpisode` 默认为 `13`（而不是 `null`）意味着只用 `id`/`createdAt`/`modifiedAt` 构造 `Anime` 会产出单 cour 形态的记录，而不是开放结局的；`Anime.create` 依赖同一个默认值。

### `String get displayTitle` <a id="displaytitle"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 412 行）
- **用途：** 返回用于显示的最佳可用标题。
- **输入：** 无。
- **返回：** `String` — `title` 非空则它，否则 `titleJa` 非空则它，否则 `''`。
- **副作用：** 无。
- **算法：** 对 `.isNotEmpty == true` 的两层嵌套三元检查（容忍 null 接收者）。
- **用法：**
  ```dart
  final aTitle = _normalizeTitle(a.displayTitle);
  ```
  （`lib/shared/services/duplicate_service.dart`，标题相似度比较——见 [`../../../../features/duplicate-detection.md`](../../../../features/duplicate-detection.md)）
- **备注：** 即使 `title` 和 `titleJa` 都是 `null` 也绝不抛出或返回 `null`——调用方可以依赖一个普通（可能为空的）`String`。

### `int? get totalEpisodes` <a id="totalepisodes"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 421 行）
- **用途：** 运行长度已知时返回总集数。
- **输入：** 无。
- **返回：** `int?` — `endEpisode` 已设置时为 `endEpisode! - startEpisode + 1`，否则 `null`。
- **副作用：** 无。
- **算法：** 单个条件表达式。
- **用法：**
  ```dart
  final total = anime.totalEpisodes;
  ```
  （`lib/shared/services/import_export_service.dart`，Markdown 导出观看状态行）
- **备注：** `null` 特指长期连载/未知终点，与合理的少集数不同。

### `AnimeType get autoType` <a id="autotype"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 429 行）
- **用途：** 仅从当前集数推断播出类型，忽略任何手动覆盖。
- **输入：** 无。
- **返回：** `AnimeType`。
- **副作用：** 无。
- **算法：** `totalEpisodes` 为 `null` 时返回 `longRunning`；否则按 [`../../../../data-formats.md`](../../../../data-formats.md) 文档化的阈值走 if 链：`<=13` → `singleCour`，`<=26` → `halfYear`，`<=52` → `fullYear`，否则 `longRunning`。
- **用法：**
  ```dart
  AnimeType get effectiveType {
    if (manualType != null) return manualType!;
    return autoType;
  }
  ```
  （`Anime.effectiveType`，同一文件）
- **备注：** `allAtOnce` 绝不由 `autoType` 产生——它只能通过 `manualType` 到达。

### `AnimeType get effectiveType` <a id="effectivetype"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 443 行）
- **用途：** 返回真正应驱动应用行为（日历渲染、季度归属、剧集日期回卷）的 `AnimeType`，在存在时应用手动覆盖。
- **输入：** 无。
- **返回：** `AnimeType`。
- **副作用：** 无。
- **算法：** `manualType != null` 时返回 `manualType!`，否则 `autoType`。
- **用法：**
  ```dart
  if (anime.effectiveType == AnimeType.allAtOnce) {
    return anime.getEpisodeCalendarDate(episode);
  }
  ```
  （`lib/features/anime/views/home_page.dart`，`_effectiveEpisodeDate`）
- **备注：** 这个优先级——手动总是胜出——在读取 `effectiveType` 的每个地方都一致，包括 [`airsInQuarter`](#airsinquarter)、[`getEpisodeAirDate`](#getepisodeairdate) 和 [`getEpisodeCalendarDate`](#getepisodecalendardate)。

### `bool airsInQuarter(int year, int quarter)` <a id="airsinquarter"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 453 行）
- **用途：** 决定这部动画是否应出现在给定的 `(year, quarter)` 列表中（管理和统计页使用的"cour"分组）。
- **输入：** `year`、`quarter`（1–4）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 完整三分支逻辑（手动类型 cour 跨度、估计周数跨度、长期连载日期重叠回退）的详细走查在 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md#quarter-placement)。简言之：
  1. `firstAirDate` 或 `startQuarter` 不可用时立即返回 `false`。
  2. `manualType` 已设置（且不是 `longRunning`）时，用从 `startQuarter` 起的固定跨度（`allAtOnce`/`singleCour` → 1 个季度，`halfYear` → 2 个，`fullYear` → 4 个），并检查 `(year, quarter)` 是否落在该跨度内。
  3. 否则，`endEpisode` 已知时，把实际运行周数估计为 `(episodeCount - 1) + weekOffsetFor(lastEpisode)`，并映射为季度跨度，每个边界约 2 周容差（`<=15`→1，`<=28`→2，`<=41`→3，`<=54`→4，否则 `ceil(weeks/13)`）。
  4. 否则（长期连载、无手动类型），回退为 `[firstAirDate, firstAirDate + 51 weeks]` 与请求季度日期范围之间的简单日期重叠检查。
- **用法：**
  ```dart
  return _allAnime.where((a) {
    return a.airsInQuarter(quarter.year, quarter.q);
  }).toList()..sort((a, b) { ... });
  ```
  （`lib/features/anime/views/management_page.dart`，`_animeForQuarter`）
- **备注：** 手动类型 switch 内部的 `AnimeType.longRunning` case（`spanQuarters = 0`）在实践中不可达，因为外围 `if` 已经排除了 `manualType == AnimeType.longRunning`。

### `(int, int)? get startQuarter` <a id="startquarter"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 518 行）
- **用途：** 返回从 `firstAirDate` 的月份派生的起始播出季度。
- **输入：** 无。
- **返回：** `(int, int)?` — `(year, quarter)`，`firstAirDate` 未设置时为 `null`。
- **副作用：** 无。
- **算法：** 把 `firstAirDate!.month` 映射到季度：1–3 → Q1，4–6 → Q2，7–9 → Q3，否则（10–12）→ Q4。
- **用法：**
  ```dart
  final sq = anime.startQuarter;
  if (sq == null) {
    // No date — jump to "Other" page
  ```
  （`lib/features/anime/views/management_page.dart`）
- **备注：** 无。

### `int weekOffsetFor(int episodeNumber)` <a id="weekoffsetfor"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 533 行）
- **用途：** 对每个影响给定剧集的已配置周调整求和。
- **输入：** `episodeNumber`。
- **返回：** `int` — 要偏移的总周数（正 = 延期，负 = 提前）。
- **副作用：** 无。
- **算法：** 遍历 `episodeWeekOffsets.entries`，对每个键 `<= episodeNumber` 的条目累加 `entry.value`（累计，不是单次覆盖）。
- **用法：**
  ```dart
  final totalWeeks = episodeOffset + weekOffsetFor(episodeNumber);
  final baseDate = firstAirDate!.add(Duration(days: totalWeeks * 7));
  ```
  （`Anime.getEpisodeAirDate`，同一文件）
- **备注：** 直接进入两个剧集日期 getter 和 [`airsInQuarter`](#airsinquarter) 的估计周数分支——见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `DateTime? getEpisodeAirDate(int episodeNumber)` <a id="getepisodeairdate"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 546 行）
- **用途：** 计算一集的 JST 播出时间戳，包括深夜档回卷（如 `"25:00"` = 次日 01:00）。
- **输入：** `episodeNumber`。
- **返回：** `DateTime?` — 日程数据不完整时（`firstAirDate` 或 `airDayOfWeek` 缺失，或 `episodeNumber < startEpisode`）为 `null`。
- **副作用：** 无。
- **算法：**
  1. `firstAirDate` 未设置时返回 `null`。
  2. `effectiveType == AnimeType.allAtOnce` 时原样返回 `firstAirDate`（每集"播出"于同一时刻）。
  3. `airDayOfWeek` 未设置或 `episodeNumber < startEpisode` 时返回 `null`。
  4. 计算 `totalWeeks = (episodeNumber - startEpisode) + weekOffsetFor(episodeNumber)` 和基础日期 `firstAirDate + totalWeeks weeks`。
  5. 把基础日期向前吸附到 `airDayOfWeek` 的下一次出现（`diff = airDayOfWeek - baseDate.weekday`，负则 `+7`），使结果即使 `airDayOfWeek` 与基础日期实际星期几不一致也绝不早于 `firstAirDate`。
  6. 应用 `airTime`：已设置时解析 `HH:MM`（容忍小时 `>= 24`，如 `"25:00"`，把解析出的 `Duration` 加到吸附日期的午夜上）——格式错误的小时/分钟回退为 `23`/`59`。`airTime` 为 `null` 时把时间设为 `23:59`。
- **用法：**
  ```dart
  final airDate = anime.getEpisodeAirDate(ep);
  if (airDate != null && !airDate.isAfter(JstTime.now())) {
    episodes.add(_AiringEpisode(anime: anime, episode: ep));
  }
  ```
  （`lib/features/anime/views/home_page.dart`，`_getUnwatchedEpisodes`）
- **备注：** `"25:00"` 式时间为什么是此方法必须支持的真实惯例见 [`../../../../data-formats.md`](../../../../data-formats.md)，在需要普通日历日（不是 JST 时刻）的地方使用的无回卷姊妹方法见 [`getEpisodeCalendarDate`](#getepisodecalendardate)。

### `DateTime? getEpisodeCalendarDate(int episodeNumber)` <a id="getepisodecalendardate"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 592 行）
- **用途：** 计算一集的 JST 日历播出日期，刻意不应用 `airTime` 的深夜回卷。
- **输入：** `episodeNumber`。
- **返回：** `DateTime?` — 与 [`getEpisodeAirDate`](#getepisodeairdate) 相同的 null 条件。
- **副作用：** 无。
- **算法：** 镜像 `getEpisodeAirDate` 走过同样的周偏移/星期几吸附逻辑，但停在吸附后的日历日期（`DateTime(year, month, day)`）——它绝不读取 `airTime`，因此 `"24:00"`/`"25:00"` 档保留在其计划日期上，而不是回卷到下一个日历日。
- **用法：**
  ```dart
  final airDate = anime.getEpisodeCalendarDate(ep);
  final airStr = airDate != null
      ? DateFormat.MMMd().format(airDate)
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，剧集列表渲染）
- **备注：** 在应用需要"这一集是哪个日历日的播出日"（如与提醒的本地日期匹配）而不是"它在哪个时刻播出"的任何地方，用它替代 `getEpisodeAirDate`——见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `int? get nextUnwatchedEpisode` <a id="nextunwatchedepisode"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 623 行）
- **用途：** 返回第一个仍未观看的集编号。
- **输入：** 无。
- **返回：** `int?` — 每个被跟踪的剧集（到 `endEpisode` 为止，开放结局系列则为 `startEpisode + 999`）都已是 `watched` 或 `skippedThisWeek` 时为 `null`。
- **副作用：** 无。
- **算法：** 从 `startEpisode` 到 `endEpisode ?? startEpisode + 999` 线性扫描；返回状态缺失或为 `unwatched` 的第一集。
- **用法：**
  ```dart
  final nxt = a.nextUnwatchedEpisode;
  ```
  （`lib/shared/services/local_api_server.dart`，`_animeToJson`）
- **备注：** 对没有 `endEpisode` 的长期连载系列，扫描上限为 `startEpisode` 之后 999 集，而不是真正无界。

### `bool get isCompleted` <a id="iscompleted"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 639 行）
- **用途：** 每一集是否都已看。
- **输入：** 无。
- **返回：** `bool` — `endEpisode` 为 `null` 时总是 `false`（开放结局系列永远不可能"完成"）。
- **副作用：** 无。
- **算法：** `endEpisode == null` 时立即返回 `false`；否则循环 `startEpisode..endEpisode`，在第一个状态不是 `watched` 的剧集返回 `false`；循环完成则 `true`。
- **用法：**
  ```dart
  final allWatched = _anime!.isCompleted;
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，切换"全部标记已看/未看"）
- **备注：** 无。

### `AnimeViewingStatus get viewingStatus` <a id="viewingstatus"></a>
- **种类：** `Anime` 的 getter
- **来源：** `lib/features/anime/models/anime.dart`（第 652 行）
- **用途：** 派生整个 UI 显示的观看状态，从 `episodeStatuses` 计算而不是单独存储。
- **输入：** 无。
- **返回：** `AnimeViewingStatus` — `completed`、`watching`、`dropped`、`notStarted` 之一。
- **副作用：** 无。
- **算法：**
  1. `isCompleted` → `completed`。
  2. `endEpisode == null`（长期连载）：任何被跟踪剧集为 `watched` 则 `watching`，否则 `notStarted`。
  3. 否则扫描 `startEpisode..endEpisode`，跟踪是否有剧集为 `unwatched`、`watched` 或 `skippedThisWeek`（缺失条目默认为 `unwatched`）。
  4. 至少一个 `skippedThisWeek` 且没有剩余 `unwatched` 剧集则 `dropped`；任何剧集为 `watched` 则 `watching`；否则 `notStarted`。
- **用法：**
  ```dart
  switch (a.viewingStatus) {
    case AnimeViewingStatus.completed:
  ```
  （`lib/shared/services/local_api_server.dart`，状态统计）
- **备注：** "弃看"具体要求*零*剩余未看剧集且至少一个跳过——既有未看又有跳过剧集的动画仍是 `watching`，不是 `dropped`。见 [`../../../../data-formats.md`](../../../../data-formats.md) 和 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `Anime copyWith({...})` <a id="copywith"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 685 行）
- **用途：** 用所选字段创建副本，用 `clearXxx` 布尔标志显式清空本来可空的字段（因为给参数传 `null` 与"未提供"无法区分）。
- **输入：** 每个可变字段一个可选参数，外加 `clearEndEpisode`/`clearManualType`/`clearAirDayOfWeek`/`clearAirTime`/`clearFirstAirDate`/`clearCoverImage`/`clearInfoUrl`/`clearWatchUrl`/`clearNotes`/`clearRating`（全部默认 `false`）；`modifiedAt` 可选（未提供时默认为 `DateTime.now().toUtc()`）。
- **返回：** 新的 `Anime`；`id`、`createdAt` 和 `extraJson` 总是原样带过。
- **副作用：** 无（但不带显式 `modifiedAt` 调用它会读取当前时间）。
- **算法：** 对每个带 `clearXxx` 标志的可空字段：标志为 `true` 则字段变 `null`；否则提供值非 null 时用之，否则保留既有值（`value ?? this.value`）。不可空字段（`season`、`startEpisode`）和 `episodeStatuses`/`episodeWeekOffsets` 直接 `?? this.field`，无 clear 标志。
- **用法：**
  ```dart
  final updated = _existing!.copyWith(
    title: _titleController.text.trim(),
    ...
    rating: rating,
    clearRating: rating == null,
    modifiedAt: DateTime.now().toUtc(),
  );
  await AnimeStorage.addOrUpdate(updated);
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，保存编辑后的动画）
- **备注：** 除非调用方传入显式值，`modifiedAt` 总是前进到"现在"——UI 中每个编辑路径都显式传 `DateTime.now().toUtc()`，使同步冲突检测（比较 `modifiedAt`）能看到该编辑。

### `Anime withExtraJson(Map<String, dynamic> extraJson)`（`Anime`） <a id="withextrajson-anime"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 747 行）
- **用途：** 返回只替换 `extraJson` 的动画副本。
- **输入：** `extraJson`。
- **返回：** 其他每个字段都未变的新 `Anime`。
- **副作用：** 无。
- **算法：** 重建一个 `Anime`，复用除 `extraJson` 外的每个字段。
- **用法：** 目前不从本文件外部直接调用——`withPreservedUnknownJson`（下方）是每个调用方实际使用的入口；它构建合并后的 `extraJson` 并内联构造最终 `Anime`，而不是调用这个辅助。直接使用会是：
  ```dart
  final copy = anime.withExtraJson({'newField': 'value'});
  ```
- **备注：** 与 `AnimeRating.withExtraJson`/`AnimeData.withExtraJson` 保持平行，让三个 JSON 保留类型一致，尽管它目前唯一的调用路径是概念性的（`withPreservedUnknownJson` 直接重新实现同一字段列表，而不是委托给此方法）。

### `Anime withPreservedUnknownJson(Iterable<Anime?> fallbackSources)` <a id="withpreservedunknownjson-anime"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 775 行）
- **用途：** 把本记录的 `extraJson`（及其评分的 `extraJson`）与一个或多个后备候选的 `extraJson` 合并——通常是同步合并中同一条记录的本地和远程副本——使*本*应用版本不认识但任一侧存在的字段存活。
- **输入：** `fallbackSources` — `Anime?` 的可迭代（null 被跳过）。
- **返回：** `extraJson` 和 `rating.extraJson` 各自替换为合并形态的新 `Anime`；其他每个字段都从 `this` 原样复制。
- **副作用：** 无（纯）。
- **算法：**
  1. 经 [`_mergeJsonMaps`](#mergejsonmaps) 合并每个有非 null `rating` 的来源的 `rating.extraJson`，加上本记录自己的 `rating?.extraJson`。
  2. `this.rating` 非 null 时，产出 `rating!.withExtraJson(mergedRatingExtraJson)`；否则合并映射非空时，合成一个无分数的 `AnimeRating(extraJson: ...)`，使只在另一台设备上通过 `extraJson` 存在的评分不会消失；否则 `null`。
  3. 用同样的方式跨所有来源加 `this.extraJson` 合并顶层 `extraJson`。
  4. 返回 `this` 的完整副本，带合并后的 `rating` 和 `extraJson`。
- **用法：**
  ```dart
  all.add(chosen.withPreservedUnknownJson([c.localRecord, c.remoteRecord]));
  ```
  （`lib/shared/services/sync_merge.dart`，`AnimeMergeResult.buildResolved`——见 [`../services/sync_merge.md`](../../../shared/services/sync_merge.md) 如有文档，或 [`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md)）
- **备注：** 这正是 [`../../../../data-formats.md`](../../../../data-formats.md) 的 `extraJson` 一节和 [`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md) 通篇引用的机制，解释旧版应用编辑一条记录为什么不会抹掉新版引入的字段。

### `Map<String, dynamic> toJson()`（`Anime`） <a id="tojson-anime"></a>
- **种类：** `Anime` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 821 行）
- **用途：** 把本记录序列化为持久化在 `anime_data.json` 中的 JSON 形态。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：**
  1. 从 `extraJson` 的副本开始。
  2. 构建 `episodeStatuses`'/`episodeWeekOffsets`' 的 JSON：从保留在 `extraJson['episodeStatuses']`/`extraJson['episodeWeekOffsets']` 中的任何未知条目开始（经 [`_stringKeyedMap`](#stringkeyedmap)），然后覆盖上每个已知条目（`k.toString(): v.name` / `k.toString(): v`）。
  3. 写每个标量字段（`id`、`title`、`titleJa`、`season`、`startEpisode`、`endEpisode`、`manualType`、`airDayOfWeek`、`airTime`、`firstAirDate`、`coverImage`、`infoUrl`、`watchUrl`、`notes`、`createdAt`、`modifiedAt`）——可空字段非 null 时写入，否则 `json.remove(key)`，唯独 `manualType`/`rating` 在字段为 null 但键已通过 `extraJson` 存活时保持原样（不移除）。
  4. `episodeStatuses` 总是写入（即使为空）；`episodeWeekOffsets` 只在非空时写入。
  5. `rating` 只在 `rating != null && rating!.hasAnyData` 时通过 `rating!.toJson()` 写入。
- **用法：**
  ```dart
  final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
  ```
  （`AnimeStorage.save`，[`../services/anime_storage.md`](../services/anime_storage.md#save)——经由 `AnimeData.toJson`，它对每个动画映射此方法）
- **备注：** 应用为什么总是对这个输出使用 `JsonEncoder.withIndent('  ')`（逐字节相同的重存避免虚假的同步重新上传）见 [`../../../../data-formats.md`](../../../../data-formats.md)。

### `factory Anime.fromJson(Map<String, dynamic> json)` <a id="anime-fromjson"></a>
- **种类：** `Anime` 的工厂构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 922 行）
- **用途：** 从持久化 JSON 形态重建 `Anime`，保留本应用版本不认识或无法解析的每个字段。
- **输入：** `json`。
- **返回：** 新的 `Anime`。
- **副作用：** 无。
- **算法：**
  1. `extraJson` 初始为 `_animeJsonKeys` 之外的每个键（经 [`_unknownJson`](#unknownjson)）。
  2. `manualType` 经 [`_parseAnimeType`](#parseanimetype) 解析；存在但不可解析的值保留进 `extraJson['manualType']`。
  3. `episodeStatuses` 经 [`_parseEpisodeStatus`](#parseepisodestatus) 解析每个条目；解析失败的条目（坏键或坏值）收集进 `extraJson['episodeStatuses']` 而不是类型化映射；原始值根本不是 `Map` 时，保留整个原始值。
  4. `episodeWeekOffsets` 走完全相同的模式，要求 `int` 值。
  5. `rating` 在原始值是 `Map` 时经 [`AnimeRating.fromJson`](#animerating-fromjson) 解析，解析出的评分没有数据时收缩为 `null`；非 `Map` 原始值保留进 `extraJson['rating']`。
  6. 必填标量字段（`id`、`createdAt`、`modifiedAt`）用 `as` 转型读取（缺失/类型错误时抛出）；其余用 `as Type?` 带合理默认值（`season` → `'Season 1'`，`startEpisode` → `1`）。
- **用法：**
  ```dart
  final data = AnimeData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  ```
  （`lib/shared/services/webdav_service.dart`，提取被引用的封面图像名——内部经 `AnimeData.fromJson` 对每个数组元素调用一次 `Anime.fromJson`）
- **备注：** `createdAt`/`modifiedAt`/`firstAirDate` 解析使用 `DateTime.parse`（格式错误时抛出）而不是 `DateTime.tryParse`——`anime_data.json` 中的损坏时间戳使整个加载失败，而不是静默丢弃那个字段。

### `factory Anime.create({title, titleJa, season, startEpisode = 1, endEpisode = 13, manualType, airDayOfWeek, airTime, firstAirDate, coverImage, infoUrl, watchUrl, notes, rating})` <a id="anime-create"></a>
- **种类：** `Anime` 的工厂构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 1012 行）
- **用途：** 为手动录入或导入创建全新动画记录，生成新 UUID 和 UTC 创建/修改时间戳。
- **输入：** 与默认构造函数相同的可选字段，减去 `id`/`createdAt`/`modifiedAt`/`episodeStatuses`/`episodeWeekOffsets`/`extraJson`（这些在创建时种子化都没有意义）。
- **返回：** `id = const Uuid().v4()` 且 `createdAt == modifiedAt == DateTime.now().toUtc()` 的新 `Anime`。
- **副作用：** 除读取当前时间和生成 UUID 外无（无 I/O）。
- **算法：** 只计算一次 `now`（使 `createdAt` 和 `modifiedAt` 相同），然后委托给默认 `Anime(...)` 构造函数。
- **用法：**
  ```dart
  final anime = Anime.create(
    title: title,
    titleJa: _titleJaController.text.trim().isEmpty ? null : _titleJaController.text.trim(),
    ...
  );
  await AnimeStorage.addOrUpdate(anime);
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，从编辑表单创建新动画）
- **备注：** 这是模型层中为全新记录生成 UUID 的唯一地方；既有记录的导入（`file_open_service.dart`）直接调用默认 `Anime(...)` 构造函数并带它们自己的新 `const Uuid().v4()`，而不是走 `create`。

### `AnimeData withExtraJson(Map<String, dynamic> extraJson)`（`AnimeData`） <a id="withextrajson-animedata"></a>
- **种类：** `AnimeData` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 1070 行）
- **用途：** 返回只替换 `extraJson` 的容器副本。
- **输入：** `extraJson`。
- **返回：** 带相同 `animes` 列表的新 `AnimeData`。
- **副作用：** 无。
- **算法：** 单表达式重建。
- **用法：**
  ```dart
  AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources) =>
      withExtraJson(
        _mergeJsonMaps([...]),
      );
  ```
  （`AnimeData.withPreservedUnknownJson`，同一文件——它在本文件中的唯一调用点）
- **备注：** 无。

### `AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources)` <a id="withpreservedunknownjson-animedata"></a>
- **种类：** `AnimeData` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 1078 行）
- **用途：** 把本容器的顶层 `extraJson` 与一个或多个后备候选的合并（如同步合并中的远程 `AnimeData`）。
- **输入：** `fallbackSources`。
- **返回：** 经 [`withExtraJson`](#withextrajson-animedata) 的新 `AnimeData`。
- **副作用：** 无。
- **算法：** 委托给 [`_mergeJsonMaps`](#mergejsonmaps)，遍历每个非 null 来源的 `extraJson` 后再跟 `this.extraJson`（使 `this` 在标量冲突上胜出），然后用 `withExtraJson` 包装结果。
- **用法：**
  ```dart
  final extraJson = localData.withPreservedUnknownJson([remoteData]).extraJson;
  ```
  （`lib/shared/services/sync_merge.dart`，`mergeAnimeData`——在构建最终 `AnimeMergeResult` 前合并两个顶层容器的未知字段）
- **备注：** 这是 `Anime.withPreservedUnknownJson` 的顶层容器对应物；逐记录的 `extraJson` 每条动画单独处理，不经由此方法。

### `Map<String, dynamic> toJson()`（`AnimeData`） <a id="tojson-animedata"></a>
- **种类：** `AnimeData` 的方法
- **来源：** `lib/features/anime/models/anime.dart`（第 1092 行）
- **用途：** 把整个容器序列化为写入 `anime_data.json` 的 JSON 形态。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — `{...extraJson, 'animes': [...]}`。
- **副作用：** 无。
- **算法：** 先展开 `extraJson`，然后用 `animes.map((a) => a.toJson()).toList()` 覆盖/添加 `'animes'`。
- **用法：**
  ```dart
  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
  ```
  （`AnimeStorage.save`，[`../services/anime_storage.md`](../services/anime_storage.md#save)）
- **备注：** 因为 `extraJson` 在 `'animes'` 设置*之前*展开，`extraJson` 内部遗留/外来的顶层 `animes` 键（正常情况下不应存在，因为 `'animes'` 是被 `_unknownJson` 排除的已知键）会被真实列表覆盖，而不是反过来。

### `factory AnimeData.fromJson(Map<String, dynamic> json)` <a id="animedata-fromjson"></a>
- **种类：** `AnimeData` 的工厂构造函数
- **来源：** `lib/features/anime/models/anime.dart`（第 1102 行）
- **用途：** 从 JSON 解析顶层 `{animes: [...]}` 容器。
- **输入：** `json` — 解码后的 `anime_data.json`（或备份/导入捆绑）映射。
- **返回：** 新的 `AnimeData`。
- **副作用：** 无。
- **算法：** 把 `json['animes']`（`List<dynamic>?`）逐元素经 [`Anime.fromJson`](#anime-fromjson) 映射，`animes` 缺失时默认为 `[]`；`extraJson` 经 [`_unknownJson`](#unknownjson) 对照 `_animeDataJsonKeys`（`{'animes'}`）计算。
- **用法：**
  ```dart
  static Future<AnimeData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const AnimeData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const AnimeData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AnimeData.fromJson(json);
  }
  ```
  （`AnimeStorage.load`，[`../services/anime_storage.md`](../services/anime_storage.md#load)）
- **备注：** 缺失的 `animes` 键解析为空列表而不是抛出，但单个格式错误的动画条目会传播 `Anime.fromJson` 抛出的任何异常（如缺失 `id`）——这一层没有逐记录错误隔离。
