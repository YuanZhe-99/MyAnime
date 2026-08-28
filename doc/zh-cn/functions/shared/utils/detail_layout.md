# lib/shared/utils/detail_layout.dart

番剧详情页自适应布局的小型共享工具模块：`detailCoverAspectRatio` 和 `detailLeftPaneHeaderBudget` 常量，以及三个被 `anime_detail_page.dart`（见 [../../features/anime/views/anime_detail_page.md](../../features/anime/views/anime_detail_page.md)）用于判断是否把页面拆成双栏、并为该拆分定尺寸的纯辅助函数。

**拆分判定本身已不在此处。** 原先的 `detailTwoPaneMinWidth`、`detailTwoPaneMinHeight` 和 `detailTwoPaneMinAspect` 三个阈值已于 1.5.3 迁往 [adaptive_layout.md](adaptive_layout.md)，因为首页、管理与统计模块中的多列列表开始共用同一条规则；`useDetailTwoPane` 现在是转发到 `canSplitLayout` 的单行委托。留在此处的是真正属于本页面的尺寸计算——左栏有多宽，以及其中的封面能有多大。

本模块刻意只依赖 `dart:core` 及其同级的 `adaptive_layout.dart`——不含任何 Flutter 导入，`useDetailTwoPane` 接收两个 double 而非 `Size` 正是出于此因——因此每个辅助函数都可直接单元测试（`test/detail_layout_test.dart`），渲染结果则由 `test/detail_layout_ui_test.dart` 在真实设备几何尺寸下单独覆盖。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | 顶层函数 | A | 报告番剧详情页是否应使用双栏布局。 |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | 顶层函数 | A | 返回详情页固定左栏的宽度。 |
| [`detailCoverSize`](#detailcoversize) | 顶层函数 | A | 返回详情页左栏封面图的尺寸。 |

两个常量是没有 `/// Purpose:` 注释的普通声明，不作为单独行索引。`detailCoverAspectRatio`（180/260）保持单栏布局一直使用的封面比例，`detailLeftPaneHeaderBudget`（220.0）是封面下方为日文标题、标签行、进度条及其标签预留的纵向空间。

## 文档

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 21 行）
- **用途：** 判断视口的形状与尺寸是否适合详情页的双栏布局。
- **输入：** `width`、`height` — 视口的逻辑像素尺寸，读自 `MediaQuery.sizeOf(context)`。
- **返回：** `bool` — `canSplitLayout` 返回什么就返回什么。
- **副作用：** 无。
- **算法：** `=> canSplitLayout(width, height)`。三个阈值及其各自背后的推理记录于
  [adaptive_layout.md](adaptive_layout.md)，散文形式的说明见
  [../../../adaptive-layout.md](../../../adaptive-layout.md)。
- **用法：**
  ```dart
  final screen = MediaQuery.sizeOf(context);
  if (!useDetailTwoPane(screen.width, screen.height)) {
    return ListView(children: [...]);
  }
  ```
  （出自 `_AnimeDetailPageState.build`，`lib/features/anime/views/anime_detail_page.dart`）
- **备注：** 保留这层包装而不是在调用点直接替换，是为了让详情页继续用自己的词汇称呼这个判定，也让既有测试和
  本页保留原有名称。`test/adaptive_layout_test.dart` 断言这两个函数在每一处固定的设备几何上都一致，因此该委托
  不会悄悄漂移。

  简要地说，便于定位：宽 >= 600、高 >= 480 且 宽/高 >= 0.82 时拆分。宽高比检查是承重的那一项——Galaxy Z Fold 8
  展开后是 4:3 的**横向**面板，因此横屏拆分、竖屏保持单栏，而近方形的 Fold 7 与 Fold 8 Ultra 两种方向都拆分。

  该判断读取 `MediaQuery.sizeOf(context)` 而非用于给两栏定尺寸的 `LayoutBuilder` 约束：以 `Scaffold` body 度量
  会从高度中扣掉应用栏并抬高比值，使 Z Fold 8 竖屏读作 0.80，几乎不留阈值余量。

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 30 行）
- **用途：** 为承载从封面到观看进度的固定左栏定宽。
- **输入：** `totalWidth` — 视口完整宽度的逻辑像素。
- **返回：** `double` — `totalWidth * 0.36`，钳制到 `[260.0, 420.0]`。
- **副作用：** 无。
- **算法：** 视口的固定比例，并在两端钳制。
- **用法：**
  ```dart
  final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
  ```
  （出自 `_AnimeDetailPageState.build` 的双栏分支）
- **备注：** 采用比例而非固定值，是因为一代折叠屏展开后现在横跨约 672 dp（Z Fold 8，竖屏高密度最坏情况）到 954 dp（Z Fold 8 Ultra，横屏）——比 Fold 8 把产品线拆成 4:3 机型与近方形 Ultra 之前的跨度大得多。下钳制保证 600 dp 时该栏仍可用；上钳制阻止它在桌面窗口中蔓延。0.36 系数配合这两个钳制，总能让右栏占据较大的一份。

### `({double width, double height}) detailCoverSize(double paneWidth, double paneHeight)` <a id="detailcoversize"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 48 行）
- **用途：** 让封面图填满左栏富余的高度，同时不把其下方的头部内容挤出屏幕。
- **输入：** `paneWidth`、`paneHeight` — 左栏的逻辑像素尺寸。
- **返回：** 含封面 `width` 与 `height` 的记录。
- **副作用：** 无。
- **算法：**
  1. 从 `paneHeight - detailLeftPaneHeaderBudget` 起算。
  2. 先以 `paneHeight / 2` 封顶，再以 `420` 封顶，最后以 `140` 兜底。
  3. 由 `height * detailCoverAspectRatio` 得出 `width`。
  4. 若该宽度超过 `paneWidth - 32`，改以宽度为约束并据此反推高度，两种情形下都保持比例不变。
- **用法：**
  ```dart
  final cover = detailCoverSize(paneWidth, constraints.maxHeight);
  ```
  （出自 `_AnimeDetailPageState.build` 的双栏分支，传给 `_buildCover`）
- **备注：** 每一项限制都有其必要，其中两项是在看过渲染结果之后才加上的，而非事先推导出来。**半栏封顶**之所以存在，是因为封面下方的头部是内容自适应高度的：在横屏的 Z Fold 8（高 704 dp）上，仅凭固定预算会给封面 420 dp，此时标题折成两行、其下三排标签就会越过栏底。**宽度检查**之所以存在，是因为 3:4 竖向面板相对宽度的纵向空间远多于近方形面板，只按高度定尺寸会得到又高又窄的封面。左栏仍是 `SingleChildScrollView`，因此异常长的内容或极端文本缩放会滚动而不是溢出。
