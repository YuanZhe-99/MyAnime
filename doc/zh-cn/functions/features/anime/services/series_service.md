# lib/features/anime/services/series_service.dart

系列关联（1.6.0）：把片库分组为系列、并计算用户整理操作所产生编辑的纯 Dart 引擎。`SeriesIndex.build` 按需对整个片库分组，不写入任何内容；`SeriesEditor` 把每个整理操作变成要写入的记录列表，由调用方经 `AnimeStorage.addOrUpdateAll`（[`anime_storage.md`](anime_storage.md#addorupdateall)）持久化；`NextSeasonPrefill` 把"添加下一季"带到新建页。存储的字段是 `Anime.seriesLink`（[`../models/anime.md`](../models/anime.md#animeserieslink-new)）；季相关辅助函数来自 [`../../../shared/utils/season_label.md`](../../../shared/utils/season_label.md)，标题归一化与相似度来自 [`anime_search_service.md`](anime_search_service.md)。其上的界面是 [`../views/series_widgets.md`](../views/series_widgets.md)。概念、规则与实际行为见 [`../../../../features/series-linking.md`](../../../../features/series-linking.md)。测试：`test/series_service_test.dart`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `SeriesEdgeKind(...)` | 枚举构造函数（`SeriesEdgeKind`） | B | 创建带相对强度 `strength` 的边类型（`relation` 3、`legacy` 2、`baseTitle` 1）。 |
| `AnimeSeries(...)` | 构造函数（`AnimeSeries`） | B | 由键、可选 `seriesId` 与有序成员创建系列；只由 `SeriesIndex.build` 构建。 |
| `isCurated` | getter（`AnimeSeries`） | B | 该系列是否由用户创建（`seriesId != null`）。 |
| `indexOfId` | 方法（`AnimeSeries`） | B | 成员从 0 开始的位置，或 `-1`。 |
| `previousOf` | 方法（`AnimeSeries`） | B | 某记录之前的成员，或 `null`；驱动上一季按钮。 |
| `nextOf` | 方法（`AnimeSeries`） | B | 某记录之后的成员，或 `null`；驱动下一季按钮。 |
| `SeriesSuggestion(...)` | 构造函数（`SeriesSuggestion`） | B | 创建建议：一条记录及其最佳基础键相似度。 |
| `SeriesIndex._` | 构造函数（`SeriesIndex`） | B | 由预先计算的部分构建的内部构造函数；请用 `SeriesIndex.build`。 |
| [`SeriesIndex.build`](#seriesindex-build) | 工厂构造函数 | A | 把整个片库分组为手动关联的系列与自动归入的系列。 |
| [`_ordered`](#_ordered) | 静态方法（`SeriesIndex`） | A | 为一个系列的成员排序。 |
| [`seriesOf`](#seriesof) | 方法（`SeriesIndex`） | A | 返回记录所属的系列。 |
| `animeById` | 方法（`SeriesIndex`） | B | 按 id 查找记录。 |
| `all` | getter（`SeriesIndex`） | B | 构建索引所用的每条记录，按 `id` 排序；管理面板在其中搜索。 |
| [`suggestionsFor`](#suggestionsfor) | 方法（`SeriesIndex`） | A | 提供可能属于同一系列的记录，但从不关联它们。 |
| [`seriesTitlesOf`](#seriestitlesof) | 顶层函数 | A | 收集一条记录的每个非空标题。 |
| [`seriesBaseKeys`](#seriesbasekeys) | 顶层函数 | A | 计算同一作品两季共享的基础键。 |
| [`seriesOrdinalOf`](#seriesordinalof) | 顶层函数 | A | 返回系列分组用于给记录排序的季数序数。 |
| [`SeriesEditor(...)`](#serieseditor) | 构造函数（`SeriesEditor`） | A | 在一个索引上创建编辑器，时钟与 id 生成器可注入。 |
| `_write` | 方法（`SeriesEditor`） | B | 返回带新系列链接（或不带）的记录，标记 `modifiedAt = now`。 |
| [`materialise`](#materialise) | 方法（`SeriesEditor`） | A | 给系列的每个成员写入同一个手动关联的 `seriesId`。 |
| [`link`](#link) | 方法（`SeriesEditor`） | A | 把一条记录放进另一条记录所属的系列。 |
| [`removeFromSeries`](#removefromseries) | 方法（`SeriesEditor`） | A | 把记录移出所有系列（`standalone`）。 |
| [`letAppDecide`](#letappdecide) | 方法（`SeriesEditor`） | A | 把记录交还给自动分组。 |
| [`reorder`](#reorder) | 方法（`SeriesEditor`） | A | 重排系列，给每个成员写入连续的 `order`。 |
| `NextSeasonPrefill(...)` | 构造函数（`NextSeasonPrefill`） | B | 创建预填：复制的标题、季标签，以及保存时要关联的 id。 |
| [`NextSeasonPrefill.after`](#nextseasonprefill) | 工厂构造函数 | A | 为某条记录的下一季构建预填。 |

`seriesSuggestionMinScore`（`0.6`）与 `seriesSuggestionMinOrderedScore`（`0.5`）常量、`SeriesEdgeKind` 的各个值以及各类的字段都没有 `/// Purpose:` 注释，不作为行索引。

## 文档

### `factory SeriesIndex.build(Iterable<Anime> library)` <a id="seriesindex-build"></a>
- **种类：** `SeriesIndex` 的工厂构造函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 145 行）
- **用途：** 把整个片库分组为系列。
- **输入：** `library` — 每条动画记录。
- **返回：** `SeriesIndex` — 每个手动关联的系列（包括只有一个成员的）和每个至少两个成员的自动归入的系列，按键（`series:<seriesId>` 或 `auto:<最小成员 id>`）排序。
- **副作用：** 无；不写入任何内容。
- **算法：**
  1. 按 `id` 排序记录，预先计算每条记录的基础键（[`seriesBaseKeys`](#seriesbasekeys)）和序数（[`seriesOrdinalOf`](#seriesordinalof)）。
  2. 划分：独立（不归入系列）的记录完全跳过；带 `seriesLink.curatedSeriesId` 的记录放进各自的手动关联的系列；其余都是**自动**记录。
  3. 把每条自动记录和手动关联记录按修剪后的 `displayTitle` 和基础键放进哈希表索引。
  4. 为每条自动记录添加边：与 `displayTitle` 完全相同、修剪后 `season` 标签不同的每条记录之间加 **legacy** 边；与共享某个基础键的每条记录之间加 **base title** 边，除非这一对看起来是重复条目（序数相同，且 `firstAirDate` 同一天或有一方没有 `firstAirDate`）。连到另一条自动记录的边把两者合并（并查集，较小的根 id 胜出）；连到手动关联记录的边按手动关联的系列分别记录见过的最强边类型。
  5. 对每个自动连通分量，取其到每个手动关联的系列的最强边。若恰好一个手动关联的系列持有最高强度，整个分量加入它；平局时不加入任何系列。
  6. 没有加入任何系列、且至少两个成员的分量成为自动归入的系列。
  7. 用 [`_ordered`](#_ordered) 为每个系列的成员排序。
- **用法：**
  ```dart
  final index = SeriesIndex.build(data.animeList);
  final series = found == null ? null : index.seriesOf(found.id);
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，`_load`；`anime_edit_page.dart` 的 `_saveNew` 也使用）
- **备注：** 确定性——同样的记录以任意顺序输入都得到同样顺序的同样系列，因此每台设备从同样的数据算出同样的分组。手动关联的系列从不移动、从不融合：自动分组只挂接自动记录，平局则什么都不挂接。`SeriesEdgeKind.relation` 边（强度 3）是为 M2 的资料库关联关系定义的，但目前还没有任何代码添加它。哈希表索引使构建大致与片库规模成线性关系。

### `static List<Anime> _ordered(List<Anime> members, String? seriesId, Map<String, int> ordinals)` <a id="_ordered"></a>
- **种类：** `SeriesIndex` 的静态方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 299 行）
- **用途：** 为一个系列的成员排序。
- **输入：** `members`；`seriesId` — 手动关联的 id，自动归入的系列为 `null`；`ordinals` — 预先计算的季数序数。
- **返回：** `List<Anime>` — 排好序的副本。
- **副作用：** 无。
- **算法：** `seriesLink.order` 属于*本*手动关联的系列的成员排在最前，升序。其余依次按 `firstAirDate`（缺失者排后）、季数序数、`createdAt`、`id` 排序。
- **备注：** 只有当一条自动记录在重排之后才加入系列时才会出现混合状态（部分成员有顺序、部分没有）；它排在末尾，用户可以再移动它。因为序数是数字，`Season 2` 排在 `Season 10` 之前。

### `AnimeSeries? seriesOf(String animeId)` <a id="seriesof"></a>
- **种类：** `SeriesIndex` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 342 行）
- **用途：** 返回记录所属的系列。
- **返回：** `AnimeSeries?` — 独立（不归入系列）的记录或没有加入任何系列的记录为 `null`。
- **副作用：** 无。
- **备注：** 只有一个成员的手动关联的系列仍会返回；详情页只在系列至少有两个成员时显示系列卡片。

### `List<SeriesSuggestion> suggestionsFor(String animeId, {int limit = 8})` <a id="suggestionsfor"></a>
- **种类：** `SeriesIndex` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 367 行）
- **用途：** 提供可能与 `animeId` 属于同一系列的记录。
- **输入：** `animeId`；`limit` — 最多返回这么多条（默认 8）。
- **返回：** `List<SeriesSuggestion>` — 分数高者在前（同分按 `id`），不含记录自己的系列和记录本身。
- **副作用：** 无。
- **算法：** 对每条其他记录比较每一对基础键。只有 `AnimeSearchService.orderedSimilarity` 达到 `seriesSuggestionMinOrderedScore`（0.5）的键对才计入；记录的分数是计入键对中最高的 `similarityRaw`，达到 `seriesSuggestionMinScore`（0.6）即入选。
- **用法：** 管理面板的*建议*一节（[`../views/series_widgets.md`](../views/series_widgets.md#seriesmanagesheet)）。
- **备注：** 建议从不是自动关联。它们捕捉基础键抓不到、又不宜自动关联的配对——`Love Live!` 就是这样找到 `Love Live! Sunshine!!` 的。顺序感知的下限阻止仅仅共享字母的短拉丁键被推荐。

### `List<String> seriesTitlesOf(Anime anime)` <a id="seriestitlesof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 406 行）
- **用途：** 收集一条记录的每个非空标题。
- **返回：** `List<String>` — `title`、`titleJa`、`externalMeta.titleRomaji`、`externalMeta.titleEn`，然后是每个 `externalMeta.synonyms` 条目，空白者去掉。
- **副作用：** 无。
- **用法：** [`seriesBaseKeys`](#seriesbasekeys)、[`seriesOrdinalOf`](#seriesordinalof) 以及管理面板的片库搜索。

### `Set<String> seriesBaseKeys(Anime anime)` <a id="seriesbasekeys"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 434 行）
- **用途：** 计算同一作品两季共享的基础键。
- **返回：** `Set<String>` — 对 [`seriesTitlesOf`](#seriestitlesof) 中每个标题取 `AnimeSearchService.foldTitle(stripSeasonMarkers(t))`，只保留至少 2 个汉字或假名、或至少 4 个拉丁字母或数字的键。
- **副作用：** 无。
- **备注：** 长度下限防止一个两字母的英文标题与所有归一化后为同样两个字母的标题连在一起。见 [`stripSeasonMarkers`](../../../shared/utils/season_label.md#stripseasonmarkers)。

### `int seriesOrdinalOf(Anime anime)` <a id="seriesordinalof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 453 行）
- **用途：** 返回系列分组用于给记录排序的季数序数。
- **返回：** `int` — 任一标题暗示的第一个序数（[`titleSeasonOrdinal`](../../../shared/utils/season_label.md#titleseasonordinal)），否则取 `season` 标签中的序数（`halfWidthAscii` 之后的 `seasonOrdinal`），否则为 `1`。
- **副作用：** 无。
- **备注：** 标题优先，因为多数用户从不改动默认的 `Season 1` 标签。没有编号的最终季读作 `finalSeasonOrdinal`（99）。

### `SeriesEditor(SeriesIndex index, {DateTime? now, String Function()? newId})` <a id="serieseditor"></a>
- **种类：** `SeriesEditor` 的构造函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 479 行）
- **用途：** 创建系列编辑器：基于一个索引的纯整理操作。
- **输入：** `index`；`now` — 默认为当前时间，存为 UTC；`newId` — 默认为小写 UUID v4。
- **返回：** 新的 `SeriesEditor`。
- **副作用：** 无。
- **用法：**
  ```dart
  final writes = SeriesEditor(index).link(anime, source);
  await AnimeStorage.addOrUpdateAll(writes.isEmpty ? [anime] : writes);
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，`_saveNew`）
- **备注：** 每个操作都返回要写入的记录，自身什么都不写；从不在后台写入。每条返回的记录都经 `_write` 标记 `modifiedAt = now`，因此每条都是同步眼中的普通用户编辑。`now` 与 `newId` 可为测试注入。

### `(String, Map<String, Anime>) materialise(AnimeSeries series)` <a id="materialise"></a>
- **种类：** `SeriesEditor` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 502 行）
- **用途：** 给系列的每个成员写入同一个手动关联的 `seriesId`。
- **输入：** `series`。
- **返回：** `(String, Map<String, Anime>)` — 系列 id，以及按 id 索引的发生变化的记录。
- **副作用：** 无。
- **算法：** 使用系列自己的 `seriesId`，自动归入的系列则用新 id。尚未带该手动关联 id 的每个成员得到 `AnimeSeriesLink(seriesId: sid)`，保留其链接的 `extraJson`。
- **备注：** 只由用户操作调用——[`link`](#link)、[`reorder`](#reorder)。对手动关联的系列，它不动既有成员（及其 `order`），并把此前挂接上的自动记录固定下来。

### `List<Anime> link(Anime record, Anime target)` <a id="link"></a>
- **种类：** `SeriesEditor` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 526 行）
- **用途：** 把 `record` 放进 `target` 所属的系列。
- **输入：** `record` — 可以是尚未进入索引的新记录；`target`。
- **返回：** `List<Anime>` — 要写入的记录；`record` 与 `target` 相同时为空。
- **副作用：** 无。
- **算法：**
  1. `target` 在某个系列中时，[`materialise`](#materialise) 该系列；否则给 `target` 写入新 id，开始一个新的手动关联的系列。
  2. 给 `record` 写入 `AnimeSeriesLink(seriesId: sid)`（保留其链接的 `extraJson`），除非它已经带着这个手动关联 id 且不在固化的写入中。
- **用法：** 管理面板（点按建议或搜索结果）以及新建页的 `_saveNew`。
- **备注：** `record` 失去 `standalone` 和任何 `order`，因此在用户重排之前排在有顺序的成员之后。与 `record` 之间有边的自动记录可能在下次构建时跟着它进入该系列——这是可见行为，记录在 [`../../../../features/series-linking.md`](../../../../features/series-linking.md)。

### `List<Anime> removeFromSeries(Anime record)` <a id="removefromseries"></a>
- **种类：** `SeriesEditor` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 564 行）
- **用途：** 把记录移出所有系列。
- **返回：** `List<Anime>` — 唯一的那条记录，现在是 `{"standalone": true}`（保留其链接的 `extraJson`）。
- **副作用：** 无。
- **备注：** 其余成员保持不变。独立（不归入系列）的记录没有边，因此既不加入系列，也不吸引其他记录。

### `List<Anime> letAppDecide(Anime record)` <a id="letappdecide"></a>
- **种类：** `SeriesEditor` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 580 行）
- **用途：** 把记录交还给自动分组。
- **返回：** `List<Anime>` — 记录没有链接时为空；否则是移除了 `seriesLink` 的记录。
- **副作用：** 无。
- **备注：** 旧链接的未知字段以字段全空的 `AnimeSeriesLink(extraJson: …)` 保留下来，因此较新版本的数据不会丢失。

### `List<Anime> reorder(AnimeSeries series, List<String> orderedIds)` <a id="reorder"></a>
- **种类：** `SeriesEditor` 的方法
- **来源：** `lib/features/anime/services/series_service.dart`（第 596 行）
- **用途：** 重排系列。
- **输入：** `series`；`orderedIds` — 按新顺序排列的成员 id。非成员 id 被忽略；未列出的成员按现有相对顺序排在已列出者之后。
- **返回：** `List<Anime>` — 链接发生变化的每个成员。
- **副作用：** 无。
- **算法：** [`materialise`](#materialise)，然后给每个成员写入从 1 开始的连续 `order`，已在本系列中恰好处于该位置的成员跳过。
- **用法：** 管理面板的*保存顺序*按钮。

### `factory NextSeasonPrefill.after(Anime source)` <a id="nextseasonprefill"></a>
- **种类：** `NextSeasonPrefill` 的工厂构造函数
- **来源：** `lib/features/anime/services/series_service.dart`（第 653 行）
- **用途：** 为 `source` 的下一季构建预填。
- **输入：** `source` — 通常是其系列的最后一个成员。
- **返回：** `NextSeasonPrefill` — `source` 的 `title` 和 `titleJa`、下一季标签，以及 `linkToAnimeId = source.id`。
- **副作用：** 无。
- **算法：** 比较标题序数（[`seriesOrdinalOf`](#seriesordinalof)）与标签自身的 `seasonOrdinal`：
  - 没有编号的最终季（序数 99）之后，原样复制标签；
  - 两者一致时，[`nextSeasonLabel`](../../../shared/utils/season_label.md#nextseasonlabel) 以标签自身的风格递增（`第一季` → `第二季`），失败时回退到 `Season <序数 + 1>`；
  - 否则用 `Season <序数 + 1>`，因为标签已过时（典型情况是标题写着 Season 2 的记录仍带默认的 `Season 1`）。
- **用法：**
  ```dart
  await context.push('/anime/edit', extra: NextSeasonPrefill.after(last));
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，`_runSeriesAction`）
- **备注：** 预填作为路由的 `extra` 传递（见 [`../../../app/router.md`](../../../app/router.md)）；它携带的关联只在新记录保存时写入（[`../views/anime_edit_page.md`](../views/anime_edit_page.md#_savenew)）。
