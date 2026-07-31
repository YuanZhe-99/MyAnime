# lib/features/anime/views/management_page.dart

`ManagementPage` 是季浏览器：一个可滑动的季度 `PageView`（2000–2040）外加一个为没有 `firstAirDate` 的动画准备的末尾"其他"页、跳转季度选择器（[`quarter_picker_dialog.md`](quarter_picker_dialog.md)）和全局标题搜索。它通过 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）读写，并用 [`Anime.airsInQuarter`](../models/anime.md#airsinquarter) 把动画放进季度。功能概览见 [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)，本页分组依赖的季度归属规则见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md#quarter-placement)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ManagementPage.new` | 构造函数（`ManagementPage`） | B | 创建 `ManagementPage` 实例。 |
| `ManagementPage.createState` | 方法（`ManagementPage`） | B | 为此组件创建可变状态对象。 |
| `_isOtherPage` | getter（`_ManagementPageState`） | B | 当前显示的页面是否是"其他"（无日期）页。 |
| [`_ManagementPageState.initState`](#initstate-mgmt) | 方法（`_ManagementPageState`） | A | 加载数据并把 `PageView` 定位到当前季度。 |
| `_ManagementPageState.dispose` | 方法（`_ManagementPageState`） | B | 注销同步重载回调并释放页面控制器。 |
| [`_load`](#_load) | 方法（`_ManagementPageState`） | A | 从存储重载所有动画。 |
| [`_animeForQuarter`](#_animeforquarter) | 方法（`_ManagementPageState`） | A | 过滤并排序在给定季度播出的动画。 |
| [`_otherAnime`](#_otheranime) | getter（`_ManagementPageState`） | A | 没有 `firstAirDate` 的动画，按标题排序。 |
| [`_searchResults`](#_searchresults) | 方法（`_ManagementPageState`） | A | 按不区分大小写的标题子串匹配过滤并排序动画。 |
| `_quarterLabel` | 方法（`_ManagementPageState`） | B | 把季度格式化为"`year` `season name`"。 |
| `_dayLabel` | 方法（`_ManagementPageState`） | B | 本地化星期几数字供动画块副标题使用。 |
| [`_deleteAnime`](#_deleteanime) | 方法（`_ManagementPageState`） | A | 确认并删除一条动画记录。 |
| [`_showAddOptions`](#_showaddoptions) | 方法（`_ManagementPageState`） | A | 显示新增/导入选择对话框并打开 + 跳转到结果动画。 |
| [`_jumpToAnimeQuarter`](#_jumptoanimequarter) | 方法（`_ManagementPageState`） | A | 把视图翻页到含给定动画的季度（或"其他"页）。 |
| [`_showQuarterPicker`](#_showquarterpicker) | 方法（`_ManagementPageState`） | A | 打开季度选择器对话框并把视图翻页到所选季度。 |
| `_ManagementPageState.build` | 方法（`_ManagementPageState`，组件构建） | B | 构建页面脚手架（搜索字段、季度视图、FAB）。 |
| `_buildSearchResults` | 方法（组件辅助） | B | 渲染全局搜索结果列表。 |
| `_buildQuarterView` | 方法（组件辅助） | B | 渲染季度导航行和可滑动的 `PageView`。 |
| `_buildAnimeTile` | 方法（组件辅助） | B | 渲染一个带滑动编辑/删除操作的动画行。 |
| `_Quarter.new` | 构造函数（`_Quarter`） | B | 把年和季度编号配对。 |

## 文档

### `void initState()` <a id="initstate-mgmt"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 58 行）
- **用途：** 注册同步重载回调、触发首次数据加载，并把 `PageView` 定位到含今天日期的季度。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 注册给 `AutoSyncService`；调用 `_load()`；创建 `_pageController`。
- **算法：**
  1. 把 `_load` 注册给 [`AutoSyncService.addOnLocalDataChanged`](../../../shared/services/auto_sync_service.md#addonlocaldatachanged) 并调用 `_load()`。
  2. 从 `DateTime.now()` 计算当前季度：`((now.month - 1) ~/ 3) + 1`。
  3. 经 `indexWhere` 在静态 `_quarters` 列表中找到该季度的索引；找不到时回退索引 `0`（给定 `_quarters` 覆盖 2000–2040，不应发生）。
  4. 用 `initialPage: _currentQuarterIndex` 构造 `_pageController`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
    ...
  }
  ```
  （同一文件——这个覆盖本身）
- **备注：** 与本批其他视图不同，这个 `initState` 做真实的内联计算（定位当前季度索引），而不只是委托给辅助方法，因此这里记为 Tier A。

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 88 行）
- **用途：** 把完整动画列表从存储重载进 `_allAnime`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.load()`；`setState` `_allAnime`。
- **算法：** Await `AnimeStorage.load()`；mounted 时 `setState(() => _allAnime = data.animeList)`。
- **用法：**
  ```dart
  AutoSyncService.instance.addOnLocalDataChanged(_load);
  _load();
  ```
  （`_ManagementPageState.initState`，同一文件；每个变更操作后也调用它刷新视图）
- **备注：** 无。

### `List<Anime> _animeForQuarter(_Quarter quarter)` <a id="_animeforquarter"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 98 行）
- **用途：** 计算一个季度页面上显示的动画列表，按 [`airsInQuarter`](../models/anime.md#airsinquarter) 过滤并为显示排序。
- **输入：** `quarter`。
- **返回：** `List<Anime>`。
- **副作用：** 无。
- **算法：**
  1. 把 `_allAnime` 过滤为 `a.airsInQuarter(quarter.year, quarter.q)` 为 `true` 的那些。
  2. 按 `airDayOfWeek` 排序（缺失值排最后，用 `8` 作哨兵），然后相同播出日的动画按 `displayTitle` 排序。
- **用法：**
  ```dart
  final quarter = _quarters[index];
  final animeList = _animeForQuarter(quarter);
  ```
  （`_buildQuarterView`，同一文件）
- **备注：** 无。

### `List<Anime> get _otherAnime` <a id="_otheranime"></a>
- **种类：** `_ManagementPageState` 的 getter
- **来源：** `lib/features/anime/views/management_page.dart`（约第 115 行）
- **用途：** 计算末尾"其他"页上显示的动画列表——没有 `firstAirDate` 的记录，[`airsInQuarter`](../models/anime.md#airsinquarter) 永远无法把其放入季度。
- **输入：** 无。
- **返回：** `List<Anime>`。
- **副作用：** 无。
- **算法：** 把 `_allAnime` 过滤为 `firstAirDate == null`，按 `displayTitle` 排序。
- **用法：**
  ```dart
  otherCount: _otherAnime.length,
  ```
  （`_showQuarterPicker`，同一文件；`_buildQuarterView` 渲染"其他"页时也直接读取）
- **备注：** 无。

### `List<Anime> _searchResults()` <a id="_searchresults"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 125 行）
- **用途：** 从搜索字段的当前文本计算全局搜索结果列表。
- **输入：** 无（读取 `_searchQuery`）。
- **返回：** `List<Anime>`。
- **副作用：** 无。
- **算法：** 小写化 `_searchQuery`；把 `_allAnime` 过滤为 `title` 或 `titleJa`（小写后）包含它的那些；按 `displayTitle` 排序匹配项。
- **用法：**
  ```dart
  Widget _buildSearchResults(ThemeData theme, AppLocalizations l10n) {
    final results = _searchResults();
    ...
  ```
  （`_buildSearchResults`，同一文件）
- **备注：** 独立匹配主标题和日文标题——*任一*字段包含查询即匹配，不只是当前显示的那个。

### `Future<void> _deleteAnime(Anime anime)` <a id="_deleteanime"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 176 行）
- **用途：** 与用户确认，然后删除一条动画记录。
- **输入：** `anime`。
- **返回：** `Future<void>`。
- **副作用：** 显示确认对话框（`confirmDelete`）；调用 `AnimeStorage.deleteAnime`；经 `_load()` 重载。
- **算法：** Await `confirmDelete(context, anime.displayTitle)`；拒绝则返回；否则 `AnimeStorage.deleteAnime(anime.id)` 后跟 `_load()`。
- **用法：**
  ```dart
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.startToEnd) {
      ...
    } else {
      await _deleteAnime(anime);
      return false;
    }
  },
  ```
  （`_buildAnimeTile`，`Dismissible` 上的滑动删除）
- **备注：** `Dismissible` 的 `confirmDismiss` 无论结果如何总是返回 `false`——块实际上绝不被框架真正移除；记录消失后列表只是经 `_load()` 刷新。

### `Future<void> _showAddOptions(BuildContext context)` <a id="_showaddoptions"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 188 行）
- **用途：** 显示"创建"vs"导入"选择对话框，然后导航到所选流程、打开结果动画的详情页，并把季度视图跳转到它。
- **输入：** `context`。
- **返回：** `Future<void>`。
- **副作用：** 显示 `SimpleDialog`；经 `context.push` 导航；可能运行导入捆绑流程（文件系统读）；经 `_load()` 重载；把 `_pageController` 翻页到新动画的季度。
- **算法：**
  1. 显示提供 `'create'`/`'import'` 的 `SimpleDialog`；未作选择被关闭则返回。
  2. `'create'` 时：push `/anime/edit`，重载；返回 ID 时 push 它的详情页、再次重载，然后用新 ID 调用 [`_jumpToAnimeQuarter`](#_jumptoanimequarter)。
  3. `'import'` 时：运行 `showImportBundleFlow(context)`，重载；导入任何 ID 时 push 第一个导入 ID 的详情页、再次重载，然后跳到它的季度。
- **用法：**
  ```dart
  floatingActionButton: FloatingActionButton(
    onPressed: () => _showAddOptions(context),
    tooltip: l10n.animeAdd,
    child: const Icon(Icons.add),
  ),
  ```
  （`_ManagementPageState.build`，同一文件）
- **备注：** 与 `HomePage._showAddOptions`（[`home_page.md`](home_page.md#_showaddoptions)）结构相同，但这个版本之后额外把 `PageView` 跳到新动画的季度，这正是管理页（与主页不同）需要额外 `_jumpToAnimeQuarter` 步骤的原因。

### `void _jumpToAnimeQuarter(String animeId)` <a id="_jumptoanimequarter"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 240 行）
- **用途：** 把季度 `PageView` 翻页到含给定动画的季度（或"其他"页）。
- **输入：** `animeId`。
- **返回：** 无。
- **副作用：** 可能调用 `_pageController.jumpToPage`。
- **算法：**
  1. 在 `_allAnime` 中按 `id` 找动画；找不到则返回。
  2. 它的 [`startQuarter`](../models/anime.md#startquarter) 为 `null`（无 `firstAirDate`）时，除非已在那个页面上，跳到"其他"页索引（`_quarters.length`）。
  3. 否则在 `_quarters` 中找匹配的 `(year, quarter)` 条目并跳到它，除非已在该页面上。
- **用法：**
  ```dart
  await context.push('/anime/detail/$newId');
  await _load();
  _jumpToAnimeQuarter(newId);
  ```
  （`_showAddOptions`，同一文件）
- **备注：** 用 `startQuarter`（动画的*起始* cour），不是更完整的 [`airsInQuarter`](../models/anime.md#airsinquarter) 跨度逻辑——跨多个季度的动画（如 `fullYear` 类型）总是跳到它的第一季，而不是它也在播的任何更晚季度。

### `Future<void> _showQuarterPicker()` <a id="_showquarterpicker"></a>
- **种类：** `_ManagementPageState` 的方法
- **来源：** `lib/features/anime/views/management_page.dart`（约第 264 行）
- **用途：** 打开年/季选择器对话框（[`showQuarterPickerDialog`](quarter_picker_dialog.md#showquarterpickerdialog)），范围限定为数据中实际出现的年份（外加当前年和下一年），并把视图翻页到用户选择的任何项。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示对话框；可能调用 `_pageController.jumpToPage`。
- **算法：**
  1. 把每部动画 `startQuarter` 的每个不同年份收集进集合，加当前年和下一年，然后取该集合的 min/max 作为选择器的年份边界。
  2. 调用 `showQuarterPickerDialog`，带一个 `countBuilder`，按 `(year, quarter)` 报告有多少动画满足 `airsInQuarter`——外加一个计数为 `_otherAnime.length` 的"其他"选项。
  3. 结果是"其他"选择时，跳到"其他"页索引；否则在 `_quarters` 中找匹配季度并跳到它（两种情况下都只在未已在该页上时）。
- **用法：**
  ```dart
  GestureDetector(
    onTap: _showQuarterPicker,
    child: Center(
      child: Row(
  ```
  （`_buildQuarterView`，点击导航行中的季度标签）
- **备注：** 选择器中显示的逐格计数来自 `airsInQuarter`（季度的完整潜在成员资格），而别处使用的 `_animeForQuarter` 应用相同过滤——因此计数总是与对应页面实际显示的内容匹配。
