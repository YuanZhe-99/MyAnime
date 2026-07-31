# lib/features/anime/views/anime_search_dialog.dart

`showAnimeSearchDialog` 及其背后的 `_SearchDialog` 实现从编辑页使用的"在线搜索动画元数据"流程：经 `AnimeSearchService`（[`../services/anime_search_service.md`](../services/anime_search_service.md)）搜索多个来源，用一个带逐字段复选框的预览决定导入什么，可选地获取其封面图像（经 `ImageService`，[`../../../shared/services/image_service.md`](../../../shared/services/image_service.md)），并返回用户选择应用的字段的稀疏 `Map<String, dynamic>`。调用方（`AnimeEditPage._showSearchDialog`，[`anime_edit_page.md`](anime_edit_page.md#_showsearchdialog)）把该映射合并进它自己的表单字段——本文件对 `AnimeStorage` 或 `Anime` 模型本身没有直接依赖。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showAnimeSearchDialog`](#showanimesearchdialog) | 顶层函数 | A | 显示动画元数据搜索对话框并返回所选字段值。 |
| `_SearchDialog.new` | 构造函数（`_SearchDialog`） | B | 用当前表单的值创建搜索对话框供比较。 |
| `_SearchDialog.createState` | 方法（`_SearchDialog`） | B | 为此组件创建可变状态对象。 |
| `_SearchDialogState.initState` | 方法（`_SearchDialogState`） | B | 从 `initialQuery` 播种查询控制器。 |
| `_SearchDialogState.dispose` | 方法（`_SearchDialogState`） | B | 释放查询控制器。 |
| [`_search`](#_search) | 方法（`_SearchDialogState`） | A | 对当前查询文本搜索所有已配置来源。 |
| [`_selectResult`](#_selectresult) | 方法（`_SearchDialogState`） | A | 为所选结果进入预览阶段，预选要应用的字段。 |
| [`_fetchCover`](#_fetchcover) | 方法（`_SearchDialogState`） | A | 下载并暂存所选结果的封面图像。 |
| [`_apply`](#_apply) | 方法（`_SearchDialogState`） | A | 从切换的字段构建结果映射并关闭对话框。 |
| `_SearchDialogState.build` | 方法（`_SearchDialogState`，组件构建） | B | 构建对话框，在搜索和预览视图之间切换。 |
| `_buildSearchView` | 方法（组件辅助） | B | 渲染搜索阶段：页头、查询字段和结果列表。 |
| `_buildSearchResults` | 方法（组件辅助） | B | 渲染搜索结果列表（加载/错误/空/列表状态）。 |
| `_buildPreviewView` | 方法（组件辅助） | B | 渲染预览阶段：来源徽章、字段列表和应用/取消按钮。 |
| `_buildFieldList` | 方法（组件辅助） | B | 渲染逐字段比较复选框和封面图像小节。 |
| `_coverColumn` | 方法（组件辅助） | B | 渲染一个带标签的封面图像缩略图列。 |
| `_fieldTile` | 方法（组件辅助） | B | 渲染一个比较当前 vs 获取值的复选框字段块。 |
| `_buildHeader` | 方法（组件辅助） | B | 渲染对话框页头（图标、标题、可选返回/关闭按钮）。 |
| `_dayName` | 方法（`_SearchDialogState`） | B | 本地化星期几数字供显示。 |
| `_truncate` | 方法（`_SearchDialogState`） | B | 把字符串缩短到最大长度，追加 `...`。 |

## 文档

### `Future<Map<String, dynamic>?> showAnimeSearchDialog(BuildContext context, {String? initialQuery, String? currentTitle, String? currentTitleJa, int? currentEndEp, DateTime? currentFirstAirDate, int? currentAirDay, String? currentAirTime, String? currentCoverImage, String? currentNotes})` <a id="showanimesearchdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 15 行）
- **用途：** 在线元数据搜索流程的公共入口：显示用调用方当前字段值播种的 `_SearchDialog`，返回用户选择应用的任何字段映射。
- **输入：** `context`；`initialQuery` — 预填的搜索文本；`currentXxx` 参数纯直通给 `_SearchDialog`，只为让它能显示"当前 vs 获取"比较——它们不影响搜索什么。
- **返回：** `Future<Map<String, dynamic>?>` — 只含用户选择应用的字段的稀疏映射（可能键：`title`、`titleJa`、`endEpisode`、`firstAirDate`、`airDayOfWeek`、`airTime`、`notes`、`coverImage`、`infoUrl`），对话框被取消时为 `null`。
- **副作用：** 显示执行网络请求的模态对话框。
- **算法：** 薄的转发包装：用给定参数构建的 `_SearchDialog` 调用 `showDialog<Map<String, dynamic>>`。
- **用法：**
  ```dart
  final result = await showAnimeSearchDialog(
    context,
    initialQuery: query,
    currentTitle: _titleController.text.isEmpty ? null : _titleController.text,
    ...
  );
  if (result != null && mounted) {
    setState(() {
      if (result.containsKey('title')) {
        _titleController.text = result['title'] as String;
      }
      ...
  ```
  （`AnimeEditPage._showSearchDialog`，[`anime_edit_page.md`](anime_edit_page.md#_showsearchdialog)）
- **备注：** 返回映射中能出现的键的精确集合、以及每个键出现的条件，完全由下方的 [`_apply`](#_apply) 决定——调用方应把任何键都视为可选。

### `Future<void> _search()` <a id="_search"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 126 行）
- **用途：** 对当前查询文本查询每个已配置的元数据来源（经 [`AnimeSearchService.searchAll`](../services/anime_search_service.md#searchall)）。
- **输入：** 无（读取 `_queryController.text`）。
- **返回：** `Future<void>`。
- **副作用：** 执行网络请求；`setState` `_searching`、`_results`、`_error`。
- **算法：**
  1. 修剪查询；为空则提前返回。
  2. `setState` 进入加载状态，清除先前的结果/错误。
  3. Await `AnimeSearchService.searchAll(query)`；成功时存储结果，列表为空时设置"无结果"错误消息。
  4. 任何抛出的异常时，把 `e.toString()` 存为 `_error`。
- **用法：**
  ```dart
  FilledButton(
    onPressed: _searching ? null : _search,
    child: Text(l10n.searchButton),
  ),
  ```
  （`_buildSearchView`，同一文件；查询字段的 `onSubmitted` 也触发）
- **备注：** 与 `anime_edit_page.dart` 中的 `_WatchUrlSearchDialogState._search`（[`anime_edit_page.md`](anime_edit_page.md#_search-watchurl)）不同——后者只搜索 `anime1.me` 找观看页链接，而不是跨 `AnimeSearchService.searchAll` 的来源搜索元数据。

### `void _selectResult(AnimeSearchResult result)` <a id="_selectresult"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 160 行）
- **用途：** 从搜索阶段切换到所选结果的预览阶段，并根据结果实际提供的数据预选默认"应用"的字段。
- **输入：** `result` — 被点击的 `AnimeSearchResult`。
- **返回：** 无。
- **副作用：** `setState` `_selected`、`_phase`、`_toggles`，并清除任何先前获取的封面。
- **算法：**
  1. 设 `_selected = result`、`_phase = _Phase.preview`，清除 `_fetchedCoverPath`/`_coverPreview` 和 `_toggles`。
  2. 对 `title`/`titleJa`/`episodes`（→`endEpisode` 切换键）/`firstAirDate`/`airDayOfWeek`/`airTime`/`notes`（来自 `summary`）各一：只在结果确实为其提供非空值时才把该切换设为 `true`。
  3. 结果有 `coverImageUrl` 时，把 `'cover'` 切换设为 `false`（默认关——应用封面需要先显式 [`_fetchCover`](#_fetchcover)）。
- **用法：**
  ```dart
  onTap: () => _selectResult(r),
  ```
  （`_buildSearchResults`，同一文件，每个结果 `ListTile` 上）
- **备注：** 结果中没有数据的字段（如无 `airTime`）干脆没有切换条目——[`_apply`](#_apply) 的 `_toggles['airTime'] == true` 检查把缺失键与 `false` 同等对待。

### `Future<void> _fetchCover()` <a id="_fetchcover"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 184 行）
- **用途：** 下载所选结果的封面图像并本地暂存，使它可被预览，且如果用户保持切换开启就被应用。
- **输入：** 无（读取 `_selected?.coverImageUrl`）。
- **返回：** `Future<void>`。
- **副作用：** 经 `ImageService.saveImageFromUrl` 执行网络请求；经 `ImageService.resolve` 读取保存的文件；`setState` `_fetchingCover`、`_fetchedCoverPath`、`_coverPreview`、`_toggles['cover']`；失败时显示 `SnackBar`。
- **算法：**
  1. 没有 `coverImageUrl` 时提前返回。
  2. `setState(() => _fetchingCover = true)`。
  3. Await `ImageService.saveImageFromUrl(url)`；返回路径且组件仍 mounted 时，经 `ImageService.resolve` 解析为 `File`，然后 `setState` 暂存路径、`FileImage` 预览、`_toggles['cover'] = true` 和 `_fetchingCover = false`。
  4. 保存返回 `null` 时，只清除加载标志。
  5. 任何抛出的异常时，清除加载标志并显示带错误消息的 `SnackBar`。
- **用法：**
  ```dart
  TextButton.icon(
    onPressed: _fetchCover,
    icon: const Icon(Icons.download, size: 16),
    label: Text(l10n.searchFetchCover),
  ),
  ```
  （`_buildFieldList`，只在尚未获取封面时显示）
- **备注：** 成功获取封面也会强制启用 `'cover'` 切换——没有办法只获取预览而不默认"应用"它；用户之后必须手动取消勾选才能丢弃它。

### `void _apply()` <a id="_apply"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 221 行）
- **用途：** 从当前切换开启的任何字段构建稀疏结果映射，并带它关闭对话框。
- **输入：** 无（读取 `_selected` 和 `_toggles`）。
- **返回：** 无。
- **副作用：** `Navigator.of(context).pop(result)`。
- **算法：**
  1. 没有选中任何东西时提前返回。
  2. 对 `title`/`titleJa`/`episodes`→`endEpisode`/`firstAirDate`/`airDayOfWeek`/`airTime` 各一：只在切换为 `true` **且**结果确实有非 null 值时才把它包含进结果映射。
  3. 特例：`firstAirDate` 切换开启但来源没有直接提供 `airDayOfWeek` 时，从 `firstAirDate.weekday` 派生它（`1=周一..7=周日`），即使它自己的切换未必设置，也加入结果。
  4. 同样包含 `notes`（来自 `summary`），`'cover'` 切换开启时包含 `coverImage`（来自 `_fetchedCoverPath`）。
  5. `infoUrl`（来自 `sourceUrl`）非空时总是包含，无论任何切换。
  6. `Navigator.of(context).pop(result)`。
- **用法：**
  ```dart
  FilledButton(
    onPressed: _toggles.values.any((v) => v) ? _apply : null,
    child: Text(l10n.searchApply),
  ),
  ```
  （`_buildPreviewView`，同一文件——至少一个切换开启前禁用）
- **备注：** 来源提供 `infoUrl` 时无条件应用它——它没有复选框，与其他每个字段都不同；因此返回映射即使其他每个切换都关着也可能含 `infoUrl`，所以"应用"按钮启用（只要求*某个*切换开启）并不意味着最终映射只限于切换过的字段。
