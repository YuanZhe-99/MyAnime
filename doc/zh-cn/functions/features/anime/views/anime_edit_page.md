# lib/features/anime/views/anime_edit_page.dart

`AnimeEditPage` 是单条 `Anime` 记录的创建/编辑表单：标题/季/集数范围/URL/备注的文本字段、类型覆盖和播出日的下拉框、`firstAirDate` 的日期选择器、评分子分字段，以及（仅 full 风味构建）在线元数据搜索和观看 URL 搜索集成。它通过 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）持久化，并构建/解析 `Anime`/`AnimeRating` 模型（[`../models/anime.md`](../models/anime.md)）。它还定义了一个仅供自己的观看 URL 搜索操作使用的私有 `_WatchUrlSearchDialog`。这里编辑的字段（`manualType`、`airDayOfWeek`、`airTime`、`firstAirDate`）如何驱动季度归属和剧集播出日期计算见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AnimeEditPage.new` | 构造函数（`AnimeEditPage`） | B | 创建 `AnimeEditPage`，可选绑定到既有动画 ID。 |
| `AnimeEditPage.createState` | 方法（`AnimeEditPage`） | B | 为此组件创建可变状态对象。 |
| `_AnimeEditPageState.initState` | 方法（`_AnimeEditPageState`） | B | 设置默认季文本，编辑时触发加载既有记录。 |
| [`_loadExisting`](#_loadexisting) | 方法（`_AnimeEditPageState`） | A | 加载既有动画并从它填充每个表单字段/控制器。 |
| `_AnimeEditPageState.dispose` | 方法（`_AnimeEditPageState`） | B | 释放全部 15 个自有的 `TextEditingController`。 |
| [`_pickCoverImage`](#_pickcoverimage) | 方法（`_AnimeEditPageState`） | A | 让用户选择封面图像文件并暂存其路径。 |
| [`_searchWatchUrl`](#_searchwatchurl) | 方法（`_AnimeEditPageState`） | A | 打开观看 URL 搜索对话框并应用所选 URL。 |
| [`_showSearchDialog`](#_showsearchdialog) | 方法（`_AnimeEditPageState`） | A | 打开在线元数据搜索对话框并把其结果合并进表单。 |
| [`_pickFirstAirDate`](#_pickfirstairdate) | 方法（`_AnimeEditPageState`） | A | 显示日期选择器并暂存所选 `firstAirDate`。 |
| [`_save`](#_save) | 方法（`_AnimeEditPageState`） | A | 校验表单并创建或更新动画记录。 |
| [`_buildRating`](#_buildrating) | 方法（`_AnimeEditPageState`） | A | 从评分文本字段组装 `AnimeRating`，为空则 `null`。 |
| `_parseScore` | 方法（`_AnimeEditPageState`） | B | 把评分控制器的文本解析为 `double?`。 |
| `_formatScore` | 方法（`_AnimeEditPageState`） | B | 分数为整数时格式化为整数，否则保留一位小数。 |
| `_AnimeEditPageState.build` | 方法（`_AnimeEditPageState`，组件构建） | B | 构建编辑/创建表单脚手架。 |
| `_buildRatingField` | 方法（组件辅助） | B | 渲染一个带校验的 0–10 评分 `TextFormField`。 |
| `_dayName` | 方法（`_AnimeEditPageState`） | B | 本地化星期几数字供播出日下拉框使用。 |
| `_typeLabel` | 方法（`_AnimeEditPageState`） | B | 本地化 `AnimeType` 值供类型覆盖下拉框使用。 |
| `_WatchUrlSearchDialog.new` | 构造函数（`_WatchUrlSearchDialog`） | B | 带查询和替代查询创建观看 URL 搜索对话框。 |
| `_WatchUrlSearchDialog.createState` | 方法（`_WatchUrlSearchDialog`） | B | 为此组件创建可变状态对象。 |
| `_WatchUrlSearchDialogState.initState` | 方法（`_WatchUrlSearchDialogState`） | B | 播种查询控制器并运行首次搜索。 |
| `_WatchUrlSearchDialogState.dispose` | 方法（`_WatchUrlSearchDialogState`） | B | 释放查询控制器。 |
| [`_search`](#_search-watchurl) | 方法（`_WatchUrlSearchDialogState`） | A | 搜索 anime1.me 找匹配查询的观看页链接。 |
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
  2. 找到时，设 `_isEdit = true`、`_existing = found`，把每个可编辑字段复制进匹配的控制器（未设置的可选文本字段为空字符串）或暂存变量（`_airDayOfWeek`、`_firstAirDate`、`_manualType`、`_coverImage`）。
  3. 评分子分在放进控制器之前经 `_formatScore`（Tier B，同一文件）格式化。
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
- **用途：** 打开以当前标题（和替代标题）为种子的 `_WatchUrlSearchDialog`，并应用用户选择的任何结果 URL。
- **输入：** 无（读取 `_titleController`/`_titleJaController` 文本）。
- **返回：** `Future<void>`。
- **副作用：** 显示执行网络请求的对话框；`setState` `_watchUrlController.text`；成功时显示 `SnackBar`。
- **算法：**
  1. 标题非空则用作主查询，否则用日文标题；两者都空则提前返回。
  2. 构建 `altQueries`——*另一个*标题，但只在两者恰好一个非空时包含（使对话框在只有一个标题时总有回退查询）。
  3. Await `showDialog<String>`，带一个 `_WatchUrlSearchDialog`；选中 URL 且组件仍 mounted 时，设置 `_watchUrlController.text` 并显示确认 `SnackBar`。
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
- **副作用：** 显示执行网络请求的对话框；`setState` `_titleController`、`_titleJaController`、`_endEpController`、`_firstAirDate`、`_airDayOfWeek`、`_airTimeController`、`_notesController`、`_coverImage`、`_infoUrlController` 中的任意。
- **算法：**
  1. 标题控制器的文本非空则用作初始查询，否则用日文标题。
  2. Await `showAnimeSearchDialog(...)`，把每个当前表单值作为 `currentXxx` 参数传入（使对话框能显示"当前 vs 获取"比较）。
  3. 返回非 null 结果映射时，把映射中存在的每个键应用到匹配的控制器/字段——九个可能键（`title`、`titleJa`、`endEpisode`、`firstAirDate`、`airDayOfWeek`、`airTime`、`notes`、`coverImage`、`infoUrl`）各自经 `result.containsKey(...)` 独立检查和应用。
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

### `Future<void> _save()` <a id="_save"></a>
- **种类：** `_AnimeEditPageState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 262 行）
- **用途：** 校验表单、调和集数范围，然后更新既有动画或创建新动画，之后离开页面。
- **输入：** 无（读取每个控制器/暂存字段）。
- **返回：** `Future<void>`。
- **副作用：** 可能显示"缺少字段"`AlertDialog`；调用 `AnimeStorage.addOrUpdate`；弹出当前路由（创建时带新动画 ID）。
- **算法：**
  1. 运行 `Form` 的字段校验器（`_formKey.currentState!.validate()`）；无效则中止。
  2. 创建时（`!_isEdit`），要求标题/日文标题至少一个非空；否则显示列出缺失字段的阻塞对话框并返回。
  3. 从控制器解析 `startEp`/`endEp`（默认为 `1`/`12`）并经 [`_buildRating`](#_buildrating) 构建评分。
  4. `startEp > endEp` 时，上移 `endEp`，使集数相对原始 `endEpisode`（编辑时）或原始解析的 `endEp`（创建时）保持不变——`endEp = originalEnd - 1 + startEp`。
  5. 编辑时：用每个表单字段（空的可选字符串变 `null`）、`rating`、`clearRating: rating == null` 和新 `modifiedAt` `copyWith` 既有动画；经 `AnimeStorage.addOrUpdate` 保存；无结果地弹出。
  6. 创建时：标题字段为空时从日文标题自动填充 `title`，经 [`Anime.create`](../models/anime.md#anime-create) 构建新 `Anime`，保存它，并带新动画的 `id` 作为结果弹出路由。
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

### `Future<void> _search()` <a id="_search-watchurl"></a>
- **种类：** `_WatchUrlSearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_edit_page.dart`（约第 867 行）
- **用途：** 经 `AnimeSearchService.searchAnime1` 查询 `anime1.me`，找匹配对话框查询文本的观看页链接，外加传入的任何替代查询。
- **输入：** 无（读取 `_controller.text`；使用 `widget.altQueries`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `AnimeSearchService.searchAnime1` 执行网络请求；`setState` `_loading`、`_results`、`_error`。
- **算法：**
  1. 修剪查询文本；为空则提前返回。
  2. `setState` 进入加载状态，清除先前的结果/错误。
  3. Await `AnimeSearchService.searchAnime1(q, altQueries: widget.altQueries)`；成功时存储结果，列表返回空时设置"无结果"错误消息。
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
