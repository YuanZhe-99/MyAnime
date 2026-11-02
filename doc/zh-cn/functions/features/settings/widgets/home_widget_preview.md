# lib/features/settings/widgets/home_widget_preview.dart

`HomeWidgetPreview` 在小组件设置页上绘制一个桌面小组件（1.9.4，仅 Android 与 iOS；自 1.9.7 起每个预览只画一个小组件，见
[`../views/home_widget_settings_page.md`](../views/home_widget_settings_page.md)），这样不用回到桌面就能判断该小组件「小组件字号」滑块的效果。
自 1.9.7 起它是一个 `StatelessWidget`：`HomeWidgetPreviewKind`（`large`、`strip`）决定画哪个小组件，页面只调用一次静态的 `load()`，
并把同一个 `Future<HomeWidgetPreviewData>`（`HomeWidgetPreviewState` 与已放置尺寸组成的记录的 typedef）传给两个预览。它用
[`HomeWidgetService.buildSnapshot`](../../../shared/services/home_widget_service.md#buildsnapshot)
为真实片库构建快照，按原生小组件的方式求值，并以 Android 布局字号乘以所选倍数、用应用配色在 `myapps_widget_ui` 的共享
`WidgetPreviewSurface` 上（1.9.5）绘制大号卡片或横条。在 Android 上，卡片按桌面启动器给该小组件第一个已放置实例的尺寸排版
（[`HomeWidgetService.placedSizes`](../../../shared/services/home_widget_service.md#placedsizes)）；未放置时以及在 iOS 上，使用
[`defaultSize`](#defaultsize)：大号小组件 3×2 格、横条 3×1 格，其中 `cell` 为 86 dp（`WidgetPreviewSurface.smallSide` 的一半），横条保持
`WidgetPreviewSurface.stripHeight`（76）。卡片随后按 `displayScale`（0.75）绘制，只在放不下时才进一步缩小以适应页面。它只是近似原生小组件，
并非任一平台的像素级复刻；若启动器缩放绘制小组件（有些会把整个小组件缩小），桌面上看起来仍会更小。见
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `HomeWidgetPreview({super.key, required this.data, required this.kind, required this.textScale})` | 构造函数（`HomeWidgetPreview`） | B | 依据共享数据，按某个字号倍数创建一个小组件的预览。 |
| [`defaultSize`](#defaultsize) | 静态方法（`HomeWidgetPreview`） | A | 返回未放置实例时使用的尺寸。 |
| [`load`](#load) | 静态方法（`HomeWidgetPreview`） | A | 构建预览状态并读取已放置的尺寸。 |
| [`build`](#build) | 方法（`HomeWidgetPreview`） | A | 排布这一张预览卡片。 |
| `HomeWidgetPreviewState(...)` | 构造函数（`HomeWidgetPreviewState`） | B | 保存一次求值后的小组件状态。 |
| [`HomeWidgetPreviewState.evaluate`](#evaluate) | 工厂构造函数（`HomeWidgetPreviewState`） | A | 像原生小组件一样对新快照求值。 |
| [`_airTime`](#_airtime) | 顶层函数 | A | 像原生小组件一样格式化播出时间。 |
| `_SmallWidgetCard(...)` | 构造函数（`_SmallWidgetCard`） | B | 按给定尺寸和已放置的最小高度创建大号小组件预览。 |
| [`_SmallWidgetCard.build`](#_smallwidgetcard-build) | 方法（`_SmallWidgetCard`） | A | 绘制大号小组件。 |
| `_StripWidgetCard(...)` | 构造函数（`_StripWidgetCard`） | B | 按给定尺寸创建横条预览。 |
| [`_StripWidgetCard.build`](#_stripwidgetcard-build) | 方法（`_StripWidgetCard`） | A | 绘制横条。 |

`HomeWidgetPreviewKind` 枚举、`HomeWidgetPreviewData` typedef、`data`、`kind` 与 `textScale` 字段，以及 `cell` 与 `displayScale`
常量都没有 `/// Purpose:` 注释，不单列一行。`createState` 和 `_HomeWidgetPreviewState` 已于 1.9.7 移除。

## 文档

### `static Size defaultSize(HomeWidgetPreviewKind kind)` <a id="defaultsize"></a>
- **种类：** `HomeWidgetPreview` 的静态方法
- **用途：** 返回其小组件没有已放置实例时预览使用的尺寸。
- **输入：** `kind`。
- **返回：** `large` 为 `Size(3 × cell, 2 × cell)`（258 × 172 dp）；`strip` 为 `Size(3 × cell,
  WidgetPreviewSurface.stripHeight)`（258 × 76 dp）。
- **副作用：** 无。
- **算法：** 对 `kind` 做 `switch`。
- **用法：** [`build`](#build)，用于尺寸以及加载中占位的高度。
- **备注：** 横条保持共享的横条高度，而不是一整格。1.9.7 之前默认尺寸为 172 × 172 和 172 × 76。

### `static Future<HomeWidgetPreviewData> load()` <a id="load"></a>
- **种类：** `HomeWidgetPreview` 的静态方法
- **用途：** 读取片库和日历时间基准，对当前时刻构建的快照求值，并读取已放置小组件的尺寸。
- **输入：** 无。
- **返回：** 求值后的状态，以及每个已放置实例的 `PlacedWidgetSize`。
- **副作用：** 读取 `anime_data.json` 和 `storage_config.json`；在 Android 上向启动器查询已放置小组件的尺寸。
- **算法：** `AnimeStorage.load` → 时间基准 → 以空 labels 调用 `buildSnapshot` → [`evaluate`](#evaluate)；然后 `HomeWidgetService.placedSizes`。
- **用法：** `HomeWidgetSettingsPage` 把它保存在 `late final` future 中并传给两个预览，因此拖动滑块不会重新加载片库。
- **备注：** 文案改由组件树自身的 `AppLocalizations` 提供。尺寸每次进入该页读取一次，期间调整过大小的小组件需重新打开该页才会反映。
  1.9.6 及之前它是状态类的私有方法 `_load`。

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `HomeWidgetPreview` 的方法
- **用途：** 居中显示 `kind` 对应的卡片。
- **输入：** `context`。
- **返回：** 该卡片；`data` 完成前为 `defaultSize(kind).height × displayScale` 高的占位。
- **副作用：** 无。
- **算法：** 对 `data` 使用 `FutureBuilder`；`kind` 对应的 Provider（`HomeWidgetService.smallProvider` 或 `stripProvider`）选出第一个已放置实例，
  按当前方向取其 `portrait` 或 `landscape` 尺寸，否则用 [`defaultSize`](#defaultsize)。卡片（带实例 `minHeight` 的 `_SmallWidgetCard`，
  或 `_StripWidgetCard`）传入 `textScale`，并适配进 `size × displayScale` 的盒子，外面是放在 `Center` 中的 `FittedBox(scaleDown)`。
- **用法：** `HomeWidgetSettingsPage`，每个滑块下方。
- **备注：** 同一小组件有多个已放置实例时，显示第一个。比页面更宽的卡片会整体缩小，排版保持不变。1.9.6 及之前，一个有状态的预览在
  `Wrap` 中按原尺寸同时绘制两张卡片。

### `factory HomeWidgetPreviewState.evaluate(Map<String, dynamic> snapshot, DateTime nowUtc)` <a id="evaluate"></a>
- **种类：** `HomeWidgetPreviewState` 的工厂构造函数
- **用途：** 对在 `nowUtc` 构建的快照复刻原生 `UpNextState` 的求值。
- **输入：** `snapshot` —— 来自 `buildSnapshot` 的外层封装 map；`nowUtc`。
- **返回：** `toWatch`、`queue`、`todayCount`、`nextUp`。
- **副作用：** 无。
- **算法：** 读取外层封装的 `payload`。`toWatch = airedUnwatched`（`generatedAt` 之后没有新播出的集）；`queue` = 每部番剧第一条未看且已播出的条目；`todayCount` = 在快照时区（JST 或设备时区）中日期为今天的条目数；`nextUp` = 此刻之后第一条未看的条目。
- **用法：** [`load`](#load)；`test/home_widget_service_test.dart`。
- **备注：** 设为公开，便于测试对照原生公式进行检查。

### `String _airTime(BuildContext context, int ms)` <a id="_airtime"></a>
- **种类：** 顶层函数
- **用途：** 格式化为 `HH:mm`（24 小时制），不是今天时前缀简短星期。
- **输入：** `context`、毫秒时间戳 `ms`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** `MaterialLocalizations.formatTimeOfDay` 与 `narrowWeekdays`。
- **用法：** 两张卡片的 `build` 方法。
- **备注：** 使用设备本地时间，对预览来说足够接近。

### `Widget _SmallWidgetCard.build(BuildContext context)` <a id="_smallwidgetcard-build"></a>
- **种类：** `_SmallWidgetCard` 的方法
- **用途：** 绘制大号小组件：带今日胶囊的标题行、数字或「已全部看完」、说明文字和条目行。
- **输入：** `context`。
- **返回：** 给定尺寸的 `WidgetPreviewSurface`。
- **副作用：** 无。
- **算法：** 字号取自 `widget_up_next.xml`（12/11/36 或 20/12/13/12 sp）乘以倍数。队列行数：令 `h` 为已放置实例的最小高度，未放置时为卡片高度；
  `h` 为 0 或不小于 150 dp × 倍数则两行，否则一行（同 `UpNextWidgetProvider.render`）。队列为空时显示下一集播出。
- **用法：** [`build`](#build)。
- **备注：** 内容取舍与 `UpNextWidgetProvider.render` 相同。1.9.6 及之前，没有已放置实例时 120% 及以下两行，以上一行。

### `Widget _StripWidgetCard.build(BuildContext context)` <a id="_stripwidgetcard-build"></a>
- **种类：** `_StripWidgetCard` 的方法
- **用途：** 绘制横条：数字方块和两行文字。
- **输入：** `context`。
- **返回：** 给定尺寸的 `WidgetPreviewSurface`。
- **副作用：** 无。
- **算法：** 字号取自 `widget_up_next_strip.xml`（18/14/12 sp）乘以倍数；两行内容同 `UpNextStripWidgetProvider.render`。
- **用法：** [`build`](#build)。
- **备注：** 无。
