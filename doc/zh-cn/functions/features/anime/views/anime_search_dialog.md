# lib/features/anime/views/anime_search_dialog.dart

在线元数据搜索对话框。`showAnimeSearchDialog` 打开一个两阶段模态框：**搜索阶段**列出
[`../services/anime_search_service.md`](../services/anime_search_service.md) 中各来源的命中，
**预览阶段**让用户勾选选中结果中要应用哪些字段。它返回一个字段名 → 值的
`Map<String, dynamic>`，由 `anime_edit_page.dart` 写入其表单控制器。

该对话框只能从 `anime_edit_page.dart` 进入，而后者把它放在 `AppFlavor.isFull` 门禁之后——flavor
门禁规则见
[`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showAnimeSearchDialog`](#showanimesearchdialog) | 顶层函数 | A | 打开搜索对话框并返回要应用的字段。 |
| `_SearchDialog(...)` | 构造函数（`_SearchDialog`） | B | 保存预览中作为「当前」显示的现有字段值。 |
| `createState` | 方法（`_SearchDialog`） | B | Flutter 生命周期覆写。 |
| `initState` | 方法（`_SearchDialogState`） | B | 用 `initialQuery` 初始化查询控制器。 |
| `dispose` | 方法（`_SearchDialogState`） | B | 释放查询控制器。 |
| [`_search`](#search) | 方法（`_SearchDialogState`） | A | 执行搜索，在每个来源回应时显示结果，并重置结果列表控件。 |
| [`_visibleResults`](#visibleresults) | getter（`_SearchDialogState`） | A | 对原始结果列表应用当前过滤条件与排序。 |
| [`_availableSources`](#availablesources) | getter（`_SearchDialogState`） | A | 列出当前原始结果中出现过的来源名。 |
| [`_selectResult`](#selectresult) | 方法（`_SearchDialogState`） | A | 进入预览阶段并预设各字段复选框。 |
| [`_externalMetaFieldCount`](#externalmetafieldcount) | 方法（`_SearchDialogState`） | A | 统计一条结果实际携带多少个外部元数据字段。 |
| `_fetchCover` | 方法（`_SearchDialogState`） | B | 下载封面图并显示前后对比预览。 |
| [`_apply`](#apply) | 方法（`_SearchDialogState`） | A | 用已勾选的字段值关闭对话框。 |
| `build` | 方法（`_SearchDialogState`） | B | 渲染搜索阶段或预览阶段。 |
| `_buildSearchView` | 方法（`_SearchDialogState`） | B | 查询框、搜索按钮、显示部分结果时的紧凑进度条（1.6.1）、工具栏与结果列表。 |
| [`_buildResultToolbar`](#buildresulttoolbar) | 方法（`_SearchDialogState`） | A | 构建结果列表上方的排序/过滤/分组工具栏。 |
| `_sortLabel` | 方法（`_SearchDialogState`） | B | 单个 `_SearchSort` 值的本地化标签。 |
| [`_showFilterSheet`](#showfiltersheet) | 方法（`_SearchDialogState`） | A | 在底部面板中展示来源与字段过滤条件。 |
| `_buildSearchResults` | 方法（`_SearchDialogState`） | B | 在完整进度面板（仅在首批结果到达之前）、错误、空、分组或平铺列表之间选择。 |
| [`_buildSearchProgress`](#_buildsearchprogress) | 方法 | A | 在检索进行中以完整面板或紧凑窄条显示哪些来源已回应。 |
| `_sourceChip` | 方法 | B | 渲染单个来源的等待/找到/失败状态。 |
| [`_buildGroupedResults`](#buildgroupedresults) | 方法（`_SearchDialogState`） | A | 把结果列表渲染成每个来源一个可折叠分区。 |
| [`_resultTile`](#resulttile) | 方法（`_SearchDialogState`） | A | 构建搜索结果列表的一行。 |
| [`_secondaryLine`](#secondaryline) | 方法（`_SearchDialogState`） | A | 组合结果下方的次要元数据行。 |
| [`_showResultDetails`](#showresultdetails) | 方法（`_SearchDialogState`） | A | 不截断地展示一条结果的全部名称与字段。 |
| [`_detailRows`](#detailrows) | 方法（`_SearchDialogState`） | A | 构建结果详情面板中带标签的元数据行。 |
| `_copyToClipboard` | 方法（`_SearchDialogState`） | B | 复制一个值并用 SnackBar 确认。 |
| `_buildPreviewView` | 方法（`_SearchDialogState`） | B | 来源标识、字段列表与取消/应用按钮。 |
| [`_buildFieldList`](#buildfieldlist) | 方法（`_SearchDialogState`） | A | 构建预览阶段的逐字段复选框列表。 |
| [`_buildExternalMetaSummary`](#buildexternalmetasummary) | 方法（`_SearchDialogState`） | A | 展示外部元数据复选框将要应用的内容。 |
| `_coverColumn` | 方法（`_SearchDialogState`） | B | 标签在上、缩略图在下的列。 |
| `_fieldTile` | 方法（`_SearchDialogState`） | B | 一行「当前 → 已获取」复选框。 |
| `_buildHeader` | 方法（`_SearchDialogState`） | B | 带可选返回按钮与关闭按钮的标题栏。 |
| `_dayName` | 方法（`_SearchDialogState`） | B | `1..7` 的本地化星期名。 |
| `_truncate` | 方法（`_SearchDialogState`） | B | 按最大长度省略字符串。 |

本文件还声明了两个没有文档注释的私有枚举：`_Phase`（`search`、`preview`）与 `_SearchSort`
（`relevance`、`firstAirDate`、`episodes`、`source`）。它们的成员带 `///` 注释；枚举本身在此计为类型
而非声明。

## 文档

### `Future<Map<String, dynamic>?> showAnimeSearchDialog(BuildContext context, {initialQuery, currentTitle, currentTitleJa, currentEndEp, currentFirstAirDate, currentAirDay, currentAirTime, currentCoverImage, currentNotes, currentExternalMeta})` <a id="showanimesearchdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 17 行）
- **用途：** 打开番剧搜索对话框，返回用户选择应用的字段。
- **输入：** `initialQuery` 用于初始化查询框；每个 `current*` 参数是编辑表单的现有值，会显示在对应抓取值旁边作为「当前」，让用户看清某个复选框会覆盖什么。
- **返回：** `Future<Map<String, dynamic>?>` —— 字段名 → 值，取消时为 `null`。
- **副作用：** 显示一个模态对话框；对话框自身会执行网络 I/O。
- **备注：** `currentExternalMeta` 不只用于显示——[`_apply`](#apply) 会把新抓取的元数据*折叠进*它，因此从另一个来源应用第二条结果时，第一条贡献的内容会被保留而不是被替换。

### `Future<void> _search()` <a id="search"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 164 行）
- **用途：** 执行搜索并重置结果列表控件。
- **返回：** 无。
- **副作用：** 经 `AnimeSearchService.searchAll` 执行网络 I/O；每个来源回应时重建状态；递增 `_searchGeneration`。
- **算法：**
  1. 查询为空白或已有检索在进行时直接返回。
  2. 读取 `Localizations.localeOf(context).toLanguageTag()` 作为 `preferredLanguage`，递增 `_searchGeneration`，并定义 `current()` 为「仍已挂载且仍是最新一次检索」。
  3. 清空结果、错误与全部过滤条件，并在首批结果到达**之前**保存 `AnimeSearchService.queryVariants(query)` 和语言，使部分结果已能按相关度排序。
  4. Await `searchAll`，`onProgress` 保存 `_progress`，`onResults`（1.6.1）保存 `_results`，两者都只在 `current()` 时生效。
  5. 返回后若 `current()` 仍成立，保存最终结果并清除 `_searching`；列表为空时把 `_error` 设为「无结果」文案。
  6. 抛出异常时（且 `current()`），清除 `_searching`；只有尚无任何结果到达时才把 `_error` 设为异常文本。
- **备注：** 变体缓存在 state 中是刻意的——每次按相关度排序的重建都要用它们打分，逐帧重新推导既浪费又可能与服务实际检索时使用的集合产生偏差。每次新搜索都重置过滤条件，是因为上一次查询的某个来源 chip 在新结果中可能根本不存在。自 1.6.1 起，列表在最慢的来源结束之前很久就已可用，并随更多结果到达重新排序；已有部分结果时发生的错误会保留这些结果。代次检查会丢弃仍在后台收尾的较早检索的回调。它维护的 `int _searchGeneration` 字段没有 `/// Purpose:` 块，也没有对应行。

### `List<AnimeSearchResult> get _visibleResults` <a id="visibleresults"></a>
- **种类：** `_SearchDialogState` 的 getter
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 200 行）
- **用途：** 对原始结果列表应用当前过滤条件与排序。
- **返回：** `List<AnimeSearchResult>`。
- **副作用：** 无。
- **算法：** 过滤掉被隐藏的来源，以及（开关打开时）没有封面或没有首播日期的结果。随后按当前 `_SearchSort` 排序：`relevance` 按 `AnimeSearchService.relevance` 降序；`firstAirDate` 最新在前；`episodes` 最多在前；`source` 按字母序、以相关度作为同分判据。
- **备注：** 对 `firstAirDate` 与 `episodes`，**缺少**该值的结果无论排序方向都沉到底部，而不是按 0 参与排序——未知集数绝不能压过已知集数。

### `List<String> get _availableSources` <a id="availablesources"></a>
- **种类：** `_SearchDialogState` 的 getter
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 249 行）
- **用途：** 列出当前原始结果中出现过的来源名。
- **返回：** 按 `AnimeSearchSource.all` 顺序排列的 `List<String>`。
- **副作用：** 无。
- **备注：** 驱动过滤 chip，因此没有返回结果的来源绝不会作为过滤项出现。按固定顺序而非首次出现顺序排列，可让 chip 行在多次搜索之间保持稳定。

### `void _selectResult(AnimeSearchResult result)` <a id="selectresult"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 259 行）
- **用途：** 进入预览阶段并预设各字段复选框。
- **副作用：** 重建状态；清除此前已抓取的封面。
- **算法：** 把 `_phase` 切到 `preview`，并预先勾选该结果实际提供的每个字段——标题、日文标题、集数、首播日期、播出星期、播出时间、备注，以及（当 [`_externalMetaFieldCount`](#externalmetafieldcount) 非零时）外部元数据。
- **备注：** 封面复选框刻意保持**未勾选**：它需要显式抓取，因为应用它会下载并写入一个图片文件。

### `int _externalMetaFieldCount(AnimeSearchResult r)` <a id="externalmetafieldcount"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 285 行）
- **用途：** 统计一条结果实际携带多少个外部元数据字段。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** 对每个非空的 `synonyms`、`titleRomaji`、`titleEn`、`format`、`status`、`durationMinutes`、`genres`、`studios`、`endDate` 各加一，评分块整体再加一。
- **备注：** 为零表示该来源除基础字段外什么都没提供，此时根本不显示外部元数据复选框。该计数同时显示在复选框标签中，因此「资料库信息：来自 AniList 的 6 项信息」无需展开就能告诉用户他们正在接受什么。

### `void _apply()` <a id="apply"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 342 行）
- **用途：** 用已勾选的字段值关闭对话框。
- **副作用：** 携带结果 map 弹出对话框。
- **算法：** 把每个已勾选字段复制进 map。当勾选了 `firstAirDate` 但来源没有报告 `airDayOfWeek` 时，从日期推导星期。勾选外部元数据时，构建 `AnimeSearchService.toExternalMeta(r)` 并经 `mergedWith` 折叠进 `widget.currentExternalMeta`。只要存在 `sourceUrl`，`infoUrl` 就无条件设置。
- **备注：** `infoUrl` 不做成复选框，因为它记录的是*这些元数据从哪里来*，而后续的刷新流程需要它——见 [`../services/anime_search_service.md`](../services/anime_search_service.md)。

### `Widget _buildResultToolbar(AppLocalizations l10n)` <a id="buildresulttoolbar"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 462 行）
- **用途：** 构建结果列表上方的排序/过滤/分组工具栏。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 一行内包含「共 M 条，显示 N 条」计数、按来源分组开关、一个 `PopupMenuButton<_SearchSort>`，以及一个过滤按钮——其图标在有过滤条件生效时从 `filter_alt_outlined` 切换为 `filter_alt`。
- **备注：** 只有搜索产生结果后才渲染，因此空对话框保持简洁。「弹出菜单 + 随状态变化的图标」这一模式沿用了 `management_page.dart` 中的归档过滤器。

### `Future<void> _showFilterSheet(AppLocalizations l10n)` <a id="showfiltersheet"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 537 行）
- **用途：** 在底部面板中展示来源与字段过滤条件。
- **副作用：** 打开模态面板，并在用户切换时修改过滤状态。
- **算法：** 一个 `StatefulBuilder` 面板，包含 [`_availableSources`](#availablesources) 每一项对应的 `FilterChip`、两个 `SwitchListTile` 与一个重置按钮。局部 `toggle()` 辅助函数**同时**调用父级的 `setState` 与面板自身的 `setState`，使面板背后的列表实时更新。
- **备注：** 过滤条件存为 `_hiddenSources`（排除集合）而非包含集合，因此后续搜索中新出现的来源默认可见，而「重置」只需清空该集合。

### `Widget _buildGroupedResults(AppLocalizations l10n, List<AnimeSearchResult> visible)` <a id="buildgroupedresults"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 671 行）
- **用途：** 把结果列表渲染成每个来源一个可折叠分区。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 按 `source` 把 `visible` 分桶，再为每个来源渲染一个初始展开的 `ExpansionTile`，尾部槽位显示该组条数。
- **备注：** 分区保持固定的 `AnimeSearchSource.all` 顺序而非当前排序顺序，因此切换排序只会重排分区*内部*的行，而不会打乱分区本身。

### `Widget _resultTile(AppLocalizations l10n, AnimeSearchResult r)` <a id="resulttile"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 713 行）
- **用途：** 构建搜索结果列表的一行。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 一个 `ListTile`，含网络封面缩略图、被列出全部已知名称的 `Tooltip` 包裹的 `r.displayTitle`、第一行「来源 · 日文标题 · 集数」副标题，以及其下的 [`_secondaryLine`](#secondaryline)。`onTap` 选中该结果；`onLongPress` 打开 [`_showResultDetails`](#showresultdetails)。
- **备注：** 标题刻意截断为一行——番剧标题经常超出对话框宽度。长按（触摸）与悬停提示（桌面）是通向完整名称的两条出口，而完整名称正是详情面板存在的理由。

### `String? _secondaryLine(AppLocalizations l10n, AnimeSearchResult r)` <a id="secondaryline"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 773 行）
- **用途：** 组合结果下方的次要元数据行。
- **返回：** `String?` —— 来源未提供任何这些字段时返回 `null`。
- **副作用：** 无。
- **算法：** 用 ` · ` 连接存在的项：形如 `★ 9.2/10` 的评分、作品形式、播出星期加时间、首播日期（仅在没有播出星期时）、第一个制作公司。
- **备注：** 返回 `null` 而非空串，可以让调用方去掉 `isThreeLine`，因此来自 filmarks.com 这类信息稀薄来源的行会保持紧凑，而不是预留一行空白。

### `Future<void> _showResultDetails(AppLocalizations l10n, AnimeSearchResult r)` <a id="showresultdetails"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 794 行）
- **用途：** 不截断地展示一条结果的全部名称与字段。
- **副作用：** 打开模态面板；复制会写入系统剪贴板。
- **算法：** 一个 `DraggableScrollableSheet`，列出来源 chip、`r.allTitles` 每一项（作为带复制按钮的 `SelectableText`）、[`_detailRows`](#detailrows) 生成的各行，以及完整简介。
- **备注：** 名称使用 `SelectableText`，因此即使某个名称远超触发本面板的那一行的宽度，也能被复制出来。这正是对「列表把名称截断了，我看不全」的回答——这里没有任何内容被省略。

### `List<Widget> _detailRows(AppLocalizations l10n, AnimeSearchResult r, ThemeData theme)` <a id="detailrows"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 870 行）
- **用途：** 构建结果详情面板中带标签的元数据行。
- **返回：** `List<Widget>`。
- **副作用：** 无。
- **算法：** 从该结果提供的每个字段构建 `(标签, 值)` 列表——集数、首播/完结日期、播出星期与时间、作品形式、播出状态、时长、制作公司、类型标签、含票数与排名的评分、来源 URL——再把每项渲染为定宽标签加 `SelectableText` 值。
- **备注：** 来源未提供的字段被整行省略而非留空，因此面板长度诚实地反映了该来源掌握多少信息。

### `Widget _buildFieldList(AppLocalizations l10n, AnimeSearchResult r)` <a id="buildfieldlist"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 1007 行）
- **用途：** 构建预览阶段的逐字段复选框列表。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 为每个已提供字段渲染一个 `_fieldTile`（标题、日文标题、集数、首播日期、播出星期、播出时间、备注），随后是外部元数据复选框及其只读 chip 摘要，最后是封面图区块及其显式抓取按钮与前后对比预览。
- **备注：** 外部元数据是覆盖制作公司/类型标签/作品形式/播出状态/时长/别名/评分全部内容的*单个*复选框。逐字段拆分会让列表无法使用，而这些字段本来就总是从同一个来源一起到达。

### `Widget _buildExternalMetaSummary(AppLocalizations l10n, AnimeSearchResult r)` <a id="buildexternalmetasummary"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（第 1161 行）
- **用途：** 展示外部元数据复选框将要应用的内容。
- **返回：** `Widget` —— 无内容可展示时返回 `SizedBox.shrink()`。
- **副作用：** 无。
- **算法：** 一个紧凑的 chip `Wrap`：作品形式、播出状态、时长、每个制作公司、每个类型标签，以及评分。
- **备注：** 设计上是只读的——上方那个复选框决定其中是否有任何内容被写入。它存在的意义是让用户在接受之前看清「来自 AniList 的 6 项信息」究竟指什么。

### `Widget _buildSearchProgress(AppLocalizations, {bool compact = false})` <a id="_buildsearchprogress"></a>
- **种类：** 方法
- **来源：** `lib/features/anime/views/anime_search_dialog.dart`（约第 708 行）
- **用途：** 在检索仍在进行时，显示哪些来源已经回应。
- **输入：** `l10n`；`compact`（1.6.1）—— 显示在部分结果上方的窄条，取代完整面板。
- **返回：** `Widget`。
- **副作用：** 无。
- **算法：** 用 `AnimeSearchProgress.fraction` 画一条确定进度条，配一行说明当前轮次与计数的文案，
  再为每个来源画一个 chip——等待中是转圈，落地后是对勾加结果条数，抛异常则是错误图标。`compact`
  缩小内边距与间距，并用 `bodySmall` 显示文案。
- **用法：**
  ```dart
  if (_searching && _results.isNotEmpty)
    _buildSearchProgress(l10n, compact: true),
  ```
  （`_buildSearchView`，位于结果工具栏上方；`_searching && _results.isEmpty` 时由 `_buildSearchResults` 显示完整面板）
- **备注：** 取代了本界面直到 1.5.0 一直使用的光秃秃 `CircularProgressIndicator`。一次检索确实可能
  耗时约半分钟——每个来源各有 10–15 秒超时，且空手而归的来源会用首轮采集到的标题再查一次——
  在这段时间里，孤零零一个转圈与真正的卡死无法区分。

  真正回答问题的是那些 chip：当某一个来源很慢时，其余四个已经打上对勾，这说明的是「在工作」
  而不是「卡住了」，并且直接点名了拖后腿的那一个。

  在首个进度快照到达之前回退为普通转圈（`compact` 时为一条无确定值的 `LinearProgressIndicator`），因此不会出现「空进度条且没有 chip」的那一帧。

  自 1.6.1 起，完整面板只在首批结果到达之前占满对话框；此后它收缩为已可使用的结果列表上方的紧凑窄条，
  其余来源则继续完成。
