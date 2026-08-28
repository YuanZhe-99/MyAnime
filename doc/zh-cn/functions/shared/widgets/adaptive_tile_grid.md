# lib/shared/widgets/adaptive_tile_grid.dart

多列列表布局的控件部分：两个把扁平条目列表转成行的构建器，以及让用户挑选列数的应用栏控件。相关算术单独位于
[`../utils/adaptive_layout.md`](../utils/adaptive_layout.md)；本文件只负责由其构建控件。

被三个数据浏览模块全部使用——`home_page.dart`、`management_page.dart` 与 `statistics_page.dart`（见
[../../features/anime/views/home_page.md](../../features/anime/views/home_page.md) 及其同级页面）。该行为的概念
层描述见 [../../../adaptive-layout.md](../../../adaptive-layout.md)。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| [`adaptiveTileRow`](#adaptivetilerow) | 顶层函数 | A | 构建多列列表中的一行，从左向右填充。 |
| [`adaptiveTileRows`](#adaptivetilerows) | 顶层函数 | A | 把列表子项构建成行，单列或多列。 |
| [`listColumnsButton`](#listcolumnsbutton) | 顶层函数 | A | 构建挑选列表列数的应用栏控件。 |

## 文档

### `Widget adaptiveTileRow({required int rowIndex, required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerow"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`（约第 19 行）
- **用途：** 构建属于多列列表某一行的那些条目。
- **输入：** `rowIndex`——从零开始的行号；`columns`——每行条目数；`itemCount`——扁平列表中的条目总数；
  `itemBuilder`——按条目在扁平列表中的下标构建单个条目；`gap`——列间距。
- **返回：** 一个由等宽条目组成、顶部对齐的 `Row`。
- **副作用：** 除构建控件外无。
- **算法：** 对 `0..columns-1` 中的每一列 `c`，在除首列之外的每列前插入 `SizedBox(width: gap)`，随后是一个
  `Expanded`；当 `rowIndex * columns + c` 在范围内时其中放 `itemBuilder(...)`，否则放 `SizedBox.shrink()`。
  因此跨连续行的下标顺序是从左到右、然后从上到下。
- **用法：**
  ```dart
  return ListView.builder(
    itemCount: listRowCount(animeList.length, columns),
    itemBuilder: (context, row) => adaptiveTileRow(
      rowIndex: row,
      columns: columns,
      itemCount: animeList.length,
      itemBuilder: (i) => _buildAnimeTile(animeList[i], theme, l10n, columns),
    ),
  );
  ```
  （出自 `_ManagementPageState._buildQuarterView`）
- **备注：** **刻意采用 `Expanded` 子项的 `Row` 而非 `GridView`。** 三个列表模块中有两个把条目构建为外层滚动
  视图的子项——统计页的外层 `ListView`，以及首页那个同时承载日历的异构 `ListView`——在那里嵌套可滚动控件需要
  `shrinkWrap: true` 与 `NeverScrollableScrollPhysics`。第三个即管理页，依赖 `ListView.builder` 的虚拟化，而
  预先构建的网格会在库容量较大时把这一点丢掉。以 `listRowCount` 行数为基础用构建器供给，两个性质都得以保留。
  `GridView` 还会强制每个单元格有固定的 `childAspectRatio`，在大字号缩放下很脆弱；`Expanded` 子项则保持其自然
  高度。

  不满的末行以空单元补位而非任其拉伸，因此末行条目与其上方的列对齐。

### `List<Widget> adaptiveTileRows({required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerows"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`（约第 47 行）
- **用途：** 产出可直接展开进 `ListView` 或 `Column` 的列表子项。
- **输入：** `columns`、`itemCount`、`itemBuilder`、`gap`——同上。
- **返回：** `List<Widget>`。
- **副作用：** 除构建控件外无。
- **算法：** 当 `columns <= 1` 时返回 `List.generate(itemCount, itemBuilder)`——原样的条目。否则以
  `adaptiveTileRow` 为基础返回 `List.generate(listRowCount(itemCount, columns), ...)`。
- **用法：**
  ```dart
  ...adaptiveTileRows(
    columns: columns,
    itemCount: unwatched.length,
    itemBuilder: (i) => _buildEpisodeTile(unwatched[i], theme, l10n, settings),
  ),
  ```
  （出自 `_HomePageState.build`）
- **备注：** 单列时原样返回条目，正是让调用方能够把单列条目包进网格无法承载的东西里的原因。管理页依赖这一点：
  它的左右滑动编辑/删除 `Dismissible` 在单列时保留，在多列时被去掉，因为在一个窄单元格内水平拖动的含义是含糊
  的。列表作为外层滚动视图的子项时用本函数；`ListView.builder` 必须保留虚拟化时直接用 `adaptiveTileRow`。

### `Widget listColumnsButton(BuildContext context, {required int preference, required int capacity, required ValueChanged<int> onChanged})` <a id="listcolumnsbutton"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`（约第 79 行）
- **用途：** 在页面应用栏中提供列数选择。
- **输入：** `context`；`preference`——存储的选择，`listColumnsAuto` 或一个固定列数；`capacity`——当前宽度所能
  承载的最大列数；`onChanged`——接收新的偏好值。
- **返回：** 一个 `PopupMenuButton<int>`，当 `capacity <= 1` 时返回 `SizedBox.shrink()`。
- **副作用：** 除用户选择时调用 `onChanged` 外无。
- **算法：** 窗口无法承载多于一列时返回空控件。否则返回一个 `PopupMenuButton<int>`，图标为
  `Icons.view_column_outlined`，`initialValue: preference`，菜单项为 `listColumnsAuto` 后接
  `1..listMaxColumns`。
- **用法：**
  ```dart
  listColumnsButton(
    context,
    preference: settings.statsListColumns,
    capacity: capacity,
    onChanged: (value) =>
        ref.read(appSettingsProvider.notifier).setStatsListColumns(value),
  ),
  ```
  （出自 `_StatisticsPageState.build`，位于应用栏的 `actions` 中）
- **备注：** 只容得下一列时是**隐藏而非禁用**，因此手机和折叠状态的外屏永远不会显示一个做不了任何事的控件。
  即便当前宽度用不完，菜单仍然提供直到 `listMaxColumns` 的每一个列数，这样偏好可以在折叠状态下设定并在展开时
  生效；勾选标记跟随存储的偏好，而实际渲染的是被 `listColumnCount` 钳制后的该偏好。三个模块各存一份自己的
  偏好，因此同一个控件会以三个不同的值出现三次。
