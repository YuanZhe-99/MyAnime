# lib/features/settings/widgets/home_widget_preview.dart

`HomeWidgetPreview` 在设置 › 桌面小组件中绘制两个桌面小组件（1.9.4，仅 Android 与 iOS），这样不用回到桌面就能判断「小组件字号」滑块的效果。它用
[`HomeWidgetService.buildSnapshot`](../../../shared/services/home_widget_service.md#buildsnapshot)
为真实片库构建快照，按原生小组件的方式求值，并以 Android 布局字号乘以所选倍数、用应用配色绘制一张 2×2 卡片和一条 2×1 横条。它只是近似原生小组件，并非任一平台的像素级复刻。见
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `HomeWidgetPreview({super.key, required this.textScale})` | 构造函数（`HomeWidgetPreview`） | B | 为某个字号倍数创建预览。 |
| `createState` | 方法（`HomeWidgetPreview`） | B | 创建状态对象。 |
| [`_load`](#_load) | 方法（`_HomeWidgetPreviewState`） | A | 从已存储的片库一次性构建预览状态。 |
| [`build`](#build) | 方法（`_HomeWidgetPreviewState`） | A | 排布两张预览卡片。 |
| `HomeWidgetPreviewState(...)` | 构造函数（`HomeWidgetPreviewState`） | B | 保存一次求值后的小组件状态。 |
| [`HomeWidgetPreviewState.evaluate`](#evaluate) | 工厂构造函数（`HomeWidgetPreviewState`） | A | 像原生小组件一样对新快照求值。 |
| [`_airTime`](#_airtime) | 顶层函数 | A | 像原生小组件一样格式化播出时间。 |
| `_WidgetSurface(...)` | 构造函数（`_WidgetSurface`） | B | 创建共用的固定尺寸卡片底面。 |
| `_WidgetSurface.build` | 方法（`_WidgetSurface`） | B | 绘制圆角、着色并裁剪的底面。 |
| `_SmallWidgetCard(...)` | 构造函数（`_SmallWidgetCard`） | B | 创建 2×2 预览。 |
| [`_SmallWidgetCard.build`](#_smallwidgetcard-build) | 方法（`_SmallWidgetCard`） | A | 绘制 2×2 小组件。 |
| `_StripWidgetCard(...)` | 构造函数（`_StripWidgetCard`） | B | 创建 2×1 预览。 |
| [`_StripWidgetCard.build`](#_stripwidgetcard-build) | 方法（`_StripWidgetCard`） | A | 绘制 2×1 横条。 |

## 文档

### `Future<HomeWidgetPreviewState> _load()` <a id="_load"></a>
- **种类：** `_HomeWidgetPreviewState` 的方法
- **用途：** 一次性读取片库和日历时间基准，并对当前时刻构建的快照求值。
- **输入：** 无。
- **返回：** `Future<HomeWidgetPreviewState>`。
- **副作用：** 读取 `anime_data.json` 和 `storage_config.json`。
- **算法：** `AnimeStorage.load` → 时间基准 → 以空 labels 调用 `buildSnapshot` → [`evaluate`](#evaluate)。
- **用法：** 保存在 `late final` future 中，因此拖动滑块不会重新加载片库。
- **备注：** 文案改由组件树自身的 `AppLocalizations` 提供。

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `_HomeWidgetPreviewState` 的方法
- **用途：** 在居中的 `Wrap` 中显示两张卡片。
- **输入：** `context`。
- **返回：** 两张卡片；`_load` 完成前为 172 像素高的占位。
- **副作用：** 无。
- **算法：** 对 `_load` 使用 `FutureBuilder`；把 `widget.textScale` 传给两张卡片。
- **用法：** 设置页，滑块下方。
- **备注：** 窗口较窄时卡片会换成两行。

### `factory HomeWidgetPreviewState.evaluate(Map<String, dynamic> snapshot, DateTime nowUtc)` <a id="evaluate"></a>
- **种类：** `HomeWidgetPreviewState` 的工厂构造函数
- **用途：** 对在 `nowUtc` 构建的快照复刻原生 `UpNextState` 的求值。
- **输入：** 来自 `buildSnapshot` 的 `snapshot`；`nowUtc`。
- **返回：** `toWatch`、`queue`、`todayCount`、`nextUp`。
- **副作用：** 无。
- **算法：** `toWatch = airedUnwatched`（`generatedAt` 之后没有新播出的集）；`queue` = 每部番剧第一条未看且已播出的条目；`todayCount` = 在快照时区（JST 或设备时区）中日期为今天的条目数；`nextUp` = 此刻之后第一条未看的条目。
- **用法：** [`_load`](#_load)；`test/home_widget_service_test.dart`。
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
- **用途：** 绘制 2×2 小组件：带今日胶囊的标题行、数字或「已全部看完」、说明文字和条目行。
- **输入：** `context`。
- **返回：** 172 × 172 的卡片。
- **副作用：** 无。
- **算法：** 字号取自 `widget_up_next.xml`（12/11/36 或 20/12/13/12 sp）乘以倍数；120% 及以下显示两行队列，以上显示一行；队列为空时显示下一集播出。
- **用法：** [`build`](#build)。
- **备注：** 内容取舍与 `UpNextWidgetProvider.render` 相同。

### `Widget _StripWidgetCard.build(BuildContext context)` <a id="_stripwidgetcard-build"></a>
- **种类：** `_StripWidgetCard` 的方法
- **用途：** 绘制 2×1 横条：数字方块和两行文字。
- **输入：** `context`。
- **返回：** 172 × 76 的卡片。
- **副作用：** 无。
- **算法：** 字号取自 `widget_up_next_strip.xml`（18/14/12 sp）乘以倍数；两行内容同 `UpNextStripWidgetProvider.render`。
- **用法：** [`build`](#build)。
- **备注：** 无。
