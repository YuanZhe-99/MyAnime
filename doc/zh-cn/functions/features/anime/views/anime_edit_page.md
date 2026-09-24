# lib/features/anime/views/anime_edit_page.dart

`AnimeEditPage` 是单条 `Anime` 记录的创建/编辑表单：标题/季/集数范围/URL/备注的文本字段、类型覆盖和播出日的下拉框、`firstAirDate` 的日期选择器、评分子分字段、记录本地下载存档的本地存档小节，以及（仅 full 风味构建）在线元数据搜索和观看 URL 搜索集成。它通过 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）持久化，并构建/解析 `Anime`/`AnimeRating`/`AnimeLocalArchive` 模型（[`../models/anime.md`](../models/anime.md)）；存档枚举标签来自 [`archive_labels.md`](archive_labels.md)。它还定义了一个仅供自己的观看 URL 搜索操作使用的私有 `_WatchUrlSearchDialog`。这里编辑的字段（`manualType`、`airDayOfWeek`、`airTime`、`firstAirDate`）如何驱动季度归属和剧集播出日期计算见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

自 1.6.0 起，新建路由（`/anime/edit`，见 [`../../../app/router.md`](../../../app/router.md)）可以把 `NextSeasonPrefill`（[`../services/series_service.md`](../services/series_service.md#nextseasonprefill)）作为 `extra` 携带：系列卡片的*添加下一季*操作打开本页时会复制标题、递增季标签，并带一个待定的关联，由 [`_saveNew`](#_savenew) 仅在新记录保存时写入。编辑时忽略 `prefill` 构造参数。详情页的缺失续作提示（1.6.0 M2）用 [`NextSeasonPrefill.fromRelation`](../services/series_service.md#nextseasonprefill-fromrelation) 打开同一路由，其 `autoSearch` 标志让 `initState` 在首帧之后打开在线搜索对话框——仅限完整版构建。`initState` 自己检查 `AppFlavor.isFull`，因此即使关联数据是经同步到达的，商店版构建也只得到预填的标题而不会搜索。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AnimeEditPage.new` | 构造函数（`AnimeEditPage`） | B | 创建 `AnimeEditPage`，可选绑定到既有动画 ID，或（仅新建路由）由 `NextSeasonPrefill` 预填。 |
| `AnimeEditPage.createState` | 方法（`AnimeEditPage`） | B | 为此组件创建可变状态对象。 |
| `_AnimeEditPageState.initState` | 方法（`_AnimeEditPageState`） | B | 设置默认季文本，新建时应用下一季预填（其 `autoSearch` 已设置且为完整版构建时启动在线搜索），编辑时触发加载既有记录。 |
| [`_loadExisting`](#_loadexisting) | 方法（`_AnimeEditPageState`） | A | 加载既有动画并从它填充每个表单字段/控制器。 |
| `_AnimeEditPageState.dispose` | 方法（`_AnimeEditPageState`） | B | 释放全部 17 个自有的 `TextEditingController`。 |
| [`_pickCoverImage`](#_pickcoverimage) | 方法（`_AnimeEditPageState`） | A | 让用户选择封面图像文件并暂存其路径。 |
| [`_searchWatchUrl`](#_searchwatchurl) | 方法（`_AnimeEditPageState`） | A | 用所有已知标题打开观看 URL 搜索对话框，并应用所选 URL 及其进度。 |
| [`_showSearchDialog`](#_showsearchdialog) | 方法（`_AnimeEditPageState`） | A | 打开在线元数据搜索对话框并把其结果合并进表单。 |
| [`_pickFirstAirDate`](#_pickfirstairdate) | 方法（`_AnimeEditPageState`） | A | 显示日期选择器并暂存所选 `firstAirDate`。 |
| [`_saveNew`](#_savenew) | 方法（`_AnimeEditPageState`） | A | 写入新建的记录；页面由"添加下一季"打开时把它关联进系列。 |
| [`_save`](#_save) | 方法（`_AnimeEditPageState`） | A | 校验表单并创建或更新动画记录。 |
| [`_buildRating`](#_buildrating) | 方法（`_AnimeEditPageState`） | A | 从评分文本字段组装 `AnimeRating`，为空则 `null`。 |
| [`_buildLocalArchive`](#_buildlocalarchive) | 方法（`_AnimeEditPageState`） | A | 从存档控件组装 `AnimeLocalArchive`，未填写则 `null`。 |
| `_parseScore` | 方法（`_AnimeEditPageState`） | B | 把评分控制器的文本解析为 `double?`。 |
| `_formatScore` | 方法（`_AnimeEditPageState`） | B | 分数为整数时格式化为整数，否则保留一位小数。 |
| [`_AnimeEditPageState.build`](#_animeeditpagestate_build) | 方法（`_AnimeEditPageState`，组件构建） | A | 把编辑/创建表单构建为单列或双栏。 |
| [`_buildCoverPicker`](#_buildcoverpicker) | 方法（`_AnimeEditPageState`） | A | 以显式尺寸构建封面选择器。 |
| [`_buildTitleFields`](#_buildtitlefields) | 方法（`_AnimeEditPageState`） | A | 构建与封面共处左栏的两个标题字段。 |
| [`_buildDetailFields`](#_builddetailfields) | 方法（`_AnimeEditPageState`） | A | 构建两个标题之下的每一个表单字段。 |
| `_buildRatingField` | 方法（组件辅助） | B | 渲染一个带校验的 0–10 评分 `TextFormField`。 |
| `_dayName` | 方法（`_AnimeEditPageState`） | B | 本地化星期几数字供播出日下拉框使用。 |
| `_typeLabel` | 方法（`_AnimeEditPageState`） | B | 本地化 `AnimeType` 值供类型覆盖下拉框使用。 |
| `_WatchUrlSearchDialog.new` | 构造函数（`_WatchUrlSearchDialog`） | B | 带查询、替代查询、首播日期与季度标签创建观看 URL 搜索对话框。 |
| `_WatchUrlSearchDialog.createState` | 方法（`_WatchUrlSearchDialog`） | B | 为此组件创建可变状态对象。 |
| `_WatchUrlSearchDialogState.initState` | 方法（`_WatchUrlSearchDialogState`） | B | 播种查询控制器并运行首次搜索。 |
| `_WatchUrlSearchDialogState.dispose` | 方法（`_WatchUrlSearchDialogState`） | B | 释放查询控制器。 |
| [`_search`](#_search-watchurl) | 方法（`_WatchUrlSearchDialogState`） | A | 对对话框的查询文本运行 anime1.me 索引查找。 |
| `_WatchUrlSearchDialogState.build` | 方法（`_WatchUrlSearchDialogState`，组件构建） | B | 构建观看 URL 搜索对话框脚手架。 |
| `_buildBody` | 方法（组件辅助） | B | 渲染观看 URL 对话框的加载/错误/结果正文。 |

## 文档

### `Future<void> _loadExisting()` <a id="_loadexisting"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 79 行）
- **用途：** 加载 `widget.animeId` 标识的动画并从它填充每个表单控制器和暂存字段，把页面切到编辑模式。
- **输入：** 无（`widget.animeId` 来自外层组件）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.load()`；`setState` `_isEdit`、`_existing` 和每个控制器/暂存字段（`_titleController`、……、`_coverImage`）。
- **算法：**
  1. Await `AnimeStorage.load()`；找 `id == widget.animeId` 的记录。
  2. 找到时，设 `_isEdit = true`、`_existing = found`，把每个可编辑字段复制进匹配的控制器（未设置的可选文本字段为空字符串）或暂存变量（`_airDayOfWeek`、`_firstAirDate`、`_manualType`、`_coverImage`、`_archived`、`_archiveSource`、`_archiveResolution`）。
  3. 评分子分在放进控制器之前经 `_formatScore`（Tier B，同一文件）格式化。
  4. 本地存档控件以空安全默认值从 `found.localArchive` 填充，因此没有存档记录的动画打开时开关关闭、各字段为空。
- **用法：**
  ```dart
  if (widget.animeId != null) {
    _loadExisting();
  }
  ```
  （`_AnimeEditPageState.initState`，同一文件）
- **备注：** 没有记录匹配 `widget.animeId` 时，页面静默保持在创建模式（`_isEdit` 保持 `false`），而不是显示错误。

### `Future<void> _pickCoverImage()` <a id="_pickcoverimage"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 141 行）
- **用途：** 让用户从设备选择图像文件并暂存为动画的封面。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ImageService.pickAndSaveImage()`（文件系统读/复制）；`setState` `_coverImage`。
- **算法：** Await `ImageService.pickAndSaveImage()`；返回非 null 路径且组件仍 mounted 时，暂存进 `_coverImage`。
- **用法：**
  ```dart
  Center(
    child: GestureDetector(
      onTap: _pickCoverImage,
      child: Container(...),
  ```
  （`_AnimeEditPageState.build`，封面图像点击目标）
- **备注：** 选中的图像只在内存中暂存，直到 [`_save`](#_save) 持久化动画记录——不保存地退出编辑页会丢弃该选择（不过 `ImageService.pickAndSaveImage` 可能已把文件复制进应用的图像目录；见 [`../../../shared/services/image_service.md`](../../../shared/services/image_service.md)）。

### `Future<void> _searchWatchUrl()` <a id="_searchwatchurl"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 153 行）
- **用途：** 打开以表单所知的每个标题为种子的 `_WatchUrlSearchDialog`，并应用用户选择的结果——其 URL 与站点的集数进度。
- **输入：** 无（读取标题控制器、`_externalMeta`、`_firstAirDate` 与季度控制器）。
- **返回：** `Future<void>`。
- **副作用：** 显示执行网络请求的对话框；`setState` `_watchUrlController.text` 与 `_externalMeta`；成功时显示 `SnackBar`。
- **算法：**
  1. 标题非空则用作主查询，否则用日文标题；两者都空则提前返回。
  2. 构建 `altQueries`——日文标题（当标题是主查询时），以及 `_externalMeta` 的 `titleEn`、`titleRomaji` 与每个别名，过滤空白。站点索引的台译可能与大陆译名一个字都不共享，因此每个已知名称都一并送去。
  3. Await `showDialog<Anime1Match>`，带一个同时接收 `_firstAirDate` 与季度标签（驱动档期加分）的 `_WatchUrlSearchDialog`；选中命中且组件仍 mounted 时，设置 `_watchUrlController.text`，经 `mergedWith` 把 `match.toProgress(now)` 并入 `_externalMeta`，并显示确认 `SnackBar`。进度因此在保存时一并存储，无需再发请求。
- **用法：**
  ```dart
  suffixIcon: AppFlavor.isFull
      ? IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.searchWatchUrl,
          onPressed: _searchWatchUrl,
        )
      : null,
  ```
  （`_AnimeEditPageState.build`，观看 URL 字段后缀——门控在 `AppFlavor.isFull` 上）
- **备注：** 只在 full 应用风味（`AppFlavor.isFull`）中接线；lite 风味绝不显示触发它的搜索图标。

### `Future<void> _showSearchDialog()` <a id="_showsearchdialog"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 183 行）
- **用途：** 打开预填表单当前值的在线元数据搜索对话框（[`showAnimeSearchDialog`](anime_search_dialog.md#showanimesearchdialog)），然后应用用户选择导入回表单的任何字段。
- **输入：** 无（读取当前控制器/暂存字段值作为 `currentXxx` 参数传入）。
- **返回：** `Future<void>`。
- **副作用：** 显示执行网络请求的对话框；`setState` `_titleController`、`_titleJaController`、`_endEpController`、`_firstAirDate`、`_airDayOfWeek`、`_airTimeController`、`_notesController`、`_coverImage`、`_infoUrlController`、`_externalMeta` 中的任意。
- **算法：**
  1. 标题控制器的文本非空则用作初始查询，否则用日文标题。
  2. Await `showAnimeSearchDialog(...)`，把每个当前表单值作为 `currentXxx` 参数传入（使对话框能显示"当前 vs 获取"比较）。
  3. 返回非 null 结果映射时，把映射中存在的每个键应用到匹配的控制器/字段——十个可能键（`title`、`titleJa`、`endEpisode`、`firstAirDate`、`airDayOfWeek`、`airTime`、`notes`、`coverImage`、`infoUrl`、`externalMeta`）各自经 `result.containsKey(...)` 独立检查和应用。`externalMeta` 保存在 `_externalMeta` 中（不是表单控制器，因为它从不手工输入），并在 `_save()` 时随记录一并写入。
- **用法：**
  ```dart
  if (AppFlavor.isFull)
    IconButton(
      icon: const Icon(Icons.travel_explore),
      tooltip: l10n.searchAnimeInfo,
      onPressed: _showSearchDialog,
    ),
  ```
  （`_AnimeEditPageState.build`，应用栏操作——仅 full 风味）
- **备注：** 结果映射的键完全由被调方定义——确切哪些键能出现、在什么条件下出现，见 [`showAnimeSearchDialog`](anime_search_dialog.md#showanimesearchdialog) 和该文件的 `_apply`。

### `Future<void> _pickFirstAirDate()` <a id="_pickfirstairdate"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 245 行）
- **用途：** 显示平台日期选择器（限制在 2000–2040 年）并把所选日期暂存为 `firstAirDate`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示 `showDatePicker` 对话框；`setState` `_firstAirDate`。
- **算法：** Await `showDatePicker`，`initialDate: _firstAirDate ?? DateTime.now()`；选中日且组件仍 mounted 时暂存它。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.calendar_today),
    onPressed: _pickFirstAirDate,
  ),
  ```
  （`_AnimeEditPageState.build`，首播日期行）
- **备注：** 单独的"清除"图标（`onPressed: () => setState(() => _firstAirDate = null)`）完全绕过此方法直接取消该日期。

### `Future<void> _saveNew(Anime anime)` <a id="_savenew"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 333 行）
- **用途：** 写入新建的记录；页面由"添加下一季"打开时把它关联进系列（1.6.0）。
- **输入：** `anime` — 新记录。
- **返回：** `Future<void>`。
- **副作用：** 写一次 `anime_data.json`。
- **算法：**
  1. 没有 `prefill`：`AnimeStorage.addOrUpdate(anime)`。
  2. 有 `prefill`：重新加载片库，构建 `SeriesIndex`，查找 `prefill.linkToAnimeId`。若该记录在此期间已消失，则不带关联地保存新记录。
  3. 否则执行 `SeriesEditor(index).link(anime, source)`，并用一次 `AnimeStorage.addOrUpdateAll` 写入结果——新记录加上被固化的系列。
- **用法：**
  ```dart
  await _saveNew(anime);
  if (mounted) context.pop(anime.id);
  ```
  （`_save`，同一文件，新建分支）
- **备注：** 关联在此之前一直是待定的：不保存就离开页面不会写入任何东西，连被固化的系列也不会写入。

### `Future<void> _save()` <a id="_save"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 359 行）
- **用途：** 校验表单、调和集数范围，然后更新既有动画或创建新动画，之后离开页面。
- **输入：** 无（读取每个控制器/暂存字段）。
- **返回：** `Future<void>`。
- **副作用：** 可能显示"缺少字段"`AlertDialog`；调用 `AnimeStorage.addOrUpdate`（新建时改经 [`_saveNew`](#_savenew)）；弹出当前路由（创建时带新动画 ID）。
- **算法：**
  1. 运行 `Form` 的字段校验器（`_formKey.currentState!.validate()`）；无效则中止。
  2. 创建时（`!_isEdit`），要求标题/日文标题至少一个非空；否则显示列出缺失字段的阻塞对话框并返回。
  3. 从控制器解析 `startEp`/`endEp`（默认为 `1`/`12`）并经 [`_buildRating`](#_buildrating) 构建评分，并经 [`_buildLocalArchive`](#_buildlocalarchive) 构建本地存档记录。
  4. `startEp > endEp` 时，上移 `endEp`，使集数相对原始 `endEpisode`（编辑时）或原始解析的 `endEp`（创建时）保持不变——`endEp = originalEnd - 1 + startEp`。
  5. 编辑时：用每个表单字段（空的可选字符串变 `null`）、`rating`、`clearRating: rating == null`、`localArchive`、`clearLocalArchive: localArchive == null` 和新 `modifiedAt` `copyWith` 既有动画；经 `AnimeStorage.addOrUpdate` 保存；无结果地弹出。
  6. 创建时：标题字段为空时从日文标题自动填充 `title`，经 [`Anime.create`](../models/anime.md#anime-create) 构建新 `Anime`，经 [`_saveNew`](#_savenew) 保存它，并带新动画的 `id` 作为结果弹出路由。
- **用法：**
  ```dart
  TextButton(onPressed: _save, child: Text(l10n.save)),
  ```
  （`_AnimeEditPageState.build`，应用栏操作）
- **备注：** 第 4 步的集数保持调整只在用户（或导入的搜索结果）留下 `startEpisode` 大于 `endEpisode` 时触发——它是修复步骤，不是常规保存会走到的东西。

### `AnimeRating? _buildRating()` <a id="_buildrating"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 378 行）
- **用途：** 从六个评分文本字段组装 `AnimeRating`，其中没有一个（且没有保留的 `extraJson`）持有数据时收缩为 `null`。
- **输入：** 无（读取六个评分控制器和 `_existing?.rating?.extraJson`）。
- **返回：** `AnimeRating?`。
- **副作用：** 无。
- **算法：** 经 `_parseScore` 解析六个评分控制器各一，构建带 `_existing` 的 `extraJson`（如有）的 `AnimeRating`，然后只在 [`hasAnyData`](../models/anime.md) 为 true 时返回它，否则 `null`。
- **用法：**
  ```dart
  final rating = _buildRating();
  ...
  rating: rating,
  clearRating: rating == null,
  ```
  （`_save`，同一文件）
- **备注：** 以 `_build` 前缀命名但**不**返回 `Widget`——它是供 [`_save`](#_save) 使用的数据组装辅助，不是 UI 构建器。

### `AnimeLocalArchive? _buildLocalArchive()` <a id="_buildlocalarchive"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 416 行）
- **用途：** 从本地存档小节的控件组装 `AnimeLocalArchive`，该小节未被触碰时收缩为 `null`。
- **输入：** 无（读取 `_archived`、`_archiveSource`、`_archiveResolution`、两个存档控制器，以及
  `_existing?.localArchive?.extraJson`）。
- **返回：** `AnimeLocalArchive?`。
- **副作用：** 无。
- **算法：** 裁剪位置文本（空 → `null`），对份数文本做 `int.tryParse`，构建一个带上 `_existing` 存档
  `extraJson`（若有）的 `AnimeLocalArchive`，仅当
  [`hasAnyData`](../models/anime.md#animelocalarchive-hasanydata) 为真时返回它，否则 `null`。
- **用法：**
  ```dart
  final localArchive = _buildLocalArchive();
  ...
  localArchive: localArchive,
  clearLocalArchive: localArchive == null,
  ```
  （同文件 `_save`）
- **备注：** 与 [`_buildRating`](#_buildrating) 完全平行，包括不返回 `Widget` 的 `_build` 前缀。这个
  `null` 收缩正是让 `anime_data.json` 中不出现空 `localArchive` 对象（针对从未使用该功能的动画）的原因。
  即使 `archived` 开关关闭，子字段仍可编辑——没有跨字段联动，因此"尚未下载，但已预定放 NAS-01"是可表达的。
### `Future<void> _search()` <a id="_search-watchurl"></a>
- **种类：** `_WatchUrlSearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 867 行）
- **用途：** 对对话框的查询文本运行 anime1.me 查找（`Anime1Service.search`），外加传入的替代查询、首播日期与季度标签。
- **输入：** 无（读取 `_controller.text`；使用 `widget.altQueries`、`widget.firstAirDate`、`widget.seasonText`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `Anime1Service.search` 执行网络请求；`setState` `_loading`、`_results`（一个 `List<Anime1Match>`）、`_error`。
- **算法：**
  1. 修剪查询文本；为空则提前返回。
  2. `setState` 进入加载状态，清除先前的结果/错误。
  3. Await `Anime1Service.search(q, altQueries:, firstAirDate:, seasonText:)`；成功时存储结果，列表返回空时设置"无结果"错误消息。每行渲染标题、来自 `anime1InfoLine` 的说明行（季节 · 集数 · 字幕组）与 URL；当任一结果为 `viaAliases` 时，一行说明指出命中来自 bangumi.tv 的别名。重新键入查询只对缓存的索引重新排序，不会再下载。
  4. 任何抛出的异常时，把 `e.toString()` 存为 `_error` 而不是结果。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _search();
  }
  ```
  （`_WatchUrlSearchDialogState.initState`，同一文件；也从搜索字段的 `onSubmitted` 和搜索 `FilledButton` 重新调用）
- **备注：** 错误以原始 `e.toString()` 文本浮出，而不是本地化消息。

### `Widget build(BuildContext context)` <a id="_animeeditpagestate_build"></a>
- **种类：** `_AnimeEditPageState` 的方法（组件构建）
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 487 行）
- **用途：** 把编辑/创建表单构建为单列或双栏。
- **输入：** `context`。
- **返回：** 该页面的控件树。
- **副作用：** 由当前状态创建 UI 控件。
- **算法：**
  1. 先各构建一次 `_buildTitleFields` 与 `_buildDetailFields`，使两种布局拿到的是同一批控件。
  2. 当 `useDetailTwoPane(screen.width, screen.height)` 为假时，返回原本那个单一 `ListView`：120 × 170 的封面、
     两个标题，然后是其余字段。
  3. 否则返回一个 `Row`：一个 `SizedBox(width: detailLeftPaneWidth(constraints.maxWidth))` 装着按
     `editCoverSize` 定尺寸的封面与两个标题，一条 `VerticalDivider(width: 1)`，以及一个装着其余字段的
     `Expanded` `ListView`。
- **用法：**
  ```dart
  GoRoute(
    path: '/anime/edit/:id',
    builder: (context, state) =>
        AnimeEditPage(animeId: state.pathParameters['id']),
  ),
  ```
  （出自 `lib/app/router.dart` 中的 `appRouter`）
- **备注：** 于 1.5.5 加入，采用详情页自 1.5.2 起就有的形状，并且经由同一个 `useDetailTwoPane` 委托。这条路由位于
  `ShellRoute` **之外**，因此没有侧边导航栏需要扣除，`constraints.maxWidth` 就是整块宽度——这也是它成为唯一
  一个不经过 `shellContentWidth` 的自适应页面的原因。

  两栏都留在同一个 `Form` 内，因此 `_save` 的 `validate()` 仍能同时够到左边的标题字段与右边的季度字段。这里
  除了状态对象本来就持有的那些控制器之外没有任何状态，所以折叠设备会在下一帧互换两种布局，而输了一半的标题
  原封不动。

### `Widget _buildCoverPicker({required double width, required double height})` <a id="_buildcoverpicker"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 552 行）
- **用途：** 以显式尺寸构建封面选择器。
- **输入：** `width`、`height`——选择器方框的逻辑像素尺寸。
- **返回：** `Widget`。
- **副作用：** 经由 `ImageService.resolve` 读取封面文件；点击会打开图片选择器。
- **算法：** 一个 `Center` 套 `GestureDetector` 套按给定尺寸的 `Container`，显示解析出的封面文件或
  `add_photo_alternate` 图标。
- **用法：**
  ```dart
  _buildCoverPicker(width: cover.width, height: cover.height),
  ```
  （出自同一文件 `build` 的双栏分支）
- **备注：** 于 1.5.5 从 `build` 中抽出并接受尺寸参数，因为双栏布局是由其左栏剩下的高度推导它的，而单列布局保持
  原本固定的 120 × 170 方框。与 `anime_detail_page._buildCover` 对应。

### `List<Widget> _buildTitleFields(AppLocalizations l10n)` <a id="_buildtitlefields"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 596 行）
- **用途：** 构建与封面共处左栏的两个标题字段。
- **输入：** `l10n`。
- **返回：** `List<Widget>`——标题字段、一个 12 dp 间距、日文标题字段。
- **副作用：** 无。
- **算法：** 原样返回那两个 `TextFormField`，与它们在单列形态下完全相同。
- **用法：**
  ```dart
  final titleFields = _buildTitleFields(l10n);
  ```
  （出自同一文件的 `build`）
- **备注：** 与 [`_buildDetailFields`](#_builddetailfields) 分开，因为这恰是用户要求留在封面旁边的那些。无论渲染
  在哪里它们都必须待在一起：标题的校验器在日文标题已填写时接受空值，因此把它们拆开会让一个字段的有效性落在
  另一栏里。

### `List<Widget> _buildDetailFields(AppLocalizations l10n)` <a id="_builddetailfields"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 630 行）
- **用途：** 构建两个标题之下的每一个表单字段。
- **输入：** `l10n`。
- **返回：** `List<Widget>`——季度、集数区间、类型、播出日、播出时间、首播日期、信息 URL、观看 URL、评分卡片、
  本地存档卡片与备注。
- **副作用：** 无。
- **算法：** 原样返回那些字段，与它们原本作为 `build` 中 `ListView` 尾部时完全相同。
- **用法：**
  ```dart
  Expanded(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: detailFields,
    ),
  ),
  ```
  （出自同一文件 `build` 的双栏分支）
- **备注：** 在双栏布局里它们是滚动栏的子控件，否则就是那个单一 `ListView` 的尾部——一份列表、两个宿主，因此
  字段顺序不可能在两种布局之间走样。`test/local_archive_ui_test.dart` 滚动的正是这个 `ListView`；自 1.5.5 起它
  必须经由 `find.byType(ListView)` 来指认它，而不能再当作页面上的第一个 `Scrollable`，因为左栏的滚动视图现在
  排在前面。
