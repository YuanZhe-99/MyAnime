# lib/shared/utils/adaptive_layout.dart

全应用范围的自适应布局策略：决定布局是否可以拆分的 `splitMinWidth`、`splitMinHeight`、`splitMinAspect` 三个
阈值，以及一旦可以拆分后决定列表分成几列的 `listTileMinWidth`、`listTileGap`、`listMaxColumns`、
`listColumnsAuto` 四个常量。在它们之上是四个纯函数。

该模块刻意只依赖 `dart:core`——它不含任何 Flutter 导入，`canSplitLayout` 接收两个 double 而非一个 `Size` 正是
出于这个原因——因此每个辅助函数都可直接进行单元测试（`test/adaptive_layout_test.dart`），而渲染结果则由
`test/list_columns_ui_test.dart` 与 `test/detail_layout_ui_test.dart` 在真实设备几何下单独覆盖。

这些数字的推导过程、折叠屏设备表格以及与 Google 规范的调和见
[../../../adaptive-layout.md](../../../adaptive-layout.md)。本页记录的是声明本身。

使用方：`detail_layout.dart`（见 [detail_layout.md](detail_layout.md)），其 `useDetailTwoPane` 是转发到
`canSplitLayout` 的单行委托；`home_page.dart`、`management_page.dart` 与 `statistics_page.dart` 用于各自的列表
列数；以及 `anime_storage.dart` 与 `app_settings.dart` 在校验存储的偏好时使用 `listColumnsAuto` 与
`listMaxColumns`。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| [`canSplitLayout`](#cansplitlayout) | 顶层函数 | A | 报告布局是否可以拆成分栏或多列。 |
| [`listColumnCapacity`](#listcolumncapacity) | 顶层函数 | A | 返回给定内容宽度能承载多少列表列。 |
| [`listColumnCount`](#listcolumncount) | 顶层函数 | A | 返回列表实际应当渲染的列数。 |
| [`listRowCount`](#listrowcount) | 顶层函数 | A | 返回在某个列数下一组条目需要多少行。 |

七个常量是没有 `/// Purpose:` 注释的普通声明，不作为独立行编入索引。

## 文档

### `bool canSplitLayout(double width, double height)` <a id="cansplitlayout"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/adaptive_layout.dart`（约第 44 行）
- **用途：** 判定视口的形状与尺寸是否适合拆分。
- **输入：** `width`、`height`——视口的逻辑像素尺寸，读自 `MediaQuery.sizeOf(context)`。
- **返回：** `bool`——三个条件全部成立时为 `true`。
- **副作用：** 无。
- **算法：** 三项彼此独立、必须全部通过的测试：
  1. `width >= splitMinWidth`（600.0）
  2. `height >= splitMinHeight`（480.0）
  3. `width / height >= splitMinAspect`（0.82）

  非正的高度在做除法之前即被拒绝。
- **用法：**
  ```dart
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(screen.width)
      : 1;
  ```
  （出自 `_HomePageState.build`，`lib/features/anime/views/home_page.dart`）
- **备注：** **宽高比测试是承重的那一项，这正是它不是一个单纯宽度断点的原因。** Galaxy Z Fold 8 展开后是 4:3
  的**横向**面板，因此竖持时它是 3:4——相对其高度比它所替代的近方形 Fold 7 更窄，尽管它更新。于是一台设备需要
  在同一个宽度下给出两个不同的答案。宽度下限是常见的 Material 3 *medium* / Android `sw600dp` 阈值。高度下限
  存在，是因为单靠宽高比测试会放行又宽又矮的视口——折叠状态的外屏或普通手机横持否则都会被拆分。完整推导、设备
  表格以及与 Google"用宽度而非宽高比"规范的刻意分歧见
  [../../../adaptive-layout.md](../../../adaptive-layout.md)。

### `int listColumnCapacity(double contentWidth)` <a id="listcolumncapacity"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/adaptive_layout.dart`（约第 68 行）
- **用途：** 报告列表所获得的宽度中能容纳多少个不低于 `listTileMinWidth` 的列。
- **输入：** `contentWidth`——列表可用的宽度，逻辑像素。
- **返回：** `int`，最小 1，最大 `listMaxColumns`（4）。
- **副作用：** 无。
- **算法：** `((contentWidth + listTileGap) / (listTileMinWidth + listTileGap)).floor()`，钳制到
  `[1, listMaxColumns]`。在分子上加一个间距，正是让这个算式计算列**之间**的间距、而不是每一列之后都算一个间距
  的原因。非正的宽度返回 1。
- **用法：**
  ```dart
  final contentWidth = screen.width - 32;
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(contentWidth)
      : 1;
  ```
  （出自 `_StatisticsPageState.build`，其列表位于 16 dp 的页面水平内边距之内）
- **备注：** 这是 Google 为 feed 布局推荐的自适应最小宽度做法，而非为每个断点写死一个列数。320 dp 是列表条目
  在其 40 × 56 封面、两行文字和最多两个尾部图标按钮把标题挤到无处容身之前所需要的宽度。请传入列表实际获得的
  宽度而非屏幕宽度，这样页面内边距已经被计入。

### `int listColumnCount({required double screenWidth, required double screenHeight, required double contentWidth, required int preference})` <a id="listcolumncount"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/adaptive_layout.dart`（约第 87 行）
- **用途：** 把拆分门控、宽度容量与用户存储的偏好合并为列表渲染的列数。
- **输入：** `screenWidth`、`screenHeight`——整块屏幕，决定是否允许拆分；`contentWidth`——列表自身获得的宽度；
  `preference`——`listColumnsAuto`（0）或一个固定的列数。
- **返回：** `int`，最小 1。
- **副作用：** 无。
- **算法：**
  1. `canSplitLayout(screenWidth, screenHeight)` 为假时返回 1。
  2. 计算 `listColumnCapacity(contentWidth)`。
  3. `preference == listColumnsAuto` 时返回容量，否则返回钳制到 `[1, capacity]` 的偏好值。
- **用法：**
  ```dart
  final columns = listColumnCount(
    screenWidth: screen.width,
    screenHeight: screen.height,
    contentWidth: screen.width,
    preference: settings.manageListColumns,
  );
  ```
  （出自 `_ManagementPageState.build`）
- **备注：** 门控读取屏幕而容量读取列表自身的宽度，这是刻意的；见 `canSplitLayout` 的备注以及
  [../../../adaptive-layout.md](../../../adaptive-layout.md) 中"门控量屏幕，容量量内容"一节。固定的偏好值是被
  **钳制而非拒绝**的，因此在桌面端设定的列数能在被带到折叠状态的手机上存活下来，并在展开时回来——存储的值永远
  不会被布局改写。

### `int listRowCount(int itemCount, int columns)` <a id="listrowcount"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/adaptive_layout.dart`（约第 99 行）
- **用途：** 当 `ListView.builder` 的每一项都是一行条目时，给出它的 `itemCount`。
- **输入：** `itemCount`——扁平列表中的条目数；`columns`。
- **返回：** `int`——空列表为 0，否则为 `itemCount / columns` 向上取整。
- **副作用：** 无。
- **算法：** `(itemCount + perRow - 1) ~/ perRow`，其中 `perRow` 是被下限钳制到 1 的 `columns`。
- **用法：**
  ```dart
  return ListView.builder(
    itemCount: listRowCount(results.length, columns),
    itemBuilder: (context, row) => adaptiveTileRow(
      rowIndex: row,
      columns: columns,
      itemCount: results.length,
      itemBuilder: (i) => _buildAnimeTile(results[i], theme, l10n, columns),
    ),
  );
  ```
  （出自 `_ManagementPageState._buildSearchResults`）
- **备注：** 最后一行可能不满；`adaptiveTileRow` 会为其补位，使剩余条目保持自身宽度而不是横向拉伸铺满整行。
  对 `columns < 1` 的保护让算式在尚未钳制的调用点保持完整，而不是除以零。
