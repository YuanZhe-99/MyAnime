# lib/shared/utils/detail_layout.dart

番剧详情页自适应布局的小型共享工具模块：`detailTwoPaneMinWidth`、`detailTwoPaneMinHeight`、`detailTwoPaneMinAspect`、`detailCoverAspectRatio` 和 `detailLeftPaneHeaderBudget` 常量，以及三个被 `anime_detail_page.dart`（见 [../../features/anime/views/anime_detail_page.md](../../features/anime/views/anime_detail_page.md)）用于判断是否把页面拆成双栏、并为该拆分定尺寸的纯辅助函数。

本模块刻意只依赖 `dart:core`——不含任何 Flutter 导入，`useDetailTwoPane` 接收两个 double 而非 `Size` 正是出于此因——因此每个辅助函数都可直接单元测试（`test/detail_layout_test.dart`），渲染结果则由 `test/detail_layout_ui_test.dart` 在真实设备几何尺寸下单独覆盖。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | 顶层函数 | A | 报告番剧详情页是否应使用双栏布局。 |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | 顶层函数 | A | 返回详情页固定左栏的宽度。 |
| [`detailCoverSize`](#detailcoversize) | 顶层函数 | A | 返回详情页左栏封面图的尺寸。 |

五个常量是没有 `/// Purpose:` 注释的普通声明，不作为单独行索引。`detailCoverAspectRatio`（180/260）保持单栏布局一直使用的封面比例，`detailLeftPaneHeaderBudget`（220.0）是封面下方为日文标题、标签行、进度条及其标签预留的纵向空间。

## 文档

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 33 行）
- **用途：** 判断视口的形状与尺寸是否适合详情页的双栏布局。
- **输入：** `width`、`height` — 视口的逻辑像素尺寸，读自 `MediaQuery.sizeOf(context)`。
- **返回：** `bool` — 三个条件全部满足时为 `true`。
- **副作用：** 无。
- **算法：** 三项彼此独立、必须全部通过的检查：
  1. `width >= detailTwoPaneMinWidth`（600.0）
  2. `height >= detailTwoPaneMinHeight`（480.0）
  3. `width / height >= detailTwoPaneMinAspect`（0.82）
- **用法：**
  ```dart
  final screen = MediaQuery.sizeOf(context);
  if (!useDetailTwoPane(screen.width, screen.height)) {
    return ListView(children: [...]);
  }
  ```
  （出自 `_AnimeDetailPageState.build`，`lib/features/anime/views/anime_detail_page.dart`）
- **备注：** **宽高比检查是承重的那一项，也是本规则不是单纯宽度断点的原因。** Galaxy Z Fold 8 展开后是 4:3 的**横向**面板（2448 × 1848 px），因此竖屏时为 3:4——相对高度比它所取代的近方形 Fold 7 更窄，尽管它更新。于是同一台设备在同一宽度下需要两个不同答案：横屏拆分，竖屏保持原本的单栏。阈值 0.82 位于 Fold 8 竖屏的 0.755 与 Fold 7 / Fold 8 Ultra 竖屏的 0.90 之间空隙的中段，两侧各留约 9% 余量。

  宽度下限是通常的 Material 3 *medium* / Android `sw600dp` 阈值。即便取显示尺寸可选范围中较密的一端，每块展开的折叠屏也至少高出 59 dp，而每块折叠状态的封面屏（约 356–416 dp）都远在其下。

  高度下限之所以存在，是因为仅凭宽高比检查会放行**又宽又矮**的视口：没有它，折叠状态的 Z Fold 8 封面屏旋转到横向（约 657 × 416 dp）和普通手机横屏（约 915 × 412 dp）都会被拆成两个逼仄的栏。

  由于该规则针对形状而非设备类别，4:3 或 16:10 的平板竖屏同样保持单栏、横屏拆分，与 Fold 8 完全一致。

  该判断读取 `MediaQuery.sizeOf(context)` 而非用于给两栏定尺寸的 `LayoutBuilder` 约束：以 `Scaffold` body 度量会从高度中扣掉应用栏并抬高比值，使 Z Fold 8 竖屏读作 0.80，几乎不留阈值余量。

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 48 行）
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
- **来源：** `lib/shared/utils/detail_layout.dart`（约第 66 行）
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
