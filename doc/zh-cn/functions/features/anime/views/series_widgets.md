# lib/features/anime/views/series_widgets.dart

系列界面（1.6.0）：详情页的*系列*卡片及其打开的管理面板。两者都建立在 [`../services/series_service.md`](../services/series_service.md) 中的纯引擎之上；详情页在 `_buildDetailChildren` 与 `_runSeriesAction`（[`anime_detail_page.md`](anime_detail_page.md)）中接入它们。管理面板经 `canSplitLayout`（[`../../../shared/utils/adaptive_layout.md`](../../../shared/utils/adaptive_layout.md)）在底部面板与对话框之间选择，因此遵循全应用统一的分栏规则。行为说明见 [`../../../../features/series-linking.md`](../../../../features/series-linking.md)。组件测试：`test/series_card_ui_test.dart`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `SeriesCard.new` | 构造函数（`SeriesCard`） | B | 为至少两个成员的系列、当前记录和两个回调创建系列卡片。 |
| [`SeriesCard.build`](#seriescard-build) | 方法（`SeriesCard`，组件构建） | A | 构建卡片：标题行、操作菜单和每个成员一行。 |
| `_memberTile` | 方法（`SeriesCard`，组件辅助） | B | 一行成员：位置、标题、带已看/总数的季标签、状态图标；当前记录高亮且不可点按。 |
| `viewingStatusIcon` | 顶层函数 | B | 为 `AnimeViewingStatus` 选图标；卡片与面板共用。 |
| [`showSeriesManageSheet`](#showseriesmanagesheet) | 顶层函数 | A | 以底部面板或对话框打开管理面板。 |
| `SeriesManageSheet.new` | 构造函数（`SeriesManageSheet`） | B | 为一条记录及计算其编辑所用的索引创建面板。 |
| `SeriesManageSheet.createState` | 方法（`SeriesManageSheet`） | B | 创建状态对象。 |
| `_SeriesManageSheetState.initState` | 方法（`_SeriesManageSheetState`） | B | 从索引初始化可编辑的成员顺序。 |
| `_SeriesManageSheetState.dispose` | 方法（`_SeriesManageSheetState`） | B | 释放搜索控制器。 |
| [`_apply`](#_apply) | 方法（`_SeriesManageSheetState`） | A | 写入一次编辑产生的记录并关闭面板。 |
| [`_search`](#_search) | 方法（`_SeriesManageSheetState`） | A | 返回归一化标题包含搜索文本的片库记录。 |
| [`_SeriesManageSheetState.build`](#seriesmanagesheet) | 方法（`_SeriesManageSheetState`，组件构建） | A | 构建搜索框、建议和可重排的成员列表。 |
| `_header` | 方法（`_SeriesManageSheetState`，组件辅助） | B | 构建小节标题。 |

`SeriesAction` 枚举（`manage`、`addNextSeason`、`remove`、`letAppDecide`）没有 `/// Purpose:` 注释，不作为行索引；卡片菜单和详情页应用栏关联菜单都把它交给 `_runSeriesAction`。

## 文档

### `Widget build(BuildContext context)`（`SeriesCard`） <a id="seriescard-build"></a>
- **种类：** `SeriesCard` 的方法（组件构建）
- **来源：** `lib/features/anime/views/series_widgets.dart`（第 61 行）
- **用途：** 构建详情页的*系列*卡片。
- **输入：** `context`。字段：`series`（至少两个成员）、`current`、`onOpen`、`onAction`。
- **返回：** `Widget` — 一个 `Card`。
- **副作用：** 无；点按调用 `onOpen`，菜单选择调用 `onAction`。
- **算法：**
  1. 标题行：图标、*系列*和副标题——手动关联的系列显示*手动关联的系列*，自动归入的系列显示*自动归入*。
  2. 一个 `PopupMenuButton<SeriesAction>`：*管理系列…*、*添加下一季*、*移出系列*，以及仅当 `current` 自身带有可移除的 `seriesLink` 时出现的*交给应用自动判断*。
  3. 按系列顺序每个成员一个 `_memberTile`。
- **用法：**
  ```dart
  SeriesCard(
    series: series,
    current: anime,
    onOpen: (a) => context.push('/anime/detail/${a.id}'),
    onAction: _runSeriesAction,
  ),
  ```
  （`anime_detail_page.dart`，`_buildDetailChildren`）
- **备注：** 卡片位于 `_buildDetailChildren` 中，因此在双栏详情布局中渲染在右栏。

### `Future<bool> showSeriesManageSheet(BuildContext context, {required Anime anime, required SeriesIndex index})` <a id="showseriesmanagesheet"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/series_widgets.dart`（第 180 行）
- **用途：** 为 `anime` 打开系列管理面板。
- **输入：** `context`；`anime`；`index` — 由当前片库构建。
- **返回：** `Future<bool>` — 是否写入了任何内容。
- **副作用：** 显示模态界面；面板可能经 `AnimeStorage.addOrUpdateAll` 写入记录。
- **算法：** `canSplitLayout(width, height)` 成立时显示限制为 560 × 640 的 `Dialog`；否则显示受滚动控制、避开安全区、高度 85% 的模态底部面板。
- **用法：** `_runSeriesAction` 的 `manage` 分支，从卡片的*管理系列…*和应用栏的*关联到系列…*进入。
- **备注：** 没有新的断点：它复用全应用的分栏规则，因此会分栏的窗口得到对话框。见 [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。

### `Future<void> _apply(List<Anime> writes)` <a id="_apply"></a>
- **种类：** `_SeriesManageSheetState` 的方法
- **来源：** `lib/features/anime/views/series_widgets.dart`（第 270 行）
- **用途：** 写入一次编辑产生的记录并关闭面板。
- **输入：** `writes` — 来自 `SeriesEditor.link` 或 `reorder`。
- **返回：** `Future<void>`。
- **副作用：** 设置 `_busy`；一次 `AnimeStorage.addOrUpdateAll`；以 `true` 弹出面板。
- **备注：** 已有写入进行中时忽略调用，期间每个列表项和保存按钮都被禁用，因此双击不会写两次。

### `List<Anime> _search(String query)` <a id="_search"></a>
- **种类：** `_SeriesManageSheetState` 的方法
- **来源：** `lib/features/anime/views/series_widgets.dart`（第 283 行）
- **用途：** 返回匹配搜索文本的片库记录。
- **输入：** `query`。
- **返回：** `List<Anime>` — 至多 30 条，不含当前记录；查询为空时为空。
- **副作用：** 无。
- **算法：** 用 `AnimeSearchService.foldTitle` 归一化查询，然后保留（来自 `SeriesIndex.all`，按 `id` 顺序）任一 `seriesTitlesOf` 标题归一化后包含它的记录。
- **备注：** 归一化使字形与全半角差异无关紧要，因此 `进击` 能找到 `進撃`。

### `Widget build(BuildContext context)`（`_SeriesManageSheetState`） <a id="seriesmanagesheet"></a>
- **种类：** `_SeriesManageSheetState` 的方法（组件构建）
- **来源：** `lib/features/anime/views/series_widgets.dart`（第 306 行）
- **用途：** 构建管理面板：搜索、建议和成员顺序。
- **返回：** `Widget`。
- **副作用：** 不直接产生；点按调用 `_apply`。
- **算法：**
  1. 搜索框（*在番剧库中搜索*）。
  2. 有文本时：`_search` 的结果，或*没有匹配的番剧*。
  3. 无文本时：来自 `SeriesIndex.suggestionsFor` 的*建议*——关联建议的副标题在季标签后追加*衍生作品*或*不同版本*；然后——记录的系列至少有两个成员时——以带拖动手柄的 `SliverReorderableList` 显示的*本系列*，以及顺序改变后才启用的*保存顺序*按钮。
  4. 点按任一建议或搜索结果即应用 `SeriesEditor.link(current, tapped)`；*保存顺序*应用 `SeriesEditor.reorder`。
- **备注：** 关联会把当前记录移进被点按记录的系列（先把它固化）。点按或*保存顺序*之前什么都不写；关闭面板不写入任何内容。
