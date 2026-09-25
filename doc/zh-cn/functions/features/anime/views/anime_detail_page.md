# lib/features/anime/views/anime_detail_page.dart

`AnimeDetailPage` 是一部被跟踪动画的读/操作页：封面、一行信息行和操作行、评分摘要、本地存档摘要、带上一季/下一季导航的系列卡片，以及带日程偏移控件的逐集观看状态列表。它通过 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）读写，并操作 `Anime`/`AnimeRating`/`AnimeLocalArchive` 模型（[`../models/anime.md`](../models/anime.md)），存档枚举通过 [`archive_labels.md`](archive_labels.md) 渲染。存档卡片仅供展示，且刻意不出现在本页分享操作生成的分享图片卡片中——见 [`../../../../features/share-and-import.md`](../../../../features/share-and-import.md)。本页为剧集播出日期/回卷和日程偏移语义暴露的控件见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。


## 布局

页面以两种布局之一渲染，每帧由 [`../../../shared/utils/detail_layout.md`](../../../shared/utils/detail_layout.md) 中的 `useDetailTwoPane` 依视口尺寸选定：

- **单栏** — 一个 `ListView`：封面，然后是信息块（日文标题、信息行、操作行、分类标签、进度条、`已看 / 总数`、评分／资料库／存档卡片、备注、系列卡片与上下季导航），最后是剧集列表。这就是原本的布局，未作改动。
- **双栏** — 一个 `Row`。左栏定宽且占满高度，容纳从封面到观看进度标签的内容，封面尺寸由 `detailCoverSize` 按剩余高度算出。右栏是独立滚动的 `ListView`，容纳从卡片往下的全部内容，包括系列卡片和剧集列表。

系列卡片（1.6.0，[`series_widgets.md`](series_widgets.md) 中的 `SeriesCard`）在 `_buildDetailChildren` 中取代了原来的上一季/下一季行，位置不变，因此在双栏布局中它落在右栏。只有记录所属系列至少有两个成员时才会出现；其下方的上一季/下一季按钮现在由系列顺序驱动，放在 `Wrap` 中，窄屏手机上会换行堆叠而不会溢出。自 1.6.1 起，成员行和上一季/下一季按钮用 `context.push` 打开另一条记录的详情页，而不是 `context.go` 过去，因此返回会回到用户来时的记录。记录不属于任何系列（包括独立（不归入系列）的记录）时，卡片不出现，改由应用栏的关联菜单（*关联到系列…*、*添加下一季*，记录带 `seriesLink` 时还有*交给应用自动判断*）提供相同操作。系列卡片正上方是缺失续作提示（1.6.0 M2）：当资料库列出了系列最后一个成员的某部续作、而片库中没有它时，显示一张写着「下一部：<标题>（<来源>）」的卡片。与系列卡片不同，记录不在任何系列中时它也会出现。自 1.6.3 起，提示以续作抓取到的缩略图作为前置图片，并显示至多三行简介，二者都从 `recommendations.json` 读取（见 [`../../recommendations/services/sequel_info_service.md`](../../recommendations/services/sequel_info_service.md)）。见 [`../../../../features/series-linking.md`](../../../../features/series-linking.md)。

### 头部（1.6.3）

1.6.2 及之前，`_buildHeaderChildren` 渲染一个 `Wrap`，其中有至多八个标签——季、长度类型、星期、时间、*信息*、*刷新资料库信息*、*观看*和 anime1.me 进度——事实与操作看起来一模一样，后面是分类标签和一个*编辑分类*标签。在手机上这会占满四行。自 1.6.3 起，头部从上到下依次为：

| 行 | 内容 | 构建者 |
|---|---|---|
| 日文标题 | `titleJa`（已设置时） | `_buildHeaderChildren` |
| 信息行 | 一个 `onSurfaceVariant` 颜色的 `Text`：`Season 2 · Single Cour · Sun · 21:00`，缺少的部分略去 | `_infoLine` |
| 操作行 | *观看*是唯一带文字的 `FilledButton.tonalIcon`；anime1.me 进度是一个 `TextButton.icon`；*信息*和*刷新资料库信息*是描边图标按钮，文字作为提示 | `_buildHeaderActions` |
| 分类 | 紧凑的标签，然后是一个编辑图标按钮（提示*编辑分类*） | `CategoryChips` |
| 进度 | 进度条和 `已看 / 总数` | `_buildHeaderChildren` |

记录没有任何操作时省略操作行。构建风味门禁不变：*刷新资料库信息*和 anime1.me 重新检查只在完整版中提供，已保存的 anime1.me 进度在每种构建风味下都显示。

推荐开启时（1.6.2），`_buildDetailChildren` 把**相关推荐**卡片（`RelatedRecommendationsCard`，[`../../recommendations/views/related_card.md`](../../recommendations/views/related_card.md)）放在备注之后、缺失续作提示之前，因此在双栏布局中它落在右栏。它以记录 id 为键，接收 `_load` 读取的片库，并自行负责加载、持久保存、换一批和垃圾箱；页面只决定它是否出现。见 [`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#详情页的相关推荐)。

自动分类开启时（1.6.0 M4），`_buildHeaderChildren` 会在操作行与进度条之间加一行分类标签（[`category_widgets.md`](category_widgets.md) 中的 `CategoryChips`），因此在双栏布局中它们留在左栏。其中的编辑按钮打开分类编辑器。见 [`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

两种布局都由同样四个构建函数拼装——`_buildCover`、`_buildHeaderChildren`、`_buildDetailChildren`、`_buildEpisodeChildren`——因此每个区块的组件代码只有一份。`_buildHeaderChildren` 与 `_buildDetailChildren` 之间的分界**就是**分栏边界：把某个区块移过这条缝，它就会换栏。`_buildDetailChildren` 中每一项都自带前置的 `SizedBox(height: 12)`，正是这一点让同一份列表无论跟在进度条之后还是作为右栏开头都能正确呈现。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AnimeDetailPage.new` | 构造函数（`AnimeDetailPage`） | B | 为给定动画 ID 创建 `AnimeDetailPage` 实例。 |
| `AnimeDetailPage.createState` | 方法（`AnimeDetailPage`） | B | 为此组件创建可变状态对象。 |
| `_AnimeDetailPageState.initState` | 方法（`_AnimeDetailPageState`） | B | 触发首次数据加载。 |
| [`_load`](#_load) | 方法（`_AnimeDetailPageState`） | A | 加载此动画并构建系列分组，找到它所属的系列。 |
| [`didUpdateWidget`](#didupdatewidget) | 方法（`_AnimeDetailPageState`） | A | 页面为另一条记录重建时重新加载。 |
| [`_editCategories`](#_editcategories) | 方法（`_AnimeDetailPageState`） | A | 让用户设置本记录的分类。 |
| [`_addMissingSequel`](#_addmissingsequel) | 方法（`_AnimeDetailPageState`） | A | 为资料库列出、但片库中没有的续作打开新建页。 |
| [`_runSeriesAction`](#_runseriesaction) | 方法（`_AnimeDetailPageState`） | A | 运行系列卡片（或应用栏关联菜单）中的某个操作。 |
| [`_toggleEpisode`](#_toggleepisode) | 方法（`_AnimeDetailPageState`） | A | 循环一集的观看状态并持久化它。 |
| [`_shiftFromEpisode`](#_shiftfromepisode) | 方法（`_AnimeDetailPageState`） | A | 把一集的播出周偏移一个增量并持久化它。 |
| [`_resetSchedule`](#_resetschedule) | 方法（`_AnimeDetailPageState`） | A | 清除所有逐集周偏移，恢复到原始日程。 |
| [`_delete`](#_delete) | 方法（`_AnimeDetailPageState`） | A | 确认并删除这条动画记录。 |
| `_AnimeDetailPageState.build` | 方法（`_AnimeDetailPageState`，组件构建） | B | 构建详情页脚手架，并在单栏与双栏布局之间取舍。 |
| `_buildCover` | 方法（组件辅助） | B | 按明确尺寸构建封面图块。 |
| `_buildHeaderChildren` | 方法（组件辅助） | B | 构建头部块：日文标题、信息行、操作行、自动分类开启时的分类标签，以及已看集数条（1.6.3 布局）。 |
| `_infoLine` | 方法（`_AnimeDetailPageState`） | B | 把季标签、长度类型、星期和时间连成头部的信息行（1.6.3）。 |
| `_hasHeaderActions` | 方法（`_AnimeDetailPageState`） | B | 报告头部是否有任何可显示的操作（1.6.3）。 |
| `_buildHeaderActions` | 方法（组件辅助） | B | 构建操作行：*观看*、anime1.me 进度、*信息*和*刷新资料库信息*（1.6.3）。 |
| `_buildDetailChildren` | 方法（组件辅助） | B | 构建进度条下方的卡片，以及相关推荐卡片（1.6.2，推荐开启时）、缺失续作提示、系列卡片和上一季/下一季按钮。 |
| `_buildEpisodeChildren` | 方法（组件辅助） | B | 构建剧集列表表头及每一集一行。 |
| [`_toggleAllWatched`](#_toggleallwatched) | 方法（`_AnimeDetailPageState`） | A | 把每个被跟踪剧集标记为已看，已完整时则全部标记为未看。 |
| `_buildAbandonOrResume` | 方法（组件辅助） | B | 渲染剧集列表页头的"放弃"/"恢复"操作按钮。 |
| [`_refreshableUrls`](#_refreshableurls) | 方法（`_AnimeDetailPageState`） | A | 列出这部番剧可用于刷新的来源页面。 |
| [`_refreshExternalMeta`](#_refreshexternalmeta) | 方法（`_AnimeDetailPageState`） | A | 从每个已记住的来源页面重新抓取外部元数据。 |
| `_watchProgressChipLabel` | 方法（`_AnimeDetailPageState`） | B | 用已存的观看进度给 anime1.me 进度按钮取文案，否则用「查看」提示。 |
| [`_checkWatchProgress`](#_checkwatchprogress) | 方法（`_AnimeDetailPageState`） | A | 重新读取 anime1.me 为本记录 URL 列出的内容并存储。 |
| [`_buildExternalMetaCard`](#_buildexternalmetacard) | 方法（组件辅助） | A | 渲染从外部资料库拉取的公开元数据。 |
| `_buildRatingCard` | 方法（组件辅助） | B | 渲染用户自己的评分摘要卡片。 |
| `_buildLocalArchiveCard` | 方法（组件辅助） | B | 渲染只读的本地存档摘要卡片。 |
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
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 89 行）
- **用途：** 加载 `widget.animeId` 标识的动画及其所属的系列。
- **输入：** 无（`widget.animeId` 从外层组件读取）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups)`（1.6.1，可能在不改动 `modifiedAt` 的情况下改写默认季标签）、`AnimeStorage.getAutoCategoriesEnabled()`，仅在后者与端侧 AI（`AnimeStorage.getOnDeviceAiEnabled()`）都开启时调用 `AiInsightsCache.load()`，以及 `AnimeStorage.getRecommendationsEnabled()`（1.6.2）；`setState` `_anime`、`_seriesIndex`、`_series`、`_missingSequel`、`_sequelInfo`（1.6.3）、`_categoriesOn`、`_categories`、`_recommendationsOn` 和 `_library`。有缺失续作时读取 `recommendations.json`，并可能在完整版中经 `SequelInfoService.ensure` 抓取一次续作资料，这会写入该文件。相关推荐卡片自己写入 `recommendations.json`。
- **算法：**
  1. Await [`AnimeStorage.loadFixingSeasonLabels`](../services/anime_storage.md#loadfixingseasonlabels)`(seasonLabelFixups)` 并找 `id == widget.animeId` 的记录。
  2. 在整个片库上构建 [`SeriesIndex`](../services/series_service.md#seriesindex-build)，向它查询该记录的系列。
  3. 用记录、索引和系列 `setState`——但只在该系列至少有两个成员时；否则 `_series` 为 `null`，不显示系列卡片。同时把 [`missingSequelFor`](../services/series_service.md#missingsequelfor) 的结果存为 `_missingSequel`，由它驱动缺失续作提示。
  4. 把自动分类开关存为 `_categoriesOn`，把记录的 [`resolveCategories`](../../categories/services/category_service.md#resolvecategories) 结果（读取了 AI 缓存时带上缓存）存为 `_categories`。
  5.（1.6.3）有缺失续作时，把 `RecommendationStore.load()` 中的 `sequelInfo[sequelTrashKey(sequel)]` 存为 `_sequelInfo`。在完整版中，若尚未保存资料、且该卡片不在全局垃圾箱中，则 await [`SequelInfoService.ensure`](../../recommendations/services/sequel_info_service.md#ensure)，页面仍显示同一部续作时显示结果。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  （`_AnimeDetailPageState.initState`，同一文件；编辑/删除/剧集操作后也调用它刷新页面）
- **备注：** 1.6.0 之前，这里匹配 `displayTitle` 完全相同的记录，并用普通 `String.compareTo` 比较它们的 `season` 标签，结果把 `"Season 10"` 排在 `"Season 2"` 之前，而且标题稍有不同的续作永远找不到。现在不再比较字符串：顺序来自系列分组（显式 `order`，然后 `firstAirDate`、季数序数、`createdAt`、`id`），旧的相同标题规则只作为系列分组的一种边保留下来。见 [`../../../../features/series-linking.md`](../../../../features/series-linking.md)。自 1.6.1 起它经 `loadFixingSeasonLabels` 加载，因此标题指明后续季数的记录显示 `Season N`，而不是默认的 `Season 1`。

### `void didUpdateWidget(covariant AnimeDetailPage oldWidget)` <a id="didupdatewidget"></a>
- **种类：** `_AnimeDetailPageState` 的方法（Flutter 生命周期重写）
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 76 行）
- **用途：** 页面为另一条记录重建时重新加载。
- **输入：** `oldWidget`。
- **返回：** 无。
- **副作用：** `animeId` 改变时调用 [`_load`](#_load)。
- **备注：** 1.6.1 新增。`/anime/detail/:id` 路由以 `ValueKey(id)` 为页面设置 key（[`../../../app/router.md`](../../../app/router.md)），因此这只是一道保险：1.6.1 之前，在各季之间 `context.go` 会复用同一个 State，屏幕上一直停留在最先打开的记录。

### `Future<void> _editCategories()` <a id="_editcategories"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 108 行）
- **用途：** 让用户设置本记录的分类。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 可能调用 `AnimeStorage.addOrUpdate`（一次用户编辑，以 UTC 写入 `modifiedAt`）；经 `_load()` 重新加载。
- **算法：**
  1. 以当前生效的 id 和 `hasOverride: anime.categories != null` 打开 [`showCategoryEditor`](category_widgets.md#showcategoryeditor)。被关闭 → 返回。
  2. `CategoriesChosen(ids)` → `copyWith(categories: [...ids, ...unknown])`，其中 `unknown` 是记录自身列表中本构建不认识的每个 id，使较新构建的 id 得以保留。什么都不选时写入 `[]`。
  3. `CategoriesReset` → `copyWith(clearCategories: true)`，让记录回到自动分类。
  4. 用 `AnimeStorage.addOrUpdate` 保存，然后 `_load()`。
- **用法：** `_buildHeaderChildren` 中的 `CategoryChips(categories: _categories, onEdit: _editCategories)`。
- **备注：** 编辑器从*当前生效的* id 开始，因此不做改动直接保存，会把映射或 AI 得出的分类变成用户自己的分类。这次写入是普通的用户编辑，同步方式与其他编辑相同。

### `Future<void> _addMissingSequel(AnimeExternalRelation relation)` <a id="_addmissingsequel"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 93 行）
- **用途：** 为资料库列出、但片库中没有的续作打开新建页。
- **输入：** `relation` —— 来自 `_missingSequel` 的 `sequel`。
- **返回：** `Future<void>`。
- **副作用：** 推入 `/anime/edit`；返回后经 `_load()` 重新加载。
- **算法：** 没有 `_anime` 时提前返回；否则执行 `context.push('/anime/edit', extra: NextSeasonPrefill.fromRelation(last, relation))`，其中 `last` 是系列的最后一个成员（没有系列时为本记录）。
- **用法：** `_buildDetailChildren`（同一文件）中缺失续作提示卡片的 `onTap`。
- **备注：** 完整版构建还会在新建页启动在线搜索；商店版构建只预填标题——见 [`NextSeasonPrefill.fromRelation`](../services/series_service.md#nextseasonprefill-fromrelation)。新记录只在用户保存时才关联到 `last`。

### `Future<void> _runSeriesAction(SeriesAction action)` <a id="_runseriesaction"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 111 行）
- **用途：** 运行系列卡片菜单中的某个操作；记录不在任何系列中时，运行应用栏关联菜单中的操作。
- **输入：** `action` — 一个 `SeriesAction`（[`series_widgets.md`](series_widgets.md)）。
- **返回：** `Future<void>`。
- **副作用：** 可能通过 `AnimeStorage.addOrUpdateAll` 写入记录、打开管理面板或新建页，并经 `_load()` 重新加载。
- **算法：** `_anime` 与 `_seriesIndex` 加载完成前直接返回；之后用基于当前索引的 `SeriesEditor`：
  - `manage` → `showSeriesManageSheet`；仅当它报告有写入时重新加载。
  - `addNextSeason` → `context.push('/anime/edit', extra: NextSeasonPrefill.after(last))`，其中 `last` 是系列的最后一个成员（没有系列时是本记录）；返回后重新加载。
  - `remove` → `addOrUpdateAll(editor.removeFromSeries(anime))`，然后重新加载。
  - `letAppDecide` → `addOrUpdateAll(editor.letAppDecide(anime))`，然后重新加载。
- **用法：**
  ```dart
  SeriesCard(
    series: series,
    current: anime,
    onOpen: (a) => context.push('/anime/detail/${a.id}'),
    onAction: _runSeriesAction,
  ),
  ```
  （`_buildDetailChildren`，同一文件；应用栏的 `PopupMenuButton<SeriesAction>` 也调用它）
- **备注：** 每次写入都是由 `SeriesEditor` 标记时间的用户编辑——见 [`../services/series_service.md`](../services/series_service.md#serieseditor)。

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

### `List<String> _refreshableUrls(Anime anime)` <a id="_refreshableurls"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（第 616 行）
- **用途：** 列出这部番剧可用于刷新的来源页面。
- **输入：** `anime`。
- **返回：** `List<String>` —— 已去重、已丢弃空串。
- **副作用：** 无。
- **算法：** 委托给 `MetadataUpdateService.refreshableUrls`，它把 `infoUrl` 与 `externalMeta.ratings` 中每条记录的 `sourceUrl` 取并集。
- **备注：** 两者合并正是让由多个来源构建的记录能全部刷新的原因。它同时兼作刷新按钮的显示判据：列表为空说明无可重新查询的对象，此时该按钮根本不渲染。自 1.5.0 起这段逻辑移入后台更新器并被共享，因此手动按钮与后台刷新队列不可能对「可刷新」的定义产生分歧。

### `Future<void> _refreshExternalMeta(Anime anime)` <a id="_refreshexternalmeta"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 851 行）
- **用途：** 从每个已记住的来源页面重新抓取外部元数据。
- **输入：** `anime`。
- **返回：** 无。
- **副作用：** 经 `AnimeSearchService.refreshAll` 发起 HTTP 请求，经 `AnimeStorage.patchExternalMeta` 写入更新后的番剧，重新加载页面，并用 SnackBar 提示结果。
- **算法：**
  1. [`_refreshableUrls`](#_refreshableurls) 为空时，以「没有可用于刷新的来源」提示直接返回。
  2. `await AnimeSearchService.refreshAll(urls)`；结果整体为空时同样如此提示，而不是当作成功。
  3. 用 `AnimeExternalMeta.mergedWith` 把每条抓取结果折叠进已有的 `externalMeta`，并以同一个 UTC `now` 同时作为 `fetchedAt` 与 `refreshedAt`。
  4. 经 `AnimeStorage.patchExternalMeta({anime.id: merged})` 保存、重新加载并提示。

  1.6.0 起抓取结果携带各来源的 `relations`，由 `mergedWith` 按来源替换；重新加载时会重算系列分组，因此新的关联关系可以立即关联系列或显示缺失续作提示。
- **备注：** **只有外部元数据会被改动。** 用户自己的 `rating`、观看进度与手动编辑保持原样——这种分离正是外部评分存放在 `externalMeta.ratings` 而非 `AnimeRating` 的全部理由。调用方必须门禁在 `AppFlavor.isFull` 之后，因为商店构建不包含在线查询；见 [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)。

  1.5.0 之前第 4 步是 `copyWith(externalMeta: merged, modifiedAt: now)`，它会更新 `modifiedAt`。这与
  后台刷新会带来的隐患完全相同：由于 `mergeRecords` 判断「是否变化」只看 `modifiedAt` 与同步基线，
  一条被刷新过的记录可能在另一台设备做出的删除中幸存下来。`patchExternalMeta` 不碰这个时间戳。见
  [`../../../../sync.md`](../../../../sync.md)。

### `Widget _buildExternalMetaCard(AnimeExternalMeta meta, ThemeData theme, AppLocalizations l10n)` <a id="_buildexternalmetacard"></a>
- **种类：** `_AnimeDetailPageState` 的方法（组件辅助）
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（第 691 行）
- **用途：** 渲染从外部资料库拉取的公开元数据。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 卡片顶部是来源图标、区块标题与本地化的 `refreshedAt` 日期；随后为每个已提供字段渲染一行标签/值（作品形式、播出状态、时长、完结日期、制作公司、类型标签、别名）；最后，当任一评分有分值时，加一条分隔线、「外部评分」标题、一行说明文字，以及每个来源一个显示 `来源 评分/满分 · 票数` 的 chip。
- **备注：** 它刻意紧邻个人评分卡片下方，并在视觉上作为独立区块呈现——评分标题下的说明文字存在的意义，就是让人不会把外部评分误认成自己的评分。卡片本身**不**做 flavor 门禁：展示已经同步过来的数据不属于网络功能，而商店构建完全可能通过 WebDAV 同步或导入的分享文件正当地拿到这些数据。

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

### `Future<void> _checkWatchProgress(Anime anime)` <a id="_checkwatchprogress"></a>
- **种类：** `_AnimeDetailPageState` 的方法
- **来源：** `lib/features/anime/views/anime_detail_page.dart`（约第 816 行）
- **用途：** 重新读取 anime1.me 当前为本记录观看链接列出的内容并存储。
- **输入：** `anime`。
- **返回：** `Future<void>`。
- **副作用：** 经 `Anime1Service.fetchProgress` 至多三次 HTTP 请求；经 `AnimeStorage.patchExternalMeta` 写入；`setState` `_checkingProgress`；失败时显示 snack bar。
- **算法：**
  1. 没有观看链接则返回；打开按钮上的转圈。
  2. Await `Anime1Service.fetchProgress(url)`；`null` → snack bar `anime1ProgressUnknown`。
  3. 否则经 `mergedWith(AnimeExternalMeta(watchProgress: …))` 把记录并入 `externalMeta`，用 `patchExternalMeta` 写入，并 `_load()`。
  4. 任何异常 → snack bar `anime1ProgressFailed`；只要仍 mounted，转圈总会清除。
- **用法：**
  ```dart
  onPressed: AppFlavor.isFull && !_checkingProgress
      ? () => _checkWatchProgress(anime)
      : null,
  ```
  （`_buildHeaderActions`，anime1.me 进度按钮——按钮本身在每个 flavor 下都渲染）
- **备注：** 与 `_refreshExternalMeta` 一样，这绝不修改 `modifiedAt`：进度是公开站点数据的缓存，不是用户编辑。按钮文案来自 `_watchProgressChipLabel`，它读取 `Anime.validWatchProgress`，因此上次检查后被改过的 URL 会显示「查看」提示而不是过期的集数。
