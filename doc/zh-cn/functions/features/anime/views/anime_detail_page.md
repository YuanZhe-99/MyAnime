# lib/features/anime/views/anime_detail_page.dart

`AnimeDetailPage` 是一部被跟踪动画的读/操作页：封面、元数据徽章、评分摘要、上一季/下一季导航，以及带日程偏移控件的逐集观看状态列表。它通过 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）读写，并操作 `Anime`/`AnimeRating` 模型（[`../models/anime.md`](../models/anime.md)）。本页为剧集播出日期/回卷和日程偏移语义暴露的控件见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AnimeDetailPage.new` | 构造函数（`AnimeDetailPage`） | B | 为给定动画 ID 创建 `AnimeDetailPage` 实例。 |
| `AnimeDetailPage.createState` | 方法（`AnimeDetailPage`） | B | 为此组件创建可变状态对象。 |
| `_AnimeDetailPageState.initState` | 方法（`_AnimeDetailPageState`） | B | 触发首次数据加载。 |
| [`_load`](#_load) | 方法（`_AnimeDetailPageState`） | A | 从存储加载此动画并定位它的上一季/下一季。 |
| [`_toggleEpisode`](#_toggleepisode) | 方法（`_AnimeDetailPageState`） | A | 循环一集的观看状态并持久化它。 |
| [`_shiftFromEpisode`](#_shiftfromepisode) | 方法（`_AnimeDetailPageState`） | A | 把一集的播出周偏移一个增量并持久化它。 |
| [`_resetSchedule`](#_resetschedule) | 方法（`_AnimeDetailPageState`） | A | 清除所有逐集周偏移，恢复到原始日程。 |
| [`_delete`](#_delete) | 方法（`_AnimeDetailPageState`） | A | 确认并删除这条动画记录。 |
| `_AnimeDetailPageState.build` | 方法（`_AnimeDetailPageState`，组件构建） | B | 构建详情页脚手架（封面、信息、剧集列表）。 |
| [`_toggleAllWatched`](#_toggleallwatched) | 方法（`_AnimeDetailPageState`） | A | 把每个被跟踪剧集标记为已看，已完整时则全部标记为未看。 |
| `_buildAbandonOrResume` | 方法（组件辅助） | B | 渲染剧集列表页头的"放弃"/"恢复"操作按钮。 |
| `_buildRatingCard` | 方法（组件辅助） | B | 渲染评分摘要卡片。 |
| `_formatScore` | 方法（`_AnimeDetailPageState`） | B | 分数为整数时格式化为整数，否则保留一位小数。 |
| [`_abandonAnime`](#_abandonanime) | 方法（`_AnimeDetailPageState`） | A | 把每个剩余未看剧集标记为跳过。 |
| [`_resumeAnime`](#_resumeanime) | 方法（`_AnimeDetailPageState`） | A | 把每个跳过剧集还原为未看。 |
| `_typeLabel` | 方法（`_AnimeDetailPageState`） | B | 本地化 `AnimeType` 值供显示。 |
| `_dayName` | 方法（`_AnimeDetailPageState`） | B | 本地化星期几数字供显示。 |
| `_statusIcon` | 方法（`_AnimeDetailPageState`） | B | 为一集的观看状态选前置图标。 |
| `_statusLabel` | 方法（`_AnimeDetailPageState`） | B | 本地化一集的观看状态供显示。 |
| `_statusColor` | 方法（`_AnimeDetailPageState`） | B | 为一集的观看状态选显示颜色。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 55 行）
- **用途：** 从存储加载 `widget.animeId` 标识的动画，找到时定位最近的上一季和下一季"季"记录（相同 `displayTitle`、不同 `season` 字符串），供上一季/下一季导航按钮使用。
- **输入：** 无（`widget.animeId` 从外层组件读取）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.load()`；`setState` `_anime`、`_prevSeasonId`、`_nextSeasonId`。
- **算法：**
  1. Await `AnimeStorage.load()` 并找 `id == widget.animeId` 的记录。
  2. 找到时，收集共享同一 `displayTitle` 的每条其他记录，按 `season` 字符串比较排序该子集。
  3. 遍历排序后的子集一次，找 `season` 小于当前季的最近一个（`prev`，持续更新使*最后一个*符合条件的条目——最接近的下方——胜出），再遍历一次找 `season` 大于当前季的最近一个（`next`，在*第一个*符合条件的条目——最接近的上方——`break`）。
  4. 用找到的动画和两个邻居 ID（未找到时只用动画）`setState`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  （`_AnimeDetailPageState.initState`，同一文件；编辑/删除/剧集操作后也调用它刷新页面）
- **备注：** `season` 比较是普通 `String.compareTo`，因此季标签需要作为字符串正确排序（如 `"Season 2"` 按字典序 > `"Season 10"`）——本页不做数字感知的季排序。

### `Future<void> _toggleEpisode(int ep)` <a id="_toggleepisode"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 95 行）
- **用途：** 把一集的观看状态推进到循环中的下一个状态并持久化它。
- **输入：** `ep` — 要切换的集编号。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. 读取该集的当前状态（缺失则为 `unwatched`）。
  2. 循环它：`unwatched` → `watched` → `skippedThisWeek` → `unwatched`。
  3. 用更新后的 `episodeStatuses` 映射和新 `modifiedAt` `copyWith` 该动画，经 `AnimeStorage.addOrUpdate` 保存，然后 `_load()`。
- **用法：**
  ```dart
  onTap: () => _toggleEpisode(ep),
  ```
  （`_AnimeDetailPageState.build`，剧集列表块）
- **备注：** 三态循环（而不是普通已看/未看切换）让单次点击能把一集标记为刻意跳过，与只是尚未观看区分开——该区分如何影响别处显示的派生状态见 [`viewingStatus`](../models/anime.md#viewingstatus)。

### `Future<void> _shiftFromEpisode(int ep, int delta)` <a id="_shiftfromepisode"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 123 行）
- **用途：** 把第 `ep` 集（以及累计地、之后每一集）向前或向后偏移 `delta` 周。
- **输入：** `ep` — 偏移条目被调整的集编号；`delta` — 要加的周数（正为延期，负为提前）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. 复制 `episodeWeekOffsets`，给 `ep` 的既有条目加 `delta`（或从 `0` 开始）。
  2. 结果为 `0` 时完全移除该条目（保持映射精简）。
  3. 经 `copyWith(episodeWeekOffsets: ..., modifiedAt: DateTime.now().toUtc())` 和 `AnimeStorage.addOrUpdate` 持久化，然后 `_load()`。
- **用法：**
  ```dart
  icon: const Icon(Icons.keyboard_double_arrow_left),
  onPressed: () => _shiftFromEpisode(ep, -1),
  ```
  （`_AnimeDetailPageState.build`，逐集偏移按钮）
- **备注：** 因为 [`weekOffsetFor`](../models/anime.md#weekoffsetfor) 对每个键 `<= episodeNumber` 的偏移条目求和，存在第 `ep` 集上的偏移会同时偏移之后的每一集，不只是 `ep` 本身——见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

### `Future<void> _resetSchedule()` <a id="_resetschedule"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 141 行）
- **用途：** 用户确认后清除每个逐集周偏移，恢复由 `firstAirDate` 派生的原始日程。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示确认 `AlertDialog`；调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. 显示确认对话框；用户未确认则提前返回。
  2. `copyWith(episodeWeekOffsets: {}, modifiedAt: ...)`，经 `AnimeStorage.addOrUpdate` 保存，`_load()`。
- **用法：**
  ```dart
  onPressed: () => _resetSchedule(),
  ```
  （`_AnimeDetailPageState.build`，只在 `anime.episodeWeekOffsets.isNotEmpty` 时显示）
- **备注：** 这会一次清除所有累积偏移——没有逐集撤销，只有全有或全无的重置。

### `Future<void> _delete()` <a id="_delete"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 175 行）
- **用途：** 用户确认后删除当前显示的动画记录，然后离开页面。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示确认对话框（`confirmDelete`）；调用 `AnimeStorage.deleteAnime`；弹出当前路由。
- **算法：**
  1. `_anime` 为 `null` 时提前返回。
  2. Await `confirmDelete(context, _anime!.displayTitle)`；拒绝则返回。
  3. `AnimeStorage.deleteAnime(_anime!.id)`，仍 mounted 时 `context.pop()`。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.delete_outline),
    onPressed: _delete,
  ),
  ```
  （`_AnimeDetailPageState.build`，应用栏操作）
- **备注：** 与剧集/日程变更器不同，这之后不调用 `_load()`——页面被弹出，因为它的主体已不存在。

### `Future<void> _toggleAllWatched()` <a id="_toggleallwatched"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 457 行）
- **用途：** 一次操作把每个被跟踪剧集标记为已看，动画已完整时则全部标记为未看（在整系列层面充当切换）。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. `_anime` 为 `null` 或没有 `endEpisode`（开放结局系列不能"全部已看"）时提前返回。
  2. 读 `isCompleted`（见 [`../models/anime.md#iscompleted`](../models/anime.md#iscompleted)）决定方向。
  3. 循环 `startEpisode..endEpisode`，把每集状态设为 `unwatched`（已完整时）或 `watched`（否则）。
  4. 经 `copyWith(episodeStatuses: ..., modifiedAt: ...)` 持久化并 `_load()`。
- **用法：**
  ```dart
  TextButton(
    onPressed: () => _toggleAllWatched(),
    child: Text(
      anime.isCompleted
          ? l10n.animeMarkAllUnwatched
          : l10n.animeMarkAllWatched,
    ),
  ),
  ```
  （`_AnimeDetailPageState.build`，剧集列表页头）
- **备注：** 无条件地向一个方向覆盖每集状态——任何单独 `skippedThisWeek` 的剧集也会被这个操作扫进 `watched`/`unwatched`。

### `Future<void> _abandonAnime()` <a id="_abandonanime"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 595 行）
- **用途：** 把每个当前未看的被跟踪剧集标记为 `skippedThisWeek`，实际就是放弃追赶剩余积压。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. `_anime` 为 `null` 或没有 `endEpisode` 时提前返回。
  2. 循环 `startEpisode..endEpisode`；任何状态为（或默认为）`unwatched` 的剧集变成 `skippedThisWeek`。已 `watched` 的剧集不动。
  3. 持久化并重载。
- **用法：**
  ```dart
  return TextButton(
    onPressed: () => _abandonAnime(),
    child: Text(l10n.animeAbandon),
  );
  ```
  （`_buildAbandonOrResume`，至少一集仍未看时显示）
- **备注：** 按 [`viewingStatus`](../models/anime.md#viewingstatus)，把每个未看剧集变成 `skippedThisWeek`（零剩余 `unwatched`）正是让动画在应用别处读作 `dropped` 的东西。

### `Future<void> _resumeAnime()` <a id="_resumeanime"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 617 行）
- **用途：** 逆转 `_abandonAnime`——把每个 `skippedThisWeek` 剧集还原为 `unwatched`，使系列可以重新捡起。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：**
  1. `_anime` 为 `null` 或没有 `endEpisode` 时提前返回。
  2. 循环 `startEpisode..endEpisode`；任何状态恰好为 `skippedThisWeek` 的剧集变成 `unwatched`。`watched` 剧集不动。
  3. 持久化并重载。
- **用法：**
  ```dart
  return TextButton(
    onPressed: () => _resumeAnime(),
    child: Text(l10n.animeResume),
  );
  ```
  （`_buildAbandonOrResume`，没有剩余未看剧集但至少一个跳过时显示）
- **备注：** `_buildAbandonOrResume` 一次最多显示放弃/恢复按钮之一——既有未看又有跳过剧集时放弃优先。
